import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../data/services/app_controller.dart';
import '../../data/services/database_service.dart';
import '../widgets/common/device_sidebar.dart';
import '../widgets/common/metrics_dashboard.dart';
import '../widgets/device_camera_roll.dart';
import '../widgets/history_view.dart';
import '../widgets/charts/sensor_chart.dart';
import '../widgets/dialogs/device_config_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AppController _controller = AppController();

  Device? _selectedDevice;
  bool _isSidebarOpen = true;
  bool _showHistory = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _controller.init();
    // Refresh UI every second for "Offline" timers
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool _isOffline(SensorData? data) {
    if (data == null) return true;
    // Check if data is older than 15 minutes
    return DateTime.now().difference(data.timestamp).inMinutes > 15;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe-Art Monitor'),
        leading: IconButton(
          icon: Icon(_isSidebarOpen ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _controller.isLoading,
        builder: (context, loading, _) {
          if (loading) return const Center(child: CircularProgressIndicator());

          return Row(
            children: [
              // 1. Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isSidebarOpen ? 280 : 0,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: 280,
                    minWidth: 280,
                    alignment: Alignment.topLeft,
                    child: ValueListenableBuilder<List<Device>>(
                      valueListenable: _controller.devices,
                      builder: (ctx, devices, _) {
                        return DeviceSidebar(
                          devices: devices,
                          selectedDevice:
                              _selectedDevice ??
                              (devices.isNotEmpty ? devices.first : null),
                          onDeviceSelected: (d) {
                            setState(() => _selectedDevice = d);
                            _controller.loadHistoryFor(d);
                          },
                          onAddDevice: () => _openDeviceDialog(null),
                          onEditDevice: (d) => _openDeviceDialog(d),
                          onDeleteDevice: (d) => _controller.deleteDevice(d),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 2. Main Content
              Expanded(child: _buildContentArea()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContentArea() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: ValueListenableBuilder<List<Device>>(
            valueListenable: _controller.devices,
            builder: (ctx, devices, _) {
              if (devices.isEmpty) { return const Center(child: Text("Add a device to begin")); }

              // Ensure we have a selection
              final currentDevice = _selectedDevice ?? devices.first;

              if (_showHistory) {
                return _buildHistoryView(currentDevice);
              }
              return _buildLiveView(devices, currentDevice);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _controller.isMonitoring,
                  builder: (ctx, isRunning, _) {
                    return ElevatedButton.icon(
                      onPressed: _controller.toggleMonitoring,
                      icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        isRunning ? 'Stop Monitoring' : 'Start Monitoring',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning
                            ? Colors.redAccent
                            : Colors.green,
                        foregroundColor: Colors.white,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: _controller.statusLog,
            builder: (_, log, _) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Text("Status: $log", style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveView(List<Device> devices, Device currentDevice) {
    return DeviceCameraRoll(
      devices: devices,
      selectedDevice: currentDevice,
      onDeviceChanged: (d) {
        setState(() => _selectedDevice = d);
        _controller.loadHistoryFor(d);
      },
      deviceViewBuilder: (device) {
        final initial = _controller.getLastKnownData(device.id);

        return StreamBuilder<SensorData>(
          stream: _controller.getDeviceStream(device.id),
          initialData: initial,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return MetricsDashboard(
              currentReading: snapshot.data,
              offline: _isOffline(data),
              isMonitoring: _controller.isMonitoring.value,
              offlineThresholdSeconds: 900,
              onSendStopAlarm: () => _controller.sendStopCommand(device),
              batteryMode: device.batteryMode,
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryView(Device device) {
    return ValueListenableBuilder<Map<String, List<Map<String, dynamic>>>>(
      valueListenable: _controller.historyCache,
      builder: (ctx, historyMap, _) {
        final history = historyMap[device.id] ?? [];
        return Column(
          children: [
            SizedBox(
              height: 200,
              child: SensorChart(historicalData: history, isAscending: false),
            ),
            Expanded(
              child: HistoryView(
                historicalData: history,
                onLoad: () => _controller.loadHistoryFor(device),
                // Note: You might need to refactor HistoryView to take the DB service
                // or just pass a simple callback. For now, we assume simple display.
                databaseService: DatabaseService(),
                isAscending: false,
                deviceId: device.id,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openDeviceDialog(Device? d) async {
    await showDialog(
      context: context,
      builder: (ctx) => DeviceConfigDialog(
        device: d,
        onSave: (newDev) async {
          if (d == null) {
            await _controller.addDevice(newDev, newDev.accessKey ?? '');
          } else {
            await _controller.updateDevice(newDev, newDev.accessKey);
          }
        },
      ),
    );
  }
}
