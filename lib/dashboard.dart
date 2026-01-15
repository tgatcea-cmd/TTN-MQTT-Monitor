// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mqtt_wrapper/mqtt_wrapper.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'models.dart';
import 'models/device.dart';
import 'services/device_service.dart';
import 'database_service.dart';
import 'mqtt_handlers.dart';
import 'widgets/metrics_dashboard.dart';
import 'widgets/history_view.dart';
import 'widgets/device_sidebar.dart';
import 'widgets/device_camera_roll.dart';
import 'widgets/device_config_dialog.dart';

class MqttDashboard extends StatefulWidget {
  const MqttDashboard({super.key});

  @override
  State<MqttDashboard> createState() => _MqttDashboardState();
}

class _MqttDashboardState extends State<MqttDashboard> {
  final DatabaseService _databaseService = DatabaseService();
  final DeviceService _deviceService = DeviceService();

  // MQTT clients per device
  final Map<String, MqttWrapper> _activeClients = {};
  late MqttHandlers _mqttHandlers;

  bool isMonitoring = false;
  bool isLoadingDevices = true;
  bool _showHistory = false;

  List<Device> devices = [];
  Device? selectedDevice;
  Map<String, SensorData?> deviceReadings = {};

  DateTime? _lastSeenTimestamp;
  static const int _offlineThresholdSeconds = 60 * 16;

  String lastLog = "System Ready.";
  List<Map<String, dynamic>> _historicalData = [];

  Timer? _offlineTimer;

