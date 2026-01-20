import 'package:flutter/material.dart';
import '../models.dart';

class MetricsDashboard extends StatelessWidget {
  final SensorData? currentReading;
  final bool offline;
  final bool isMonitoring;
  final int offlineThresholdSeconds;
  final VoidCallback? onSendStopAlarm;
  final String batteryMode;
  final double? dailyMHO; // Restored parameter

  const MetricsDashboard({
    super.key,
    required this.currentReading,
    required this.offline,
    required this.isMonitoring,
    required this.offlineThresholdSeconds,
    this.onSendStopAlarm,
    this.batteryMode = 'voltage',
    this.dailyMHO, // Added to constructor
  });

  @override
  Widget build(BuildContext context) {
    // 1. Idle State
    if (currentReading == null) {
      if (!isMonitoring) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pause_circle_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text("System Idle", style: TextStyle(fontSize: 18, color: Colors.grey)),
            ],
          ),
        );
      }
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Waiting for data...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // 2. Main Dashboard Content
    final metricsWidget = Column(
      children: [
        if (offline) _buildOfflineBanner(),
        
        // CO2 / Fire Warning
        if ((currentReading!.co2 ?? 0) > 1000)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 10),
                Text("FIRE RISK DETECTED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

        // Metrics Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricCard("Temperature", "${currentReading!.temperature?.toStringAsFixed(1)}°C", Icons.thermostat, Colors.orange),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard("Humidity", "${currentReading!.humidity?.toStringAsFixed(1)}%", Icons.water_drop, Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard("Dew Point", "${currentReading!.dewPoint.toStringAsFixed(1)}°C", Icons.cloud_queue, Colors.purple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: currentReading!.co2 != null
                  ? _buildMetricCard("CO2", "${currentReading!.co2?.toStringAsFixed(0)} ppm", Icons.air, Colors.blueGrey)
                  : _buildMetricCard(
                      batteryMode == 'percentage' ? "Battery Level" : "Battery Voltage",
                      batteryMode == 'percentage' 
                          ? "${currentReading!.battery?.toStringAsFixed(0) ?? '--'} %" 
                          : "${currentReading!.battery?.toStringAsFixed(2) ?? '--'} V",
                      batteryMode == 'percentage' ? Icons.battery_full : Icons.battery_charging_full,
                      Colors.green,
                    ),
            ),
          ],
        ),

        // MHO (Daily Oscillation) Box
        if (dailyMHO != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Daily Oscillation (MHO)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    Text("Thermal stress indicator", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                Text(
                  "${dailyMHO!.toStringAsFixed(2)} Δ°C",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: dailyMHO! > 5.0 ? Colors.red : Colors.indigo),
                ),
              ],
            ),
          ),
        ],

        // Stop Alarm Button
        if (onSendStopAlarm != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSendStopAlarm,
              icon: const Icon(Icons.notifications_off),
              label: const Text("STOP ALARM (DOWNLINK)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ]
      ],
    );

    // Apply grayscale if offline
    if (offline) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: Opacity(opacity: 0.8, child: metricsWidget),
      );
    }

    return metricsWidget;
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            "DEVICE OFFLINE (> ${offlineThresholdSeconds ~/ 60} mins)",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}