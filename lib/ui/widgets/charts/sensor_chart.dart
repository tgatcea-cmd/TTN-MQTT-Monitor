import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    List<Map<String, dynamic>> sortedData = List.from(historicalData);
    if (!isAscending) {
      sortedData = sortedData.reversed.toList();
    }
    if (sortedData.length > 50) sortedData = sortedData.sublist(sortedData.length - 50);

    if (sortedData.isEmpty) {
      return const Center(
        child: Text("Insufficient Data for Visualization", 
          style: TextStyle(color: Colors.grey, fontSize: 12)
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
    
    // Add padding to chart Y-axis
    minY -= 2;
    maxY += 2;
    double interval = (maxY - minY) / 4;
    if (interval == 0) interval = 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[100],
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w500
                    ),
                  );
                },
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sortedData.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: tempSpots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: const Color(0xFF18181B), // Dark line
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false), // Clean look, no fill
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final dateStr = sortedData[spot.x.toInt()]['timestamp'];
                  final date = DateTime.parse(dateStr).toLocal();
                  final time = DateFormat('HH:mm').format(date);
                  return LineTooltipItem(
                    '$time\n${spot.y.toStringAsFixed(1)}°C',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12
                    ),
                  );
                }).toList();
              },
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ),
    );
  }
}