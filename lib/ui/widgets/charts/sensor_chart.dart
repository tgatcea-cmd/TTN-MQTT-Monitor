// ui/widgets/charts/sensor_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';

class SensorChart extends StatelessWidget {
  final List<Map<String, dynamic>> historicalData;
  final bool isAscending;

  const SensorChart({
    super.key,
    required this.historicalData,
    required this.isAscending,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Data Preparation
    List<Map<String, dynamic>> sortedData = List.from(historicalData);
    if (!isAscending) {
      sortedData = sortedData.reversed.toList();
    }
    // Limit to last 50 points for visual clarity
    if (sortedData.length > 50) sortedData = sortedData.sublist(sortedData.length - 50);

    if (sortedData.isEmpty) {
      return Center(
        child: Text(
          "Awaiting Data Signal", 
          style: AppTheme.theme.textTheme.bodyMedium?.copyWith(color: AppTheme.tertiary),
        )
      );
    }

    List<FlSpot> tempSpots = [];
    double minY = 100;
    double maxY = -100;

    for (int i = 0; i < sortedData.length; i++) {
      final reading = sortedData[i];
      if (reading['temperature'] != null) {
        final double t = (reading['temperature'] as num).toDouble();
        tempSpots.add(FlSpot(i.toDouble(), t));
        if (t < minY) minY = t;
        if (t > maxY) maxY = t;
      }
    }
    
    // Dynamic Y-axis padding for "breathing room"
    minY -= 2;
    maxY += 2;
    double interval = (maxY - minY) / 4;
    if (interval == 0) interval = 1;

    // 2. Chart Construction
    return Padding(
      // Extra right padding to prevent the last label from being clipped
      padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
      child: LineChart(
        LineChartData(
          // A. Clean Grid
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppTheme.border, // Zinc 200
              strokeWidth: 1,
              dashArray: [4, 4], // Dashed line for subtlety
            ),
          ),
          
          // B. Minimalist Titles
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value.toStringAsFixed(1),
                      style: AppTheme.theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.tertiary, // Zinc 400
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          
          // C. "Floating" Look (No Borders)
          borderData: FlBorderData(show: false),
          
          minX: 0,
          maxX: (sortedData.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          
          // D. The Data Line
          lineBarsData: [
            LineChartBarData(
              spots: tempSpots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppTheme.primary, // Dark Zinc line for maximum contrast
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.1),
                    AppTheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          
          // E. Premium Interactions
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: AppTheme.primary,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final dateStr = sortedData[spot.x.toInt()]['timestamp'];
                  final date = DateTime.parse(dateStr).toLocal();
                  final time = DateFormat('HH:mm').format(date);
                  return LineTooltipItem(
                    '$time\n${spot.y.toStringAsFixed(1)}°C',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  );
                }).toList();
              },
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tooltipMargin: 16,
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }
}