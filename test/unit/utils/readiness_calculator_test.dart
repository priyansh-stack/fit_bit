// test/unit/utils/readiness_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/core/models/health_daily.dart';
import 'package:fitbit_health_dashboard/core/models/readiness_score.dart';
import 'package:fitbit_health_dashboard/core/models/user_goals.dart';
import 'package:fitbit_health_dashboard/core/utils/readiness_calculator.dart';

void main() {
  group('ReadinessCalculator Tests', () {
    const goals = UserGoals(
      stepGoal: 10000,
      calorieGoal: 2000,
      sleepHoursGoal: 8.0,
      activeMinutesGoal: 30,
    );

    test('calculates optimal readiness score when sleep is full and RHR is low', () {
      const today = HealthDaily(
        date: '2026-09-03',
        steps: 10,
        sleepMinutes: 480, // 8.0 hrs (100% of goal)
        restingHeartRate: 60,
      );

      final recent = [
        const HealthDaily(date: '2026-09-01', steps: 8000, restingHeartRate: 64),
        const HealthDaily(date: '2026-09-02', steps: 8500, restingHeartRate: 63),
        today,
      ];

      final readiness = ReadinessCalculator.calculate(
        today: today,
        recentDays: recent,
        goals: goals,
      );

      expect(readiness.score, greaterThanOrEqualTo(80));
      expect(readiness.tier, ReadinessTier.optimal);
      expect(readiness.tierLabel, 'Optimal');
    });

    test('calculates lower readiness score when sleep deficit and elevated RHR', () {
      const today = HealthDaily(
        date: '2026-09-03',
        steps: 200,
        sleepMinutes: 240, // 4 hours (50% of goal)
        restingHeartRate: 75, // +12 bpm elevated
      );

      final recent = [
        const HealthDaily(date: '2026-09-01', steps: 18000, restingHeartRate: 63),
        const HealthDaily(date: '2026-09-02', steps: 19000, restingHeartRate: 63),
        today,
      ];

      final readiness = ReadinessCalculator.calculate(
        today: today,
        recentDays: recent,
        goals: goals,
      );

      expect(readiness.score, lessThan(60));
      expect(
        readiness.tier == ReadinessTier.moderate ||
            readiness.tier == ReadinessTier.rest,
        isTrue,
      );
    });

    test('gracefully handles missing metrics with reasonable default score', () {
      const today = HealthDaily(date: '2026-09-03', steps: 0);

      final readiness = ReadinessCalculator.calculate(
        today: today,
        recentDays: [today],
        goals: goals,
      );

      expect(readiness.score, greaterThan(60));
      expect(readiness.score, lessThanOrEqualTo(100));
    });
  });
}
