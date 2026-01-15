import 'package:flutter/material.dart';
import 'dart:async';
import '../database_service.dart';

class HistoryView extends StatefulWidget {
  final List<Map<String, dynamic>> historicalData;
  final bool isLoading;
  final VoidCallback onLoad;
  final DatabaseService databaseService;

  const HistoryView({
    super.key,
    required this.historicalData,
    this.isLoading = false,
    required this.onLoad,
    required this.databaseService,
  });

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late List<Map<String, dynamic>> _liveData;
  late StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _liveData = List.from(widget.historicalData);
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    // Subscribe to periodic updates (every 2 seconds)
    _subscription = widget.databaseService.subscribeToReadings().listen(
      (newReadings) {
        if (!mounted) return;
        setState(() {
          // Merge new readings, keeping only most recent 100
          final Set<String> existingIds = {};
          for (var item in _liveData) {
            existingIds.add('${item['id']}');
          }

          for (var reading in newReadings) {
            final id = '${reading['id']}';
            if (!existingIds.contains(id)) {
              _liveData.insert(0, reading);
              existingIds.add(id);
            }
          }

          // Keep only the most recent 100 readings
          if (_liveData.length > 100) {
            _liveData = _liveData.sublist(0, 100);
          }
        });
      },
      onError: (error) {
        debugPrint('Real-time subscription error: $error');
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

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
    if (_liveData.isEmpty && !widget.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              "Waiting for sensor data...",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              "Live updates will appear here",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Text(
          "Live Sensor Readings",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          "${_liveData.length} readings (auto-updating)",
          style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 20),

        // Historical Data List with Live Updates
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _liveData.length,
            itemBuilder: (context, index) {
              final reading = _liveData[index];
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
        ),
      ],
    );
  }
}
