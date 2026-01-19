import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/iot_brain.dart';
import '../services/device_service.dart';
import '../models/device.dart';
import '../design/cyber_theme.dart';
import '../ui/visuals.dart';
import '../ui/cyber_sidebar.dart';
import '../widgets/device_config_dialog.dart';

class SafeArtDashboard extends StatefulWidget {
  const SafeArtDashboard({super.key});

  @override
  State<SafeArtDashboard> createState() => _SafeArtDashboardState();
}

class _SafeArtDashboardState extends State<SafeArtDashboard> {
  final DeviceService _deviceService = DeviceService();
  
  // UI State
  List<Device> _devices = [];
  bool _isLoading = true;
  bool _isSidebarOpen = true; // NEW: Toggle state

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _deviceService.init();
    await _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    final rawDevices = await _deviceService.getAllDevices();
    // FIXED: Correctly assign the returned list with keys
    final devicesWithKeys = await _deviceService.loadAllApiKeys(rawDevices);
    
    if (mounted) {
      setState(() {
        _devices = devicesWithKeys;
        _isLoading = false;
      });
      
      final brain = context.read<IoTBrain>();
      // Auto-connect logic
      if (brain.activeDevice == null && _devices.isNotEmpty) {
        // Find if we have a stored preference or just pick first
        brain.switchDevice(_devices.first);
      }
    }
  }

  void _openDeviceDialog([Device? device]) {
    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.dark().copyWith(
          dialogTheme: const DialogThemeData(
            backgroundColor: CyberTheme.bgSlate,
          ),
          colorScheme: const ColorScheme.dark(primary: CyberTheme.neonSafe),
        ),
        child: DeviceConfigDialog(
          device: device,
          onSave: (newDevice) async {
            if (device == null) {
              await _deviceService.addDevice(
                name: newDevice.name,
                appId: newDevice.appId,
                broker: newDevice.broker,
                deviceEui: newDevice.deviceEui,
                accessKey: newDevice.accessKey ?? '',
                canControl: newDevice.canControl,
                batteryMode: newDevice.batteryMode,
              );
            } else {
              await _deviceService.updateDevice(
                id: device.id,
                name: newDevice.name,
                broker: newDevice.broker,
                deviceEui: newDevice.deviceEui,
                accessKey: newDevice.accessKey, // Pass the key to update it
                canControl: newDevice.canControl,
                deviceType: newDevice.deviceType,
                batteryMode: newDevice.batteryMode,
              );
            }
            await _refreshDevices();
          },
        ),
      ),
    );
  }

  Future<void> _deleteDevice(Device device) async {
    await _deviceService.deleteDevice(device.id);
    await _refreshDevices();
  }

  @override
  Widget build(BuildContext context) {
    final brain = context.watch<IoTBrain>();
    final currentData = brain.activeDevice != null 
        ? brain.latestReadings[brain.activeDevice!.id] 
        : null;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          const Positioned.fill(child: GridBackground()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [Colors.transparent, CyberTheme.bgDeep.withValues(alpha: 0.9)],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Row(
              children: [
                // 1. COLLAPSIBLE SIDEBAR
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isSidebarOpen ? 280 : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: 280,
                      minWidth: 280,
                      alignment: Alignment.topLeft,
                      child: CyberSidebar(
                        devices: _devices,
                        selectedDevice: brain.activeDevice,
                        onSelect: (device) => brain.switchDevice(device),
                        onAdd: () => _openDeviceDialog(),
                        onEdit: (dev) => _openDeviceDialog(dev),
                        onDelete: (dev) => _deleteDevice(dev),
                      ),
                    ),
                  ),
                ),

                // 2. MAIN DASHBOARD CONTENT
                Expanded(
                  child: Column(
                    children: [
                      // Header with Toggle Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isSidebarOpen ? Icons.menu_open : Icons.menu, 
                                color: CyberTheme.neonSafe
                              ),
                              onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("SAFE-ART OS", style: CyberTheme.theme.textTheme.labelSmall),
                                Text(
                                  brain.activeDevice?.name.toUpperCase() ?? "SIN DISPOSITIVO",
                                  style: CyberTheme.theme.textTheme.displayMedium?.copyWith(fontSize: 20),
                                ),
                              ],
                            ),
                            const Spacer(),
                            _buildConnectionBadge(brain.isConnected),
                          ],
                        ),
                      ),

                      if (_isLoading)
                        const Expanded(child: Center(child: CircularProgressIndicator()))
                      else if (_devices.isEmpty)
                        _buildEmptyState()
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                _buildEnvironmentDeck(currentData),
                                const SizedBox(height: 20),
                                _buildAnalyticsGrid(brain),
                                const SizedBox(height: 20),
                                _buildCommandTerminal(brain),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... (Rest of your widgets: _buildEmptyState, _buildConnectionBadge, etc. remain exactly the same)
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.dns, size: 64, color: CyberTheme.textDim),
          const SizedBox(height: 20),
          Text("NO SE DETECTAN NODOS", style: CyberTheme.theme.textTheme.bodyLarge),
          TextButton(
            onPressed: () => _openDeviceDialog(),
            child: const Text("CONFIGURAR PRIMER NODO >", style: TextStyle(color: CyberTheme.neonSafe)),
          )
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? CyberTheme.neonSafe.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        border: Border.all(color: isOnline ? CyberTheme.neonSafe : Colors.red),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOnline ? "ONLINE" : "OFFLINE",
        style: CyberTheme.theme.textTheme.labelSmall?.copyWith(
          color: isOnline ? CyberTheme.neonSafe : Colors.red,
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  Widget _buildEnvironmentDeck(dynamic data) {
    double temp = data?.temperature ?? 0.0;
    double hum = data?.humidity ?? 0.0;
    
    return CyberGlass(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            SciFiGauge(
              value: temp,
              max: 50,
              label: "TEMPERATURA",
              unit: "°C",
              color: temp > 30 ? CyberTheme.neonCrit : CyberTheme.neonSafe,
            ),
            Container(width: 1, height: 80, color: Colors.white10),
            SciFiGauge(
              value: hum,
              max: 100,
              label: "HUMEDAD",
              unit: "%",
              color: CyberTheme.neonSafe,
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildAnalyticsGrid(IoTBrain brain) {
    if (brain.activeDevice == null) return const SizedBox.shrink();
    
    final mho = brain.getMHO(brain.activeDevice!.id);
    final data = brain.latestReadings[brain.activeDevice!.id];
    final dew = data?.dewPoint ?? 0.0;
    final batt = data?.battery ?? 0.0;

    return Row(
      children: [
        Expanded(child: _buildInfoTile("PUNTO ROCÍO", "${dew.toStringAsFixed(1)}°", Icons.water_drop)),
        const SizedBox(width: 12),
        Expanded(child: _buildInfoTile("MHO (OSC.)", "${mho.toStringAsFixed(1)}Δ", Icons.show_chart)),
        const SizedBox(width: 12),
        Expanded(child: _buildInfoTile("BATERÍA", "${batt.toStringAsFixed(1)}V", Icons.battery_charging_full)),
      ],
    );
  }

  Widget _buildInfoTile(String label, String val, IconData icon) {
    return CyberGlass(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, size: 16, color: CyberTheme.textDim),
            const SizedBox(height: 8),
            Text(val, style: CyberTheme.theme.textTheme.displayMedium?.copyWith(fontSize: 20)),
            Text(label, style: CyberTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 8)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandTerminal(IoTBrain brain) {
    return Column(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            border: Border.all(color: CyberTheme.textDim.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("// SYSTEM_LOGS", style: TextStyle(color: CyberTheme.neonWarn, fontFamily: 'monospace', fontSize: 10)),
              const Divider(color: Colors.white10),
              Expanded(
                child: ListView.builder(
                  itemCount: brain.commandLog.length,
                  itemBuilder: (ctx, i) => Text(
                    brain.commandLog[i], 
                    style: TextStyle(color: i == 0 ? CyberTheme.neonSafe : CyberTheme.textDim, fontFamily: 'monospace', fontSize: 10)
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (brain.activeDevice?.canControl == true)
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              brain.sendResetCommand();
            },
            child: CyberGlass(
              tint: CyberTheme.neonCrit,
              opacity: 0.1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.warning_amber, color: CyberTheme.neonCrit),
                    SizedBox(width: 10),
                    Text("EJECUTAR RESET DE ALARMA", style: TextStyle(color: CyberTheme.neonCrit, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}