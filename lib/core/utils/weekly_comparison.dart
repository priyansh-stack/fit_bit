// lib/core/utils/weekly_comparison.dart

import '../models/health_daily.dart';
import '../models/weekly_trend.dart';

class WeeklyComparison {
  const WeeklyComparison._();

  static WeeklyTrend compare({
    required List<HealthDaily> days, // Chronological: oldest to newest
  }) {
    if (days.isEmpty) return WeeklyTrend.defaultTrend;

    // Split into current 7 days and prior 7 days
    final thisWeekDays = days.length > 7 ? days.sublist(days.length - 7) : days;
    final lastWeekDays =
        days.length > 7 ? days.sublist(0, days.length - 7) : <HealthDaily>[];

    // 1. Steps
    final thisWeekSteps = thisWeekDays.map((d) => d.steps ?? 0).toList();
    final lastWeekSteps = lastWeekDays.map((d) => d.steps ?? 0).toList();

    final avgStepsThisWeek = thisWeekSteps.isNotEmpty
        ? (thisWeekSteps.reduce((a, b) => a + b) / thisWeekSteps.length).round()
        : 0;
    final avgStepsLastWeek = lastWeekSteps.isNotEmpty
        ? (lastWeekSteps.reduce((a, b) => a + b) / lastWeekSteps.length).round()
        : 0;

    double stepDeltaPercent = 0.0;
    if (avgStepsLastWeek > 0) {
      stepDeltaPercent =
          ((avgStepsThisWeek - avgStepsLastWeek) / avgStepsLastWeek) * 100;
    } else if (avgStepsThisWeek > 0) {
      stepDeltaPercent = 100.0;
    }

    // 2. Active Minutes
    final thisWeekActive = thisWeekDays.map((d) => d.activeMinutes ?? 0).toList();
    final lastWeekActive = lastWeekDays.map((d) => d.activeMinutes ?? 0).toList();

    final totalActiveThis =
        thisWeekActive.isNotEmpty ? thisWeekActive.reduce((a, b) => a + b) : 0;
    final totalActiveLast =
        lastWeekActive.isNotEmpty ? lastWeekActive.reduce((a, b) => a + b) : 0;
    final activeMinDelta = totalActiveThis - totalActiveLast;

    // 3. Resting Heart Rate
    final thisWeekRhr = thisWeekDays
        .where((d) => d.restingHeartRate != null && d.restingHeartRate! > 0)
        .map((d) => d.restingHeartRate!)
        .toList();
    final lastWeekRhr = lastWeekDays
        .where((d) => d.restingHeartRate != null && d.restingHeartRate! > 0)
        .map((d) => d.restingHeartRate!)
        .toList();

    final avgRhrThis = thisWeekRhr.isNotEmpty
        ? (thisWeekRhr.reduce((a, b) => a + b) / thisWeekRhr.length).round()
        : null;
    final avgRhrLast = lastWeekRhr.isNotEmpty
        ? (lastWeekRhr.reduce((a, b) => a + b) / lastWeekRhr.length).round()
        : null;

    int restingHrDelta = 0;
    if (avgRhrThis != null && avgRhrLast != null) {
      restingHrDelta = avgRhrThis - avgRhrLast;
    }

    // 4. Sleep Duration
    final thisWeekSleep = thisWeekDays
        .where((d) => d.sleepMinutes != null && d.sleepMinutes! > 0)
        .map((d) => d.sleepMinutes!)
        .toList();
    final lastWeekSleep = lastWeekDays
        .where((d) => d.sleepMinutes != null && d.sleepMinutes! > 0)
        .map((d) => d.sleepMinutes!)
        .toList();

    final avgSleepThis = thisWeekSleep.isNotEmpty
        ? (thisWeekSleep.reduce((a, b) => a + b) / thisWeekSleep.length).round()
        : 0;
    final avgSleepLast = lastWeekSleep.isNotEmpty
        ? (lastWeekSleep.reduce((a, b) => a + b) / lastWeekSleep.length).round()
        : 0;

    final sleepMinutesDelta = avgSleepThis - avgSleepLast;
    final avgSleepHoursThisWeek = avgSleepThis / 60.0;

    // 5. Coaching Insights
    final insights = <String>[];

    if (stepDeltaPercent >= 10.0) {
      insights.add(
          'Daily activity is up +${stepDeltaPercent.toStringAsFixed(0)}% vs last week! Superb endurance consistency.');
    } else if (stepDeltaPercent <= -15.0 && avgStepsLastWeek > 1000) {
      insights.add(
          'Steps are slightly lower than last week. A brisk 20-minute walk can help build momentum back.');
    }

    if (restingHrDelta < 0) {
      insights.add(
          'Resting HR decreased by ${restingHrDelta.abs()} bpm — a strong indicator of cardiovascular recovery.');
    } else if (restingHrDelta > 3) {
      insights.add(
          'Resting HR is elevated by +$restingHrDelta bpm vs last week. Prioritize sleep and active recovery.');
    }

    if (sleepMinutesDelta >= 25) {
      insights.add(
          'Sleeping +${sleepMinutesDelta}m more per night compared to last week.');
    } else if (sleepMinutesDelta <= -30 && avgSleepLast > 0) {
      insights.add(
          'Sleep averaged ${sleepMinutesDelta.abs()}m less per night. Try an earlier wind-down routine.');
    }

    if (insights.isEmpty) {
      insights.add(
          'Solid baseline consistency! Keep logging your daily activity and wearing your tracker to bed.');
    }

    return WeeklyTrend(
      stepDeltaPercent: stepDeltaPercent,
      avgStepsThisWeek: avgStepsThisWeek,
      avgStepsLastWeek: avgStepsLastWeek,
      activeMinDelta: activeMinDelta,
      totalActiveMinThisWeek: totalActiveThis,
      restingHrDelta: restingHrDelta,
      avgRestingHrThisWeek: avgRhrThis,
      sleepMinutesDelta: sleepMinutesDelta,
      avgSleepHoursThisWeek: avgSleepHoursThisWeek,
      coachingInsights: insights.take(2).toList(),
    );
  }
}
