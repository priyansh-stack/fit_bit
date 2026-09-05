// lib/shared/widgets/metric_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A 7-day bar/line chart for health metrics.
class StepsBarChart extends StatelessWidget {
  const StepsBarChart({
    super.key,
    required this.data, // {label → value}
    required this.color,
    this.goal,
  });

  final Map<String, int> data;
  final Color color;
  final int? goal;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxValue = data.values.fold<int>(0, (m, v) => v > m ? v : m);
    final chartMax =
        goal != null && goal! > maxValue ? goal!.toDouble() : (maxValue * 1.2);

    final groups = data.entries.indexed.map(((int, MapEntry<String, int>) e) {
      final (i, entry) = e;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ],
      );
    }).toList();

    final labels = data.keys.toList();

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMax,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMax / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  _formatValue(rod.toY.toInt()),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  if (labels.length > 7 &&
                      i % 2 != 0 &&
                      i != labels.length - 1) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
                reservedSize: 22,
              ),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  String _formatValue(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toString();
  }
}

/// A line chart for heart rate or sleep over time.
class LineMetricChart extends StatelessWidget {
  const LineMetricChart({
    super.key,
    required this.data, // {label → value}
    required this.color,
  });

  final Map<String, double> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final labels = data.keys.toList();
    final values = data.values.toList();
    final spots = values.indexed
        .map(((int, double) e) => FlSpot(e.$1.toDouble(), e.$2))
        .toList();

    final rawMin = values.fold<double>(values.first, (m, v) => v < m ? v : m);
    final rawMax = values.fold<double>(values.first, (m, v) => v > m ? v : m);
    final padding = (rawMax - rawMin) > 10 ? (rawMax - rawMin) * 0.15 : 5.0;
    final minY = (rawMin - padding).clamp(0.0, double.infinity);
    final maxY = rawMax + padding;

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: labels.length > 1 ? (labels.length - 1).toDouble() : 1,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1.0,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) return const SizedBox();
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  if (labels.length > 7 &&
                      i % 2 != 0 &&
                      i != labels.length - 1) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
                reservedSize: 22,
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF1E293B),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.0)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
