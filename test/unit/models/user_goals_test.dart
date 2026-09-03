import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/core/models/user_goals.dart';

void main() {
  group('UserGoals', () {
    test('default goals have expected baseline values', () {
      const goals = UserGoals.defaultGoals;
      expect(goals.stepGoal, 10000);
      expect(goals.calorieGoal, 2000);
      expect(goals.sleepHoursGoal, 8.0);
      expect(goals.activeMinutesGoal, 30);
    });

    test('toJson and fromJson serialize and deserialize accurately', () {
      const goals = UserGoals(
        stepGoal: 12500,
        calorieGoal: 2400,
        sleepHoursGoal: 7.5,
        activeMinutesGoal: 45,
      );

      final json = goals.toJson();
      final restored = UserGoals.fromJson(json);

      expect(restored.stepGoal, 12500);
      expect(restored.calorieGoal, 2400);
      expect(restored.sleepHoursGoal, 7.5);
      expect(restored.activeMinutesGoal, 45);
      expect(restored, equals(goals));
    });

    test('copyWith modifies only targeted properties', () {
      const original = UserGoals.defaultGoals;
      final updated = original.copyWith(stepGoal: 15000);

      expect(updated.stepGoal, 15000);
      expect(updated.calorieGoal, 2000);
      expect(updated.sleepHoursGoal, 8.0);
      expect(updated.activeMinutesGoal, 30);
    });
  });
}
