// lib/core/models/streak_data.dart

class DayStreakItem {
  const DayStreakItem({
    required this.date,
    required this.dayLabel, // e.g. "M", "T", "W"
    required this.isCompleted,
    required this.steps,
    required this.isToday,
  });

  final String date;
  final String dayLabel;
  final bool isCompleted;
  final int steps;
  final bool isToday;
}

class StreakData {
  const StreakData({
    required this.currentStreak,
    required this.bestStreak,
    required this.daysHitThisWeek,
    required this.weeklyItems,
    required this.isGoalHitToday,
  });

  final int currentStreak;
  final int bestStreak;
  final int daysHitThisWeek; // e.g. 5 of 7
  final List<DayStreakItem> weeklyItems;
  final bool isGoalHitToday;

  static const defaultStreak = StreakData(
    currentStreak: 0,
    bestStreak: 0,
    daysHitThisWeek: 0,
    weeklyItems: [],
    isGoalHitToday: false,
  );
}
