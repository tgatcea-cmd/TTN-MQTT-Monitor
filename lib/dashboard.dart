import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mqtt_wrapper/mqtt_wrapper.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'models.dart';
import 'models/device.dart';
import 'services/device_service.dart';
import 'database_service.dart';
import 'mqtt_handlers.dart' hide calculateDewPoint;
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

  final Map<String, MqttWrapper> _activeClients = {};

  final List<StreamSubscription> _subscriptions = [];

  late MqttHandlers _mqttHandlers;

  bool isMonitoring = false;
  bool isLoadingDevices = true;
  bool _showHistory = false;
  bool _sortAscending = false; 
  bool _isSidebarOpen = true;

  List<Device> devices = [];
  Device? selectedDevice;
  Map<String, SensorData?> deviceReadings = {};

  final Map<String, DateTime> _lastReadingByDevice = {};
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
      devicesWithKeys.add(
        apiKey != null ? device.copyWith(accessKey: apiKey) : device,
      );
    }

    if (!mounted) return;

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
        if (!mounted) return;
        setState(() {
          deviceReadings[sourceDeviceId] = data;
          _lastReadingByDevice[sourceDeviceId] = data.timestamp;
        });
      },
      onStatusUpdated: (status) {
        if (!mounted) return;
        setState(() {
          lastLog = status;
        });
      },
    );
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
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    for (var client in _activeClients.values) {
      try {
        client.disconnect();
      } catch (_) {}
    }
    _activeClients.clear();
  }

  void sendStopAlarm() {
    if (!isMonitoring || selectedDevice == null || !selectedDevice!.canControl)
      return;

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

      final isTTN =
          device.broker.contains('thethings') || device.broker.contains('ttn');

      final mqtt = MqttWrapper(
        appId: device.appId,
        accessKey: device.accessKey!,
        broker: device.broker,
        port: isTTN ? 8883 : 1883,
        secure: isTTN,
      );

      final subscription = mqtt.messages.listen((message) {
        _mqttHandlers.handleMessage(
          message,
          device.deviceEui,
          device.id,
          device.deviceType,
        );
      });
      _subscriptions.add(subscription);

      try {
        await mqtt.connect();
        if (mqtt.client.connectionStatus?.state ==
            MqttConnectionState.connected) {
          final String cleanAppId = device.appId.split('@')[0];
          mqtt.client.subscribe(
            "v3/$cleanAppId/devices/+/up",
            MqttQos.atMostOnce,
          );

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
        lastLog =
            "✅ Monitoring $successCount Device${successCount != 1 ? 's' : ''}";
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
      final data = await _databaseService.getLatestReadings(
        limit: 100,
        ascending: _sortAscending,
      );
      if (mounted) {
        setState(() {
          _historicalData = data;
        });
      }
    } catch (e) {
      debugPrint("Error loading historical data: $e");
    }
  }

  void _showHistoryView() {
    _loadHistoricalData();
    setState(() => _showHistory = true);
  }

  void _hideHistoryView() {
    _databaseService.unsubscribeFromReadings();
    setState(() => _showHistory = false);
  }

  Future<void> _insertTestData() async {
    final String testId = 'euid-test_device';
    final String testName = 'Test Device (Simulated)';

    final random = Random();
    final temp = 20.0 + random.nextDouble() * 10.0;
    final hum = 40.0 + random.nextDouble() * 20.0;
    final dew = calculateDewPoint(temp, hum);

    final sensorData = SensorData(
      temperature: temp,
      humidity: hum,
      co2: 450,
      battery: 3.2,
      dewPoint: dew,
      timestamp: DateTime.now(),
      deviceType: 'TTN',
    );

    if (!devices.any((d) => d.id == testId)) {
      final testDevice = Device(
        id: testId,
        name: testName,
        appId: 'test-app',
        broker: 'test.broker',
        deviceEui: testId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      setState(() {
        devices = [...devices, testDevice];
        deviceReadings[testId] = null;
        selectedDevice ??= testDevice;
      });
    }

    setState(() {
      deviceReadings[testId] = sensorData;
      _lastReadingByDevice[testId] = sensorData.timestamp;
      selectedDevice = devices.firstWhere((d) => d.id == testId);
    });

    try {
      await _databaseService.insertTestSensorReading(sensorData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Test reading added: ${temp.toStringAsFixed(1)}°C'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving to DB: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                batteryMode: newDevice.batteryMode, 
              );
            } else {
              await _deviceService.updateDevice(
                id: device.id,
                name: newDevice.name,
                broker: newDevice.broker,
                deviceEui: newDevice.deviceEui,
                accessKey: newDevice.accessKey,
                canControl: newDevice.canControl,
                deviceType: newDevice.deviceType,
                batteryMode: newDevice.batteryMode, 
              );
            }

            final loadedDevices = await _deviceService.getAllDevices();
            final devicesWithKeys = <Device>[];
            for (var d in loadedDevices) {
              final apiKey = await _deviceService.getDeviceApiKey(d.appId);
              devicesWithKeys.add(
                apiKey != null ? d.copyWith(accessKey: apiKey) : d,
              );
            }

            if (!mounted) return;

            Device? newSelectedDevice = selectedDevice;
            if (device == null && devicesWithKeys.isNotEmpty) {
              newSelectedDevice = devicesWithKeys.lastWhere(
                (d) => !devices.any((old) => old.id == d.id),
                orElse: () => devicesWithKeys.last,
              );
              deviceReadings[newSelectedDevice.id] = null;
            }

            setState(() {
              devices = devicesWithKeys;
              selectedDevice = newSelectedDevice;
            });

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  device == null ? 'Device added' : 'Device updated',
                ),
                backgroundColor: Colors.green,
              ),
            );

            if (wasMonitoring && mounted) {
              _stopMonitoring();
              await Future.delayed(Duration(milliseconds: 500));
              if (mounted) {
                _startMonitoring();
              }
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(dialogBuildContext);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
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
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  bool _isDeviceOffline(String deviceId) {
    final timestamp = _lastReadingByDevice[deviceId];
    if (timestamp == null) return true;
    return timestamp
        .add(Duration(seconds: _offlineThresholdSeconds))
        .isBefore(DateTime.now());
  }

  Widget _buildDeviceView(Device device) {
    final currentReading = deviceReadings[device.id];
    final offline = _isDeviceOffline(device.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: MetricsDashboard(
        currentReading: currentReading,
        offline: offline,
        isMonitoring: isMonitoring,
        offlineThresholdSeconds: _offlineThresholdSeconds,
        selectedProfile: null,
        onSendStopAlarm: sendStopAlarm,
        batteryMode: device.batteryMode, 
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
        leading: IconButton(
          icon: Icon(_isSidebarOpen ? Icons.menu_open : Icons.menu),
          onPressed: () {
            setState(() {
              _isSidebarOpen = !_isSidebarOpen;
            });
          },
        ),
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: _isSidebarOpen ? 280 : 0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: 280,
                minWidth: 280,
                alignment: Alignment.topLeft,
                child: DeviceSidebar(
                  devices: devices,
                  selectedDevice: selectedDevice,
                  onDeviceSelected: (device) {
                    setState(() {
                      selectedDevice = device;
                    });
                  },
                  onAddDevice: () => _addOrEditDevice(null),
                  onEditDevice: _addOrEditDevice,
                  onDeleteDevice: _deleteDevice,
                ),
              ),
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isMonitoring
                              ? _stopMonitoring
                              : _startMonitoring,
                          icon: Icon(
                            isMonitoring ? Icons.stop : Icons.play_arrow,
                          ),
                          label: Text(
                            isMonitoring
                                ? 'Stop Monitoring'
                                : 'Start Monitoring',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMonitoring
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showHistory
                              ? _hideHistoryView()
                              : _showHistoryView(),
                          icon: Icon(
                            _showHistory ? Icons.dashboard : Icons.history,
                          ),
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
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: _insertTestData,
                    icon: Icon(Icons.bug_report),
                    label: Text('Add Test Reading'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
                ),

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
                          isMonitoring
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
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

                if (_showHistory) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end, 
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _sortAscending = !_sortAscending;
                            });
                            _loadHistoricalData(); 
                          },
                          icon: Icon(
                            _sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                          ),
                          label: Text(
                            _sortAscending
                                ? "Más Antiguos Primero"
                                : "Más Recientes Primero",
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: HistoryView(
                      databaseService: _databaseService,
                      historicalData: _historicalData,
                      onLoad: _loadHistoricalData,
                      isAscending: _sortAscending,
                    ),
                  ),
                ] else if (devices.isEmpty)
                  const Expanded(
                    child: Center(child: Text("Add a device to begin")),
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
                      },
                      deviceViewBuilder: _buildDeviceView,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
