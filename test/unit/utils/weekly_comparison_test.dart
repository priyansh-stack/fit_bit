// test/unit/utils/weekly_comparison_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/core/models/health_daily.dart';
import 'package:fitbit_health_dashboard/core/utils/weekly_comparison.dart';

void main() {
  group('WeeklyComparison Tests', () {
    test('computes positive delta when activity increased this week', () {
      final days = [
        // Previous 7 days: 5,000 steps each
        for (int i = 1; i <= 7; i++)
          HealthDaily(
            date: '2026-08-0$i',
            steps: 5000,
            activeMinutes: 20,
            restingHeartRate: 70,
            sleepMinutes: 420,
          ),
        // Current 7 days: 10,000 steps each
        for (int i = 8; i <= 14; i++)
          HealthDaily(
            date: '2026-08-${i < 10 ? "0$i" : "$i"}',
            steps: 10000,
            activeMinutes: 45,
            restingHeartRate: 67, // -3 bpm
            sleepMinutes: 450, // +30 mins
          ),
      ];

      final trend = WeeklyComparison.compare(days: days);

      expect(trend.avgStepsThisWeek, 10000);
      expect(trend.avgStepsLastWeek, 5000);
      expect(trend.stepDeltaPercent, 100.0);
      expect(trend.activeMinDelta, greaterThan(0));
      expect(trend.restingHrDelta, -3);
      expect(trend.sleepMinutesDelta, 30);
      expect(trend.coachingInsights, isNotEmpty);
    });

    test('handles empty or sparse data safely', () {
      final trend = WeeklyComparison.compare(days: []);

      expect(trend.avgStepsThisWeek, 0);
      expect(trend.avgStepsLastWeek, 0);
      expect(trend.coachingInsights, isNotEmpty);
    });
  });
}
