// lib/core/utils/streak_calculator.dart

import 'package:intl/intl.dart';
import '../models/health_daily.dart';
import '../models/streak_data.dart';
import 'date_utils.dart';

class StreakCalculator {
  const StreakCalculator._();

  static StreakData calculate({
    required List<HealthDaily> days, // Chronological: oldest to newest
    required int stepGoal,
  }) {
    if (days.isEmpty || stepGoal <= 0) {
      return StreakData.defaultStreak;
    }

    final todayIso = HealthDateUtils.todayIso();
    final todayRecord = days.where((d) => d.date == todayIso).firstOrNull;
    final isGoalHitToday = (todayRecord?.steps ?? 0) >= stepGoal;

    // 1. Weekly items for last 7 dates
    final last7Dates = HealthDateUtils.lastNDates(7);
    final daysMap = {for (final d in days) d.date: d};

    final weeklyItems = <DayStreakItem>[];
    int daysHitThisWeek = 0;

    for (final dateStr in last7Dates) {
      final record = daysMap[dateStr];
      final steps = record?.steps ?? 0;
      final isCompleted = steps >= stepGoal;
      final isToday = (dateStr == todayIso);

      if (isCompleted) daysHitThisWeek++;

      final dt = HealthDateUtils.fromIsoDate(dateStr);
      final dayLetter = DateFormat('E').format(dt).substring(0, 1);

      weeklyItems.add(DayStreakItem(
        date: dateStr,
        dayLabel: dayLetter,
        isCompleted: isCompleted,
        steps: steps,
        isToday: isToday,
      ));
    }

    // 2. Current Streak calculation
    // If today is completed, streak includes today and continues backward.
    // If today is NOT completed yet, streak starts from yesterday (since today is in progress).
    int currentStreak = 0;
    final reversedDays = days.reversed.toList();

    int startIndex = 0;
    if (reversedDays.isNotEmpty && reversedDays.first.date == todayIso) {
      if (isGoalHitToday) {
        startIndex = 0; // count today
      } else {
        startIndex = 1; // start from yesterday so morning doesn't break active streak
      }
    }

    for (int i = startIndex; i < reversedDays.length; i++) {
      final steps = reversedDays[i].steps ?? 0;
      if (steps >= stepGoal) {
        currentStreak++;
      } else {
        break;
      }
    }

    // 3. Best Streak across entire dataset
    int bestStreak = 0;
    int tempStreak = 0;
    for (final day in days) {
      final steps = day.steps ?? 0;
      if (steps >= stepGoal) {
        tempStreak++;
        if (tempStreak > bestStreak) {
          bestStreak = tempStreak;
        }
      } else {
        tempStreak = 0;
      }
    }
    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    return StreakData(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      daysHitThisWeek: daysHitThisWeek,
      weeklyItems: weeklyItems,
      isGoalHitToday: isGoalHitToday,
    );
  }
}
