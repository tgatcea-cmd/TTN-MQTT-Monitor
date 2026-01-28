// ui/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models.dart';
import '../../data/services/app_controller.dart';
import '../../data/services/database_service.dart';
import '../theme.dart';
import '../widgets/common/device_sidebar.dart';
import '../widgets/common/metrics_dashboard.dart';
import '../widgets/device_camera_roll.dart';
import '../widgets/history_view.dart';
import '../widgets/charts/sensor_chart.dart';
import '../widgets/dialogs/device_config_dialog.dart';
import '../widgets/dialogs/export_device_dialog.dart';
import '../widgets/dialogs/import_device_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AppController _controller = AppController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  Device? _selectedDevice;
  bool _showHistory = false;
  Timer? _refreshTimer;

  // ---------------------------------------------------------------------------
  // Lifecycle & Logic
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _controller.init();
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
    return DateTime.now().difference(data.timestamp).inMinutes > 15;
  }

  bool _checkDeviceStatus(Device d) {
    return _isOffline(_controller.getLastKnownData(d.id));
  }

  void _onDeviceSelected(Device d) {
    setState(() => _selectedDevice = d);
    _controller.loadHistoryFor(d);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1024;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          
          // --- MOBILE APP BAR ---
          appBar: isDesktop
              ? null
              : AppBar(
                  leading: IconButton(
                    icon: const Icon(LucideIcons.menu),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  title: const Text('Safe-Art'),
                  actions: [
                    // CRITICAL FIX: Added Monitor Controls to Mobile AppBar
                    ValueListenableBuilder<bool>(
                      valueListenable: _controller.isMonitoring,
                      builder: (ctx, isRunning, _) {
                        return IconButton(
                          icon: Icon(
                            isRunning ? LucideIcons.stopCircle : LucideIcons.playCircle,
                            color: isRunning ? AppTheme.error : AppTheme.success,
                          ),
                          onPressed: _controller.toggleMonitoring,
                          tooltip: isRunning ? 'Stop Stream' : 'Start Stream',
                        );
                      },
                    ),
                    // History Toggle
                    IconButton(
                      icon: Icon(
                        _showHistory ? LucideIcons.layoutDashboard : LucideIcons.history,
                        color: AppTheme.secondary,
                      ),
                      onPressed: () => setState(() => _showHistory = !_showHistory),
                      tooltip: _showHistory ? "Back to Live" : "View History",
                    ),
                  ],
                ),
          
          // --- MOBILE DRAWER ---
          drawer: !isDesktop
              ? Drawer(
                  backgroundColor: AppTheme.surface,
                  surfaceTintColor: Colors.transparent,
                  shape: const RoundedRectangleBorder(),
                  child: _buildSidebar(isMobile: true),
                )
              : null,
          
          // --- MAIN BODY ---
          body: ValueListenableBuilder<bool>(
            valueListenable: _controller.isLoading,
            builder: (context, loading, _) {
              if (loading) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }

              if (isDesktop) {
                return Row(
                  children: [
                    SizedBox(width: 280, child: _buildSidebar(isMobile: false)),
                    VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                    Expanded(
                      child: Container(
                        color: AppTheme.background,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1300),
                            child: _buildMainContent(isDesktop),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return _buildMainContent(isDesktop);
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Structural Components
  // ---------------------------------------------------------------------------
  
  Widget _buildSidebar({required bool isMobile}) {
    return ValueListenableBuilder<List<Device>>(
      valueListenable: _controller.devices,
      builder: (ctx, devices, _) {
        return ValueListenableBuilder<Map<String, bool>>(
          valueListenable: _controller.alarmStatus,
          builder: (context, alarmMap, _) {
            return DeviceSidebar(
              devices: devices,
              selectedDevice: _selectedDevice ?? (devices.isNotEmpty ? devices.first : null),
              onDeviceSelected: _onDeviceSelected,
              onAddDevice: () => _openDeviceDialog(null),
              onEditDevice: (d) => _openDeviceDialog(d),
              onDeleteDevice: (d) => _controller.deleteDevice(d),
              onExportDevice: _handleExportDevice,
              onImportDevices: _handleImportDevices,
              isDeviceOffline: _checkDeviceStatus,
              alarmStatus: alarmMap,
            );
          },
        );
      },
    );
  }

  Widget _buildMainContent(bool isDesktop) {
    return ValueListenableBuilder<List<Device>>(
      valueListenable: _controller.devices,
      builder: (ctx, devices, _) {
        if (devices.isEmpty) return _buildEmptyState();

        final currentDevice = _selectedDevice ?? devices.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Desktop Header (Only shows on Desktop)
            if (isDesktop) _buildDesktopHeader(),

            // Content Area (Scrolls internally)
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? AppTheme.spacing32 : AppTheme.spacing16),
                child: _showHistory
                    ? _buildHistoryView(currentDevice)
                    : _buildLiveView(devices, currentDevice),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _showHistory ? "Historical Analysis" : "Live Monitor",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<String>(
                valueListenable: _controller.statusLog,
                builder: (_, log, _) => Text(
                  log.isNotEmpty ? log : "System Operational",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13, 
                    color: AppTheme.tertiary
                  ),
                ),
              ),
            ],
          ),
          
          Row(
            children: [
               ValueListenableBuilder<bool>(
                valueListenable: _controller.isMonitoring,
                builder: (ctx, isRunning, _) {
                  return OutlinedButton.icon(
                    onPressed: _controller.toggleMonitoring,
                    icon: Icon(
                      isRunning ? LucideIcons.square : LucideIcons.play,
                      size: 16,
                      color: isRunning ? AppTheme.error : AppTheme.success,
                    ),
                    label: Text(isRunning ? "Stop Stream" : "Start Stream"),
                  );
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => setState(() => _showHistory = !_showHistory),
                icon: Icon(
                  _showHistory ? LucideIcons.layoutDashboard : LucideIcons.history,
                  color: AppTheme.primary,
                ),
                tooltip: _showHistory ? "Back to Live" : "View History",
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.server, size: 64, color: AppTheme.border),
          const SizedBox(height: 24),
          Text("No Devices Configured", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openDeviceDialog(null),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text("Add First Device"),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveView(List<Device> devices, Device currentDevice) {
    return DeviceCameraRoll(
      devices: devices,
      selectedDevice: currentDevice,
      onDeviceChanged: _onDeviceSelected,
      deviceViewBuilder: (device) {
        final initial = _controller.getLastKnownData(device.id);
        return StreamBuilder<SensorData>(
          stream: _controller.getDeviceStream(device.id),
          initialData: initial,
          builder: (context, snapshot) {
            return ValueListenableBuilder<Map<String, bool>>(
              valueListenable: _controller.alarmStatus,
              builder: (ctx, alarmMap, _) {
                return MetricsDashboard(
                  currentReading: snapshot.data,
                  offline: _isOffline(snapshot.data),
                  isMonitoring: _controller.isMonitoring.value,
                  offlineThresholdSeconds: 900,
                  onSendStopAlarm: device.canControl
                      ? () => _controller.sendStopCommand(device)
                      : null,
                  batteryMode: device.batteryMode,
                  isHighFrequencyAlarm: alarmMap[device.id] ?? false,
                );
              },
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
            // Chart Area (Fixed Height)
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: SensorChart(historicalData: history, isAscending: false),
            ),
            const SizedBox(height: 24),
            // List Area (Fills remaining space)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: HistoryView(
                    historicalData: history,
                    onLoad: () => _controller.loadHistoryFor(device),
                    databaseService: DatabaseService(),
                    isAscending: false,
                    deviceId: device.id,
                  ),
                ),
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

  void _handleExportDevice(Device d) {
    showDialog(
      context: context,
      builder: (ctx) => ExportDeviceDialog(
        device: d,
        onExport: (password, includeSecrets) async {
          final bytes = await _controller.exportDeviceConfig(d, password, includeSecrets);
          if (bytes == null) return;

          try {
            final fileName = "${d.name.replaceAll(RegExp(r'\s+'), '_')}.sam";
            if (Platform.isAndroid || Platform.isIOS) {
              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/$fileName');
              await file.writeAsBytes(bytes);
              await Share.shareXFiles([XFile(file.path)], text: 'Config for ${d.name}');
            } else {
              debugPrint("Exported ${bytes.length} bytes to $fileName");
            }
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Export ready")));
            }
          } catch (e) {
            debugPrint("Export error: $e");
          }
        },
      ),
    );
  }

  void _handleImportDevices() {
    showDialog(
      context: context,
      builder: (ctx) => ImportDeviceDialog(
        onImport: (files, password) async {
          int successCount = 0;
          for (var file in files) {
             try {
                Uint8List? fileBytes;
                if (file.bytes != null) fileBytes = file.bytes;
                else if (file.path != null) fileBytes = await File(file.path!).readAsBytes();
                
                if (fileBytes != null) {
                  await _controller.importDeviceConfig(fileBytes, password);
                  successCount++;
                }
             } catch (e) {
               debugPrint("Import error: $e");
             }
          }
          if (mounted && successCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Imported $successCount devices"), backgroundColor: AppTheme.success)
            );
          }
        },
      ),
    );
  }
}