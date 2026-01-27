import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models.dart';

class MetricsDashboard extends StatelessWidget {
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
    this.dailyMHO,
    required this.isHighFrequencyAlarm,
  });

  @override
  Widget build(BuildContext context) {
    if (currentReading == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SpinningIcon(
              icon: isMonitoring
                  ? LucideIcons.loader2
                  : LucideIcons.pauseCircle,
              isSpinning: isMonitoring,
            ),
            const SizedBox(height: 24),
            Text(
              isMonitoring ? "Awaiting Sensor Data..." : "Monitoring Paused",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Alerts Area
          if (offline)
            _buildAlertBanner(
              context,
              "Device Offline",
              "Last signal received > ${offlineThresholdSeconds ~/ 60}m ago",
              Colors.grey[800]!,
              LucideIcons.wifiOff,
            ),

          if (isHighFrequencyAlarm)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildAlertBanner(
                context,
                "High Frequency Detected",
                "Rapid changes in sensor reporting interval",
                const Color(0xFFEF4444),
                LucideIcons.zap,
              ),
            ),

          const SizedBox(height: 24),

          // Primary Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _buildMetricCard(
                    context,
                    "TEMPERATURE",
                    "${currentReading!.temperature?.toStringAsFixed(1)}",
                    "°C",
                    LucideIcons.thermometer,
                    currentReading!.temperature! > 25 ? Colors.orange : null,
                  ),
                  _buildMetricCard(
                    context,
                    "HUMIDITY",
                    "${currentReading!.humidity?.toStringAsFixed(1)}",
                    "%",
                    LucideIcons.droplets,
                    Colors.blue,
                  ),
                  _buildMetricCard(
                    context,
                    "DEW POINT",
                    currentReading!.dewPoint.toStringAsFixed(1),
                    "°C",
                    LucideIcons.cloudRain,
                    Colors.purple,
                  ),
                  currentReading!.co2 != null
                      ? _buildMetricCard(
                          context,
                          "CO2 LEVEL",
                          "${currentReading!.co2?.toStringAsFixed(0)}",
                          "ppm",
                          LucideIcons.wind,
                          Colors.blueGrey,
                        )
                      : _buildMetricCard(
                          context,
                          "BATTERY",
                          batteryMode == 'percentage'
                              ? "${currentReading!.battery?.toStringAsFixed(0)}"
                              : "${currentReading!.battery?.toStringAsFixed(2)}",
                          batteryMode == 'percentage' ? "%" : "V",
                          LucideIcons.batteryCharging,
                          Colors.green,
                        ),
                ],
              );
            },
          ),

          // Secondary Info (MHO)
          if (dailyMHO != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.activity, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Daily Oscillation (MHO)",
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Thermal Stress Indicator",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${dailyMHO!.toStringAsFixed(2)} Δ",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: dailyMHO! > 5.0
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Button
          if (onSendStopAlarm != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSendStopAlarm,
                icon: const Icon(LucideIcons.bellOff, size: 18),
                label: const Text("SILENCE ALARM"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertBanner(
    BuildContext context,
    String title,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha:0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    String unit,
    IconData icon,
    Color? accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: accentColor ?? Colors.grey[400]),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.0,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpinningIcon extends StatefulWidget {
  final IconData icon;
  final bool isSpinning;

  const _SpinningIcon({required this.icon, required this.isSpinning});

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    if (widget.isSpinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(_SpinningIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning != oldWidget.isSpinning) {
      if (widget.isSpinning) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpinning) {
      return Icon(widget.icon, size: 48, color: Colors.grey[300]);
    }
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, size: 48, color: Colors.grey[300]),
    );
  }
}