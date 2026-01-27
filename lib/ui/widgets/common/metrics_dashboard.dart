import 'package:flutter/material.dart';
import '../../../data/models.dart';

class MetricsDashboard extends StatefulWidget {
  final SensorData? currentReading;
  final bool offline;
  final bool isMonitoring;
  final int offlineThresholdSeconds;
  final VoidCallback? onSendStopAlarm;
  final String batteryMode;
  final double? dailyMHO;
  final bool isHighFrequencyAlarm;

  const MetricsDashboard({
    super.key,
    required this.currentReading,
    required this.offline,
    required this.isMonitoring,
    required this.offlineThresholdSeconds,
    this.onSendStopAlarm,
    this.batteryMode = 'voltage',
    this.dailyMHO, // Added to constructor
    required this.isHighFrequencyAlarm,
  });

  State<MetricsDashboard> createState() => _MetricsDashboardState();
}

class _MetricsDashboardState extends State<MetricsDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _alertController;
  late Animation<double> _alertAnimation;

  DateTime? _lastTimestamp;
  bool _isHighFrequency = false;

  @override
  void initState() {
    super.initState();
    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _alertAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _alertController, curve: Curves.easeInOut),
    );

    _lastTimestamp = widget.currentReading?.timestamp;
  }

  @override
  void dispose() {
    _alertController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MetricsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newReading = widget.currentReading;
    final oldReading = oldWidget.currentReading;

    // Only recalculate if we have a NEW reading with a different timestamp
    if (newReading != null &&
        (oldReading == null || newReading.timestamp != oldReading.timestamp)) {
      if (_lastTimestamp != null) {
        final difference = newReading.timestamp.difference(_lastTimestamp!);

        // Alarm Condition: Frequency is High (Interval <= 5 minutes)
        if (difference.compareTo(const Duration(minutes: 5)) <= 0) {
          setState(() {
            _isHighFrequency = true;
          });
        } else {
          setState(() {
            _isHighFrequency = false;
          });
        }
      }
      _lastTimestamp = newReading.timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Idle State
    if (widget.currentReading == null) {
      if (!widget.isMonitoring) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pause_circle_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                "System Idle",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
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

    // 2. Main Dashboard Content Wrapped in AnimatedBuilder for Glow
    return AnimatedBuilder(
      animation: _alertAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isHighFrequencyAlarm
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.6),
                      blurRadius: _alertAnimation.value + 10,
                      spreadRadius: _alertAnimation.value * 0.2,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final metricsWidget = Column(
      children: [
        if (widget.offline) _buildOfflineBanner(),

        // High Frequency Warning Banner
        if (widget.isHighFrequencyAlarm)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _alertController,
                  child: const Icon(
                    Icons.speed,
                    color: Colors.yellow,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "HIGH FREQUENCY DETECTED",
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
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                "Temperature",
                "${widget.currentReading!.temperature?.toStringAsFixed(1)}°C",
                Icons.thermostat,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                "Humidity",
                "${widget.currentReading!.humidity?.toStringAsFixed(1)}%",
                Icons.water_drop,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                "Dew Point",
                "${widget.currentReading!.dewPoint.toStringAsFixed(1)}°C",
                Icons.cloud_queue,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: widget.currentReading!.co2 != null
                  ? _buildMetricCard(
                      "CO2",
                      "${widget.currentReading!.co2?.toStringAsFixed(0)} ppm",
                      Icons.air,
                      Colors.blueGrey,
                    )
                  : _buildMetricCard(
                      widget.batteryMode == 'percentage'
                          ? "Battery Level"
                          : "Battery Voltage",
                      widget.batteryMode == 'percentage'
                          ? "${widget.currentReading!.battery?.toStringAsFixed(0) ?? '--'} %"
                          : "${widget.currentReading!.battery?.toStringAsFixed(2) ?? '--'} V",
                      widget.batteryMode == 'percentage'
                          ? Icons.battery_full
                          : Icons.battery_charging_full,
                      Colors.green,
                    ),
            ),
          ],
        ),

        // MHO (Daily Oscillation) Box
        if (widget.dailyMHO != null) ...[
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
                    Text(
                      "Daily Oscillation (MHO)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    Text(
                      "Thermal stress indicator",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  "${widget.dailyMHO!.toStringAsFixed(2)} Δ°C",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.dailyMHO! > 5.0 ? Colors.red : Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Stop Alarm Button
        if (widget.onSendStopAlarm != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onSendStopAlarm,
              icon: const Icon(Icons.notifications_off),
              label: const Text("STOP ALARM (DOWNLINK)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ],
    );

    // Apply grayscale if offline
    if (widget.offline) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
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
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            "DEVICE OFFLINE (> ${widget.offlineThresholdSeconds ~/ 60} mins)",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
