// test/unit/utils/streak_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/core/models/health_daily.dart';
import 'package:fitbit_health_dashboard/core/utils/date_utils.dart';
import 'package:fitbit_health_dashboard/core/utils/streak_calculator.dart';

void main() {
  group('StreakCalculator Tests', () {
    const goal = 10000;
    final today = HealthDateUtils.todayIso();

    test('calculates active streak correctly', () {
      final days = [
        const HealthDaily(date: '2026-08-30', steps: 12000),
        const HealthDaily(date: '2026-08-31', steps: 11000),
        const HealthDaily(date: '2026-09-01', steps: 10500),
        const HealthDaily(date: '2026-09-02', steps: 14000),
        HealthDaily(date: today, steps: 10200),
      ];

      final streak = StreakCalculator.calculate(days: days, stepGoal: goal);

      expect(streak.currentStreak, 5);
      expect(streak.bestStreak, 5);
      expect(streak.isGoalHitToday, isTrue);
    });

    test('preserves streak in the morning before today goal is met', () {
      final days = [
        const HealthDaily(date: '2026-08-31', steps: 11000),
        const HealthDaily(date: '2026-09-01', steps: 10500),
        const HealthDaily(date: '2026-09-02', steps: 14000),
        HealthDaily(date: today, steps: 250), // Morning in progress
      ];

      final streak = StreakCalculator.calculate(days: days, stepGoal: goal);

      // Streak from yesterday should still be counted (3 days)
      expect(streak.currentStreak, 3);
      expect(streak.isGoalHitToday, isFalse);
    });

    test('detects broken streak when a previous day was missed', () {
      final days = [
        const HealthDaily(date: '2026-08-30', steps: 12000),
        const HealthDaily(date: '2026-08-31', steps: 4000), // Missed
        const HealthDaily(date: '2026-09-01', steps: 10500),
        const HealthDaily(date: '2026-09-02', steps: 14000),
        HealthDaily(date: today, steps: 11000),
      ];

      final streak = StreakCalculator.calculate(days: days, stepGoal: goal);

      expect(streak.currentStreak, 3); // 01, 02, today
      expect(streak.bestStreak, 3);
    });
  });
}