  @override
  void initState() {
    super.initState();
    _initDeviceService();
    _initMqttHandlers();
    _offlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _initDeviceService() async {
    await _deviceService.init();
    final loadedDevices = await _deviceService.getAllDevices();

    final devicesWithKeys = <Device>[];
    for (var device in loadedDevices) {
      final apiKey = await _deviceService.getDeviceApiKey(device.appId);
      devicesWithKeys.add(apiKey != null ? device.copyWith(accessKey: apiKey) : device);
    }

    setState(() {
      devices = devicesWithKeys;
      isLoadingDevices = false;
      if (devices.isNotEmpty) {
        selectedDevice = devices.first;
        for (var device in devices) {
          deviceReadings[device.id] = null;
        }
      }
    });
  }

  void _initMqttHandlers() {
    _mqttHandlers = MqttHandlers(
      databaseService: _databaseService,
      onMessageReceived: (msg) => debugPrint('Message: $msg'),
      onSensorDataUpdated: (data, sourceDeviceId) {
        setState(() {
          deviceReadings[sourceDeviceId] = data;
        });
      },
      onStatusUpdated: (status) {
        setState(() {
          lastLog = status;
        });
      },
    );
  }

  Future<void> _updateLastSeenFromDb(String? deviceEui) async {
    if (deviceEui == null || deviceEui.isEmpty) {
      setState(() {
        _lastSeenTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
      });
      return;
    }

    try {
      final rows = await _databaseService.getSensorReadings(
        deviceId: deviceEui,
        limit: 1,
      );
      if (rows.isNotEmpty && rows.first['timestamp'] != null) {
        setState(() {
          _lastSeenTimestamp = DateTime.parse(rows.first['timestamp']);
        });
      } else {
        setState(() {
          _lastSeenTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
        });
      }
    } catch (e) {
      debugPrint('Error reading last seen from DB: $e');
      setState(() {
        _lastSeenTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
      });
    }
  }

  @override
  void dispose() {
    _offlineTimer?.cancel();
    _disconnectAll();
    super.dispose();
  }

  void _stopMonitoring() {
    _disconnectAll();
    if (mounted) {
      setState(() {
        isMonitoring = false;
        lastLog = "Monitoring Stopped";
      });
    }
  }

  void _disconnectAll() {
    for (var client in _activeClients.values) {
      try {
        client.disconnect();
      } catch (_) {}
    }
    _activeClients.clear();
  }

  void sendStopAlarm() {
    if (!isMonitoring || selectedDevice == null || !selectedDevice!.canControl) return;

    final client = _activeClients[selectedDevice!.appId];
    if (client == null) {
      _showErrorSnackBar("Not connected to this device's application.");
      return;
    }

    _mqttHandlers.sendStopAlarm(
      client,
      selectedDevice!.appId.split('@')[0],
      selectedDevice!.deviceEui,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🛑 STOP Command Sent!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _startMonitoring() async {
    int successCount = 0;
    setState(() => lastLog = "Initializing connections...");

    for (var device in devices) {
      if (device.accessKey == null || device.accessKey!.isEmpty) {
        debugPrint("Skipping ${device.name} - No API Key");
        continue;
      }

      if (_activeClients.containsKey(device.appId)) continue;

      final mqtt = MqttWrapper(
        appId: device.appId,
        accessKey: device.accessKey!,
        broker: device.broker,
      );

      mqtt.messages.listen((message) {
        _mqttHandlers.handleMessage(
          message,
          device.deviceEui,
          device.id,
          device.deviceType,
        );
      });

      try {
        await mqtt.connect();
        if (mqtt.client.connectionStatus?.state == MqttConnectionState.connected) {
          final String cleanAppId = device.appId.split('@')[0];
          mqtt.client.subscribe("v3/$cleanAppId/devices/+/up", MqttQos.atMostOnce);

          _activeClients[device.appId] = mqtt;
          successCount++;
        }
      } catch (e) {
        debugPrint("Failed to connect to ${device.name}: $e");
      }
    }

    if (successCount > 0) {
      setState(() {
        isMonitoring = true;
        lastLog = "✅ Monitoring $successCount Device${successCount != 1 ? 's' : ''}";
      });
    } else {
      _showErrorSnackBar("Could not connect to any devices. Check API Keys.");
      setState(() => lastLog = "Connection Failed");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _loadHistoricalData() async {
    try {
      final data = await _databaseService.getLatestReadings(limit: 100);
      setState(() {
        _historicalData = data;
      });
    } catch (e) {
      debugPrint("Error loading historical data: $e");
    }
  }

  Future<void> _addOrEditDevice(Device? device) async {
    final wasMonitoring = isMonitoring;
    
    await showDialog(
      context: context,
      builder: (dialogBuildContext) => DeviceConfigDialog(
        device: device,
        onSave: (newDevice) async {
          try {
            if (device == null) {
              await _deviceService.addDevice(
                name: newDevice.name,
                appId: newDevice.appId,
                broker: newDevice.broker,
                deviceEui: newDevice.deviceEui,
                accessKey: newDevice.accessKey!,
                canControl: newDevice.canControl,
              );
            } else {
              await _deviceService.updateDevice(
                id: device.id,
                name: newDevice.name,
                broker: newDevice.broker,
                deviceEui: newDevice.deviceEui,
                accessKey: newDevice.accessKey,
                canControl: newDevice.canControl,
              );
            }

            final loadedDevices = await _deviceService.getAllDevices();
            final devicesWithKeys = <Device>[];
            for (var d in loadedDevices) {
              final apiKey = await _deviceService.getDeviceApiKey(d.appId);
              devicesWithKeys.add(apiKey != null ? d.copyWith(accessKey: apiKey) : d);
            }

            if (!mounted) return;
            
            // If a new device was added and no device was selected, select the new one
            Device? newSelectedDevice = selectedDevice;
            if (device == null && devicesWithKeys.isNotEmpty) {
              // Find the newly added device
              newSelectedDevice = devicesWithKeys.lastWhere(
                (d) => !devices.any((old) => old.id == d.id),
                orElse: () => devicesWithKeys.last,
              );
              
              // Initialize reading entry for new device
              deviceReadings[newSelectedDevice.id] = null;
            }
            
            setState(() {
              devices = devicesWithKeys;
              selectedDevice = newSelectedDevice;
            });

            Navigator.pop(dialogBuildContext);

            // Show success message
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(device == null ? 'Device added' : 'Device updated'),
                backgroundColor: Colors.green,
              ),
            );
            
            // If we were monitoring, restart monitoring with the new device list
            if (wasMonitoring && mounted) {
              _stopMonitoring();
              // Give MQTT clients time to disconnect properly
              await Future.delayed(Duration(milliseconds: 500));
              if (mounted) {
                _startMonitoring();
              }
            }
          } catch (e) {
            if (!mounted) return;
            Navigator.pop(dialogBuildContext);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteDevice(Device device) async {
    try {
      await _deviceService.deleteDevice(device.id);

      final loadedDevices = await _deviceService.getAllDevices();
      final devicesWithKeys = <Device>[];
      for (var d in loadedDevices) {
        final apiKey = await _deviceService.getDeviceApiKey(d.appId);
        devicesWithKeys.add(apiKey != null ? d.copyWith(accessKey: apiKey) : d);
      }

      setState(() {
        devices = devicesWithKeys;
        if (selectedDevice?.id == device.id) {
          selectedDevice = devices.isNotEmpty ? devices.first : null;
        }
        deviceReadings.remove(device.id);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device removed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isDeviceOffline(DateTime? timestamp) {
    if (timestamp == null) return true;
    return timestamp
        .add(Duration(seconds: _offlineThresholdSeconds))
        .isBefore(DateTime.now());
  }

  Widget _buildDeviceView(Device device) {
    final currentReading = deviceReadings[device.id];
    final effectiveTimestamp = currentReading?.timestamp ??
        _lastSeenTimestamp ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final offline = _isDeviceOffline(effectiveTimestamp);
    final secondsSince = DateTime.now().difference(effectiveTimestamp).inSeconds;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: MetricsDashboard(
        currentReading: currentReading,
        lastSeenTimestamp: _lastSeenTimestamp,
        secondsSince: secondsSince,
        offline: offline,
        offlineThresholdSeconds: _offlineThresholdSeconds,
        selectedProfile: null, // Not used in new model, but kept for compatibility
        onSendStopAlarm: sendStopAlarm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingDevices) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Safe-Art Monitor'),
        elevation: 0,
      ),
      drawer: DeviceSidebar(
        devices: devices,
        selectedDevice: selectedDevice,
        onDeviceSelected: (device) {
          setState(() {
            selectedDevice = device;
          });
          _updateLastSeenFromDb(device.deviceEui);
        },
        onAddDevice: () => _addOrEditDevice(null),
        onEditDevice: _addOrEditDevice,
        onDeleteDevice: _deleteDevice,
      ),
      body: Column(
        children: [
          // System control bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isMonitoring ? _stopMonitoring : _startMonitoring,
                    icon: Icon(isMonitoring ? Icons.stop : Icons.play_arrow),
                    label: Text(isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMonitoring ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _showHistory = !_showHistory),
                    icon: Icon(_showHistory ? Icons.dashboard : Icons.history),
                    label: Text(_showHistory ? 'Live View' : 'History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isMonitoring ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isMonitoring ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lastLog,
                      style: TextStyle(
                        color: isMonitoring ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Main content area
          if (devices.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.devices_other, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Devices',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Open the menu and add your first device',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else if (_showHistory)
            Expanded(
              child: HistoryView(
                historicalData: _historicalData,
                onLoad: _loadHistoricalData,
              ),
            )
          else
            Expanded(
              child: DeviceCameraRoll(
                devices: devices,
                selectedDevice: selectedDevice,
                onDeviceChanged: (device) {
                  setState(() {
                    selectedDevice = device;
                  });
                  _updateLastSeenFromDb(device.deviceEui);
                },
                deviceViewBuilder: _buildDeviceView,
              ),
            ),
        ],
      ),
    );
  }
}
