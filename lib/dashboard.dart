import 'dart:async';
import 'package:flutter/material.dart';
import 'services/device_service.dart';
import 'services/monitoring_service.dart';
import 'services/database_service.dart';
import 'models.dart';
import 'widgets/metrics_dashboard.dart';
import 'widgets/history_view.dart';
import 'widgets/device_sidebar.dart';
import 'widgets/device_camera_roll.dart';
import 'widgets/device_config_dialog.dart';
import 'widgets/sensor_chart.dart'; // Ensure you have this file or remove the usage below

class MqttDashboard extends StatefulWidget {
  const MqttDashboard({super.key});

  @override
  State<MqttDashboard> createState() => _MqttDashboardState();
}

class _MqttDashboardState extends State<MqttDashboard> {
  final DeviceService _deviceService = DeviceService();
  final MonitoringService _monitor = MonitoringService();
  final DatabaseService _db = DatabaseService();

  List<Device> _devices = [];
  Device? _selectedDevice;
  
  // UI State
  bool _isLoading = true;
  bool _isSidebarOpen = true; // Sidebar starts open
  bool _showHistory = false;
  bool _sortAscending = false;

  // Data Cache for Offline Detection & History
  final Map<String, DateTime> _lastSeen = {};
  final Map<String, List<Map<String, dynamic>>> _historyCache = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    // Refresh UI every second to update "Offline" timers
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {}); 
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    await _deviceService.init();
    var devices = await _deviceService.getAllDevices();

    List<Device> fullDevices = [];
    for (var d in devices) {
      final key = await _deviceService.getDeviceApiKey(d.appId);
      fullDevices.add(key != null ? d.copyWith(accessKey: key) : d);
    }

    if (mounted) {
      setState(() {
        _devices = fullDevices;
        if (_devices.isNotEmpty && _selectedDevice == null) {
          _selectedDevice = _devices.first;
        }
        _isLoading = false;
      });
      // Pre-load history for the first device
      if (_selectedDevice != null) _loadHistory(_selectedDevice!.id);
    }
  }

  Future<void> _loadHistory(String deviceId) async {
    final device = _devices.firstWhere((d) => d.id == deviceId, orElse: () => _devices.first);
    try {
      final data = await _db.getSensorReadings(
        deviceId: device.deviceEui,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _historyCache[deviceId] = data;
        });
      }
    } catch (e) {
      debugPrint("History Load Error: $e");
    }
  }

  bool _isOffline(String deviceId) {
    if (!_lastSeen.containsKey(deviceId)) return true;
    final last = _lastSeen[deviceId]!;
    // 15 minutes threshold
    return DateTime.now().difference(last).inMinutes > 15; 
  }

  void _handleMonitoringToggle() {
    if (_monitor.isMonitoring.value) {
      _monitor.stopMonitoring();
    } else {
      _monitor.startMonitoring(_devices);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe-Art Monitor'),
        leading: IconButton(
          icon: Icon(_isSidebarOpen ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
        ),
      ),
      body: Row(
        children: [
          // 1. Collapsible Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarOpen ? 280 : 0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: 280,
                minWidth: 280,
                alignment: Alignment.topLeft,
                child: DeviceSidebar(
                  devices: _devices,
                  selectedDevice: _selectedDevice,
                  onDeviceSelected: (d) {
                    setState(() {
                      _selectedDevice = d;
                      // Reload history when switching devices
                      _loadHistory(d.id);
                    });
                  },
                  onAddDevice: () => _editDevice(null),
                  onEditDevice: _editDevice,
                  onDeleteDevice: _deleteDevice,
                ),
              ),
            ),
          ),

          // 2. Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Control Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _monitor.isMonitoring,
                              builder: (ctx, isRunning, _) {
                                return ElevatedButton.icon(
                                  onPressed: _handleMonitoringToggle,
                                  icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                                  label: Text(isRunning ? 'Stop Monitoring' : 'Start Monitoring'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isRunning ? Colors.redAccent : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() => _showHistory = !_showHistory),
                              icon: Icon(_showHistory ? Icons.dashboard : Icons.history),
                              label: Text(_showHistory ? 'Back to Live' : 'View History'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Status Log Line
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: Colors.grey[200],
                        child: ValueListenableBuilder<String>(
                          valueListenable: _monitor.statusLog,
                          builder: (_, log, _) => Text(
                            "Status: $log",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Views
                Expanded(
                  child: _devices.isEmpty
                      ? const Center(child: Text("Add a device to begin"))
                      : _buildMainView(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    // 3. History View
    if (_showHistory) {
      return Column(
        children: [
          // Optional Chart at top of history
          SizedBox(
            height: 200,
            child: SensorChart(
              historicalData: _historyCache[_selectedDevice?.id] ?? [],
              isAscending: _sortAscending,
            ),
          ),
          Expanded(
            child: HistoryView(
              historicalData: _historyCache[_selectedDevice?.id] ?? [],
              isLoading: false,
              onLoad: () => _selectedDevice != null ? _loadHistory(_selectedDevice!.id) : null,
              databaseService: _db,
              isAscending: _sortAscending,
              deviceId: _selectedDevice?.id,
            ),
          ),
        ],
      );
    }

    // 4. Live Camera Roll View
    return DeviceCameraRoll(
      devices: _devices,
      selectedDevice: _selectedDevice,
      onDeviceChanged: (d) => setState(() => _selectedDevice = d),
      deviceViewBuilder: (device) {
        return StreamBuilder<SensorData>(
          stream: _monitor.getStream(device.id),
          builder: (context, snapshot) {
            
            // Update "Last Seen" for offline logic
            if (snapshot.hasData && snapshot.data != null) {
              _lastSeen[device.id] = snapshot.data!.timestamp;
            }

            // If we have no stream data, check if we have it in history to show *something*
            // Otherwise, it's just "Waiting for data..."
            
            return MetricsDashboard(
              currentReading: snapshot.data,
              offline: _isOffline(device.id),
              isMonitoring: _monitor.isMonitoring.value,
              offlineThresholdSeconds: 900, // 15 mins
              onSendStopAlarm: () => _monitor.sendStopCommand(device),
              batteryMode: device.batteryMode,
              // We can pass null for dailyMHO or calculate it if needed
              dailyMHO: null, 
            );
          },
        );
      },
    );
  }

  Future<void> _editDevice(Device? d) async {
    await showDialog(
      context: context,
      builder: (ctx) => DeviceConfigDialog(
        device: d,
        onSave: (newDev) async {
          if (d == null) {
            await _deviceService.addDevice(
              name: newDev.name, appId: newDev.appId, broker: newDev.broker,
              deviceEui: newDev.deviceEui, accessKey: newDev.accessKey ?? '',
              canControl: newDev.canControl, batteryMode: newDev.batteryMode
            );
          } else {
            await _deviceService.updateDevice(
              id: d.id, name: newDev.name, broker: newDev.broker,
              deviceEui: newDev.deviceEui, accessKey: newDev.accessKey,
              canControl: newDev.canControl, batteryMode: newDev.batteryMode
            );
          }
          _loadDevices();
        },
      ),
    );
  }

  Future<void> _deleteDevice(Device d) async {
    await _deviceService.deleteDevice(d.id);
    _loadDevices();
  }
}