// lib/features/dashboard/presentation/widgets/weekly_trend_card.dart

import 'package:flutter/material.dart';
import '../../../../core/models/weekly_trend.dart';

class WeeklyTrendCard extends StatelessWidget {
  const WeeklyTrendCard({
    super.key,
    required this.trend,
  });

  final WeeklyTrend trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                color: Color(0xFF38BDF8),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Weekly Comparison',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'vs last 7 days',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 4 Comparison Chips (2x2)
          Row(
            children: [
              Expanded(
                child: _TrendPill(
                  label: 'Daily Steps',
                  value: trend.avgStepsThisWeek >= 1000
                      ? '${(trend.avgStepsThisWeek / 1000).toStringAsFixed(1)}k/d'
                      : '${trend.avgStepsThisWeek}/d',
                  deltaText: trend.stepDeltaPercent >= 0
                      ? '+${trend.stepDeltaPercent.toStringAsFixed(0)}%'
                      : '${trend.stepDeltaPercent.toStringAsFixed(0)}%',
                  isPositiveGood: trend.stepDeltaPercent >= 0,
                  icon: Icons.directions_walk_rounded,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrendPill(
                  label: 'Active Min',
                  value: '${trend.totalActiveMinThisWeek}m tot',
                  deltaText: trend.activeMinDelta >= 0
                      ? '+${trend.activeMinDelta}m'
                      : '${trend.activeMinDelta}m',
                  isPositiveGood: trend.activeMinDelta >= 0,
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF2DD4BF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TrendPill(
                  label: 'Resting HR',
                  value: trend.avgRestingHrThisWeek != null
                      ? '${trend.avgRestingHrThisWeek} bpm'
                      : '--',
                  deltaText: trend.restingHrDelta != 0
                      ? (trend.restingHrDelta > 0
                          ? '+${trend.restingHrDelta} bpm'
                          : '${trend.restingHrDelta} bpm')
                      : 'Stable',
                  // Lower resting HR is good!
                  isPositiveGood: trend.restingHrDelta <= 0,
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFF43F5E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrendPill(
                  label: 'Sleep Avg',
                  value: trend.avgSleepHoursThisWeek > 0
                      ? '${trend.avgSleepHoursThisWeek.toStringAsFixed(1)}h/nt'
                      : '--',
                  deltaText: trend.sleepMinutesDelta != 0
                      ? (trend.sleepMinutesDelta > 0
                          ? '+${trend.sleepMinutesDelta}m'
                          : '${trend.sleepMinutesDelta}m')
                      : 'Consistent',
                  isPositiveGood: trend.sleepMinutesDelta >= 0,
                  icon: Icons.bedtime_rounded,
                  color: const Color(0xFF818CF8),
                ),
              ),
            ],
          ),
          if (trend.coachingInsights.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFBBF24), // Gold spark
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      trend.coachingInsights.first,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({
    required this.label,
    required this.value,
    required this.deltaText,
    required this.isPositiveGood,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String deltaText;
  final bool isPositiveGood;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final deltaColor = isPositiveGood
        ? const Color(0xFF10B981) // Green
        : const Color(0xFFEF4444); // Red

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  deltaText,
                  style: TextStyle(
                    color: deltaColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
