// lib/core/models/weekly_trend.dart

class WeeklyTrend {
  const WeeklyTrend({
    required this.stepDeltaPercent,
    required this.avgStepsThisWeek,
    required this.avgStepsLastWeek,
    required this.activeMinDelta,
    required this.totalActiveMinThisWeek,
    required this.restingHrDelta,
    required this.avgRestingHrThisWeek,
    required this.sleepMinutesDelta,
    required this.avgSleepHoursThisWeek,
    required this.coachingInsights,
  });

  final double stepDeltaPercent; // e.g. +14.5 (%)
  final int avgStepsThisWeek;
  final int avgStepsLastWeek;
  final int activeMinDelta; // in minutes (+30 or -15)
  final int totalActiveMinThisWeek;
  final int restingHrDelta; // in bpm (-2 or +1)
  final int? avgRestingHrThisWeek;
  final int sleepMinutesDelta; // per night (+25 or -10)
  final double avgSleepHoursThisWeek;
  final List<String> coachingInsights;

  static const defaultTrend = WeeklyTrend(
    stepDeltaPercent: 0.0,
    avgStepsThisWeek: 0,
    avgStepsLastWeek: 0,
    activeMinDelta: 0,
    totalActiveMinThisWeek: 0,
    restingHrDelta: 0,
    avgRestingHrThisWeek: null,
    sleepMinutesDelta: 0,
    avgSleepHoursThisWeek: 0.0,
    coachingInsights: [
      'Keep wearing your tracker consistently to unlock deeper weekly trends and comparisons.'
    ],
  );
}
