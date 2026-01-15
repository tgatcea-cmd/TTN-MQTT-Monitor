import 'package:flutter/material.dart';

class HistoryView extends StatelessWidget {
  final List<Map<String, dynamic>> historicalData;
  final bool isLoading;
  final VoidCallback onLoad;

  const HistoryView({
    super.key,
    required this.historicalData,
    this.isLoading = false,
    required this.onLoad,
  });

  Widget _buildMiniMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (historicalData.isEmpty && !isLoading) {
      return Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "Loading historical data...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Text(
          "Historical Sensor Readings",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          "Last 100 readings from database",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        SizedBox(height: 20),

        // Historical Data List
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: historicalData.length,
          itemBuilder: (context, index) {
            final reading = historicalData[index];
            final timestamp = DateTime.parse(reading['timestamp']);
            final deviceId = reading['device_id'];
            final profileName = reading['profile_name'];

            return Card(
              margin: EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timestamp.toLocal().toString().split('.')[0],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "$profileName - $deviceId",
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        if (reading['temperature'] != null)
                          Expanded(
                            child: _buildMiniMetric(
                              "Temp",
                              "${reading['temperature'].toStringAsFixed(1)}°C",
                              Icons.thermostat,
                              Colors.orange,
                            ),
                          ),
                        if (reading['humidity'] != null)
                          Expanded(
                            child: _buildMiniMetric(
                              "Hum",
                              "${reading['humidity'].toStringAsFixed(1)}%",
                              Icons.water_drop,
                              Colors.blue,
                            ),
                          ),
                        if (reading['co2'] != null)
                          Expanded(
                            child: _buildMiniMetric(
                              "CO2",
                              "${reading['co2'].toStringAsFixed(0)} ppm",
                              Icons.air,
                              Colors.blueGrey,
                            ),
                          ),
                        if (reading['battery'] != null)
                          Expanded(
                            child: _buildMiniMetric(
                              "Batt",
                              "${reading['battery'].toStringAsFixed(2)}V",
                              Icons.battery_charging_full,
                              Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
