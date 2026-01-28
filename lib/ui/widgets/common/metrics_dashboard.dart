// ui/widgets/common/metrics_dashboard.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models.dart';
import '../../theme.dart';

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
    // 1. Loading State
    if (currentReading == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SpinningIcon(
              icon: isMonitoring ? LucideIcons.loader2 : LucideIcons.pauseCircle,
              isSpinning: isMonitoring,
            ),
            const SizedBox(height: 24),
            Text(
              isMonitoring ? "Acquiring Signal..." : "Monitoring Paused",
              style: AppTheme.theme.textTheme.bodyMedium?.copyWith(color: AppTheme.tertiary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      // Padding handled by parent now, but we add bottom padding for scroll space
      padding: const EdgeInsets.only(bottom: 48), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          // 2. Alert Banners (Stacked)
          if (offline)
            _buildAlertBanner(
              context,
              "Signal Lost",
              "Device offline for >${offlineThresholdSeconds ~/ 60} minutes",
              AppTheme.secondary,
              LucideIcons.wifiOff,
            ),

          if (isHighFrequencyAlarm)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildAlertBanner(
                context,
                "Anomaly Detected",
                "High frequency reporting pattern observed",
                AppTheme.warning,
                LucideIcons.zap,
              ),
            ),

          const SizedBox(height: 24),

          // 3. Primary Metrics Grid
          // We use LayoutBuilder to switch between 2 columns (mobile) and 4 (desktop)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // Breakpoint logic: < 600px = 2 cols, > 600px = 4 cols
              final int crossAxisCount = width < 600 ? 2 : 4;
              
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2, // Slightly taller for elegance
                children: [
                  _buildMetricCard(
                    context,
                    "Temperature",
                    currentReading!.temperature?.toStringAsFixed(1) ?? "--",
                    "°C",
                    currentReading!.temperature != null && currentReading!.temperature! > 25 
                      ? AppTheme.warning 
                      : null,
                  ),
                  _buildMetricCard(
                    context,
                    "Humidity",
                    currentReading!.humidity?.toStringAsFixed(1) ?? "--",
                    "%",
                    null,
                  ),
                  _buildMetricCard(
                    context,
                    "Dew Point",
                    currentReading!.dewPoint.toStringAsFixed(1),
                    "°C",
                    null,
                  ),
                  currentReading!.co2 != null
                      ? _buildMetricCard(
                          context,
                          "CO2 Level",
                          currentReading!.co2?.toStringAsFixed(0) ?? "--",
                          "ppm",
                          null,
                        )
                      : _buildMetricCard(
                          context,
                          "Power",
                          batteryMode == 'percentage'
                              ? currentReading!.battery?.toStringAsFixed(0) ?? "--"
                              : currentReading!.battery?.toStringAsFixed(2) ?? "--",
                          batteryMode == 'percentage' ? "%" : "V",
                          null,
                        ),
                ],
              );
            },
          ),

          // 4. Secondary Metrics (Wide Cards)
          if (dailyMHO != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.activity, size: 24, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "OSCILLATION INDEX (MHO)",
                          style: AppTheme.theme.textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Thermal Stress Indicator",
                          style: AppTheme.theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${dailyMHO!.toStringAsFixed(2)} Δ",
                    style: AppTheme.theme.textTheme.displayLarge?.copyWith(
                      fontSize: 24,
                      color: dailyMHO! > 5.0 ? AppTheme.error : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 5. Critical Actions
          if (onSendStopAlarm != null) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSendStopAlarm,
                icon: const Icon(LucideIcons.bellOff, size: 18),
                label: const Text("SILENCE ACTIVE ALARM"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
  // ---------------------------------------------------------------------------

  Widget _buildAlertBanner(BuildContext context, String title, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTheme.theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: AppTheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    String unit,
    Color? valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Label + Unit (Top aligned)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTheme.theme.textTheme.labelSmall,
              ),
              Text(
                unit,
                style: AppTheme.theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          // Body: The Big Number
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTheme.theme.textTheme.displayLarge?.copyWith(
                color: valueColor ?? AppTheme.primary,
              ),
            ),
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
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this);
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
    final icon = Icon(widget.icon, size: 32, color: AppTheme.tertiary);
    if (!widget.isSpinning) return icon;
    return RotationTransition(turns: _controller, child: icon);
  }
}