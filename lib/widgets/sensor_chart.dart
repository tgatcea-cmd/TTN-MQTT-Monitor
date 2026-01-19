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

    if (sortedData.length > 50) {
      sortedData = sortedData.sublist(sortedData.length - 50);
    }

    if (sortedData.isEmpty) {
      return Container(
        height: 200,
        child: Center(child: Text("No data for chart")),
      );
    }

    List<FlSpot> tempSpots = [];
    double minY = 999;
    double maxY = -999;

    for (int i = 0; i < sortedData.length; i++) {
      final reading = sortedData[i];
      if (reading['temperature'] != null) {
        final double t = (reading['temperature'] as num).toDouble();
        tempSpots.add(FlSpot(i.toDouble(), t));
        if (t < minY) minY = t;
        if (t > maxY) maxY = t;
      }
    }

    minY = minY - 2;
    maxY = maxY + 2;

    double yInterval = (maxY - minY) / 5;
    if (yInterval <= 0) yInterval = 1.0;

    return Container(
      height: 250,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ºC Temperature Over Time",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        if (value == minY) return const SizedBox.shrink();

                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,

                          fitInside: SideTitleFitInsideData.fromTitleMeta(
                            meta,
                            enabled: true,
                            distanceFromEdge: 0,
                          ),
                          child: Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              height: 1.0,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: tempSpots.isNotEmpty ? tempSpots.last.x : 0,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: tempSpots,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.2),
                    ),
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
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
