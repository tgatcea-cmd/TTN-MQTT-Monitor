import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models.dart';
import '../../data/services/app_controller.dart';
import '../../data/services/database_service.dart';
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
  Device? _selectedDevice;
  bool _showHistory = false;
  Timer? _refreshTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    final data = _controller.getLastKnownData(d.id);
    return _isOffline(data);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: isDesktop
              ? null
              : AppBar(
                  leading: IconButton(
                    icon: const Icon(LucideIcons.menu),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  title: const Text('Safe-Art Monitor'),
                  actions: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _controller.isMonitoring,
                      builder: (ctx, isRunning, _) {
                        return IconButton(
                          icon: Icon(
                            isRunning
                                ? LucideIcons.stopCircle
                                : LucideIcons.playCircle,
                            color: isRunning ? Colors.red : Colors.green,
                          ),
                          onPressed: _controller.toggleMonitoring,
                          tooltip: isRunning ? 'Stop Stream' : 'Start Stream',
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _showHistory
                            ? LucideIcons.layoutDashboard
                            : LucideIcons.history,
                      ),
                      onPressed: () =>
                          setState(() => _showHistory = !_showHistory),
                    ),
                  ],
                ),
          drawer: !isDesktop
              ? Drawer(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  shape: const RoundedRectangleBorder(),
                  child: _buildSidebarContent(),
                )
              : null,
          body: ValueListenableBuilder<bool>(
            valueListenable: _controller.isLoading,
            builder: (context, loading, _) {
              if (loading) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              return Row(
                children: [
                  if (isDesktop)
                    Container(
                      width: 280,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: _buildSidebarContent(),
                    ),
                  Expanded(child: _buildContentArea(isDesktop)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSidebarContent() {
    return ValueListenableBuilder<List<Device>>(
      valueListenable: _controller.devices,
      builder: (ctx, devices, _) {
        return ValueListenableBuilder<Map<String, bool>>(
          valueListenable: _controller.alarmStatus,
          builder: (context, alarmMap, _) {
            return DeviceSidebar(
              devices: devices,
              selectedDevice:
                  _selectedDevice ??
                  (devices.isNotEmpty ? devices.first : null),
              onDeviceSelected: (d) {
                setState(() => _selectedDevice = d);
                _controller.loadHistoryFor(d);
                if (Scaffold.of(context).isDrawerOpen) {
                  Navigator.pop(context);
                }
              },
              onAddDevice: () => _openDeviceDialog(null),
              onEditDevice: (d) => _openDeviceDialog(d),
              onDeleteDevice: (d) => _controller.deleteDevice(d),
              onExportDevice: (d) {
                showDialog(
                  context: context,
                  builder: (ctx) => ExportDeviceDialog(
                    device: d,
                    onExport: (password, includeSecrets) async {
                      // Make async

                      // 1. Generate the encrypted bytes
                      final bytes = await _controller.exportDeviceConfig(
                        d,
                        password,
                        includeSecrets,
                      );

                      if (bytes == null) {
                        // Handle error (Controller already prints debug error)
                        return;
                      }

                      // 2. SAVE THE FILE (This was missing)
                      try {
                        // A. Define filename
                        final fileName =
                            "${d.name.replaceAll(RegExp(r'\s+'), '_')}.sam";

                        // B. Platform specific saving
                        if (Platform.isAndroid || Platform.isIOS) {
                          // Mobile: Write to temp and Share
                          // Requires 'path_provider' and 'share_plus' packages

                          final dir = await getTemporaryDirectory();
                          final file = File('${dir.path}/$fileName');
                          await file.writeAsBytes(bytes);
                          await Share.shareXFiles([
                            XFile(file.path),
                          ], text: 'Configuration for ${d.name}');

                          debugPrint(
                            "File generated (implement Share/Save logic): ${bytes.length} bytes",
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Export generated (Add share_plus to save)",
                              ),
                            ),
                          );
                        } else {
                          // Desktop/Web: Use a file saver package or simple File write
                          // For testing on Desktop run:
                          final file = File('./$fileName');
                          await file.writeAsBytes(bytes);
                          debugPrint("Export bytes ready: ${bytes.length}");
                        }
                      } catch (e) {
                        debugPrint("Error saving file: $e");
                      }
                    },
                  ),
                );
              },
              onImportDevices: () {
                showDialog(
                  context: context,
                  builder: (ctx) => ImportDeviceDialog(
                    onImport: (files, password) async {
                      int successCount = 0;

                      for (var file in files) {
                        try {
                          Uint8List? fileBytes;

                          // 1. Get bytes correctly based on platform
                          if (file.bytes != null) {
                            // Web or Desktop (if cached)
                            fileBytes = file.bytes;
                          } else if (file.path != null) {
                            // Mobile / Desktop (Disk access)
                            final f = File(file.path!);
                            fileBytes = await f
                                .readAsBytes(); // READ AS BYTES, NOT STRING
                          }

                          if (fileBytes != null) {
                            // 2. Pass bytes to controller
                            await _controller.importDeviceConfig(
                              fileBytes,
                              password,
                            );
                            successCount++;
                            debugPrint("Loaded file: ${file.name}");
                          }
                        } catch (e) {
                          debugPrint("Error importing ${file.name}: $e");
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Error importing ${file.name}: Check password",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }

                      if (context.mounted && successCount > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Successfully imported $successCount devices",
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                );
              },
              isDeviceOffline: _checkDeviceStatus,
              alarmStatus: alarmMap,
            );
          },
        );
      },
    );
  }

  Widget _buildContentArea(bool isDesktop) {
    return ValueListenableBuilder<List<Device>>(
      valueListenable: _controller.devices,
      builder: (ctx, devices, _) {
        if (devices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.server, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  "No Devices Configured",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _openDeviceDialog(null),
                  child: const Text("Add First Device"),
                ),
              ],
            ),
          );
        }

        final currentDevice = _selectedDevice ?? devices.first;

        return Column(
          children: [
            if (isDesktop) _buildDesktopHeader(isDesktop),
            Expanded(
              child: Padding(
                padding: isDesktop
                    ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
                    : const EdgeInsets.all(16),
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

  Widget _buildDesktopHeader(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showHistory ? "Historical Analysis" : "Live Monitor",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<String>(
                  valueListenable: _controller.statusLog,
                  builder: (_, log, _) => Text(
                    log.isNotEmpty ? log : "System Operational",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _controller.isMonitoring,
            builder: (ctx, isRunning, _) {
              return OutlinedButton.icon(
                onPressed: _controller.toggleMonitoring,
                icon: Icon(
                  isRunning ? LucideIcons.square : LucideIcons.play,
                  size: 16,
                  color: isRunning ? Colors.red : Colors.green,
                ),
                label: Text(isRunning ? "Stop Stream" : "Start Stream"),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isRunning
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                  foregroundColor: Theme.of(context).primaryColor,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => setState(() => _showHistory = !_showHistory),
            icon: Icon(
              _showHistory ? LucideIcons.layoutDashboard : LucideIcons.history,
            ),
            tooltip: _showHistory ? "Back to Live" : "View History",
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
            return ValueListenableBuilder<Map<String, bool>>(
              valueListenable: _controller.alarmStatus,
              builder: (ctx, alarmMap, _) {
                final isAlarming = alarmMap[device.id] ?? false;
                return MetricsDashboard(
                  currentReading: snapshot.data,
                  offline: _isOffline(snapshot.data),
                  isMonitoring: _controller.isMonitoring.value,
                  offlineThresholdSeconds: 900,
                  onSendStopAlarm: device.canControl
                      ? () => _controller.sendStopCommand(device)
                      : null,
                  batteryMode: device.batteryMode,
                  isHighFrequencyAlarm: isAlarming,
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
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: SensorChart(historicalData: history, isAscending: false),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: HistoryView(
                  historicalData: history,
                  onLoad: () => _controller.loadHistoryFor(device),
                  databaseService: DatabaseService(),
                  isAscending: false,
                  deviceId: device.id,
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
}
