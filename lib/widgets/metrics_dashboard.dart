import 'package:flutter/material.dart';
import '../models.dart';

class MetricsDashboard extends StatelessWidget {
  final SensorData? currentReading;
  final bool offline;
  final bool isMonitoring; // NEW: Added to track monitoring state
  final int offlineThresholdSeconds;
  final TTNProfile? selectedProfile;
  final VoidCallback? onSendStopAlarm;

  const MetricsDashboard({
    super.key,
    required this.currentReading,
    required this.offline,
    required this.isMonitoring, // NEW
    required this.offlineThresholdSeconds,
    required this.selectedProfile,
    this.onSendStopAlarm,
  });

  bool isDeviceOffline(DateTime? timestamp) {
    if (timestamp == null) return true;
    return timestamp
        .add(Duration(seconds: offlineThresholdSeconds))
        .isBefore(DateTime.now());
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we don't have an in-memory reading
    if (currentReading == null) {
      // CASE 1: Monitoring is OFF - Show Idle Message
      if (!isMonitoring) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pause_circle_outline, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                "System Idle",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Start monitoring to receive live sensor data",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      // CASE 2: Monitoring is ON but no data yet - Show Loading
      return Column(
        children: [
          if (offline)
            _buildOfflineBanner(),
          Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  "Waiting for sensor packet...",
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  "(This can take up to 15 mins)",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Normal State with Data
    return Column(
      children: [
        // Offline Warning
        if (offline) _buildOfflineBanner(),

        // Alert Banner
        if ((currentReading!.co2 ?? 0) > 1000)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "FIRE RISK DETECTED",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

        // Metrics Grid
        Builder(
          builder: (context) {
            final metricsArea = Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        "Temperature",
                        "${currentReading!.temperature?.toStringAsFixed(1)}°C",
                        Icons.thermostat,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        "Humidity",
                        "${currentReading!.humidity?.toStringAsFixed(1)}%",
                        Icons.water_drop,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        "Dew Point",
                        "${currentReading!.dewPoint.toStringAsFixed(1)}°C",
                        Icons.cloud_queue,
                        Colors.purple,
                      ),
                    ),
                    SizedBox(width: 10),
                    (currentReading!.co2 != null)
                        ? Expanded(
                            child: _buildMetricCard(
                              "CO2",
                              "${currentReading!.co2?.toStringAsFixed(0)} ppm",
                              Icons.air,
                              Colors.blueGrey,
                            ),
                          )
                        : Expanded(
                            child: _buildMetricCard(
                              "Battery",
                              "${currentReading!.battery?.toStringAsFixed(2) ?? '--'} V",
                              Icons.battery_charging_full,
                              Colors.green,
                            ),
                          ),
                  ],
                ),
              ],
            );

            if (offline) {
              const List<double> greyMatrix = <double>[
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ];
              return ColorFiltered(
                colorFilter: const ColorFilter.matrix(greyMatrix),
                child: Opacity(opacity: 0.95, child: metricsArea),
              );
            }

            return metricsArea;
          },
        ),

        SizedBox(height: 20),

        // Stop Alarm Button (Only for controllable profiles)
        if (selectedProfile?.canControl == true)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSendStopAlarm,
              icon: Icon(Icons.notifications_off),
              label: Text("STOP ALARM (DOWNLINK)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(20),
                textStyle:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white),
          SizedBox(width: 10),
          Text(
            "DEVICE OFFLINE (No data > ${(offlineThresholdSeconds ~/ 60)} mins)",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}