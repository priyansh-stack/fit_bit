// lib/core/utils/health_coach_engine.dart

import 'package:flutter/material.dart';
import '../models/health_daily.dart';
import '../models/health_insight.dart';
import '../models/readiness_score.dart';
import '../models/user_goals.dart';

/// Intelligent biometric engine that evaluates wearable metrics in real-time
/// to generate personalized, clinically-informed daily health insights.
class HealthCoachEngine {
  const HealthCoachEngine._();

  /// Evaluates today's health metrics and history to produce prioritized insights.
  static List<HealthInsight> generateInsights({
    required HealthDaily today,
    required List<HealthDaily> recentDays,
    required UserGoals goals,
    ReadinessScore? readiness,
  }) {
    final insights = <HealthInsight>[];

    // 1. Cardiovascular / Resting Heart Rate Check
    final rhrInsight = _evaluateRestingHeartRate(today, recentDays);
    if (rhrInsight != null) {
      insights.add(rhrInsight);
    }

    // 2. Sleep Debt & Consistency Analysis
    final sleepInsight = _evaluateSleepDebt(today, recentDays, goals);
    if (sleepInsight != null) {
      insights.add(sleepInsight);
    }

    // 3. Readiness Pacing Guidance
    if (readiness != null) {
      final readinessInsight = _evaluateReadinessPacing(readiness, today, goals);
      if (readinessInsight != null) {
        insights.add(readinessInsight);
      }
    }

    // 4. Goal Proximity & Streak Keeper
    final streakInsight = _evaluateGoalProximity(today, goals);
    if (streakInsight != null) {
      insights.add(streakInsight);
    }

    return insights;
  }

  // ---------------------------------------------------------------------------
  // 1. Resting Heart Rate Evaluation
  // ---------------------------------------------------------------------------
  static HealthInsight? _evaluateRestingHeartRate(
    HealthDaily today,
    List<HealthDaily> recentDays,
  ) {
    final todayRhr = today.restingHeartRate;
    if (todayRhr == null || todayRhr <= 0) return null;

    final historyWithRhr = recentDays
        .where((d) =>
            d.date != today.date &&
            d.restingHeartRate != null &&
            d.restingHeartRate! > 0)
        .toList();

    if (historyWithRhr.length < 2) return null;

    final baselineRhr = historyWithRhr
            .map((d) => d.restingHeartRate!)
            .reduce((a, b) => a + b) /
        historyWithRhr.length;

    final diff = (todayRhr - baselineRhr).round();

    if (diff >= 4) {
      final isSevere = diff >= 7;
      final severity =
          isSevere ? InsightSeverity.caution : InsightSeverity.warning;
      return HealthInsight(
        id: 'rhr_elevated',
        type: InsightType.elevatedRhr,
        severity: severity,
        title: 'Elevated Resting HR (+$diff bpm)',
        message:
            'Your resting heart rate ($todayRhr bpm) is elevated above your baseline (${baselineRhr.round()} bpm). '
            'This often signals physical fatigue, accumulated stress, dehydration, or an oncoming cold. '
            'Prioritize hydration and light recovery today.',
        metricTag: 'Cardiovascular',
        icon: Icons.favorite_rounded,
        accentColor: HealthInsight.resolveSeverityColor(severity),
        actionLabel: 'View Heart Trends',
      );
    } else if (diff <= -3) {
      return HealthInsight(
        id: 'rhr_optimal',
        type: InsightType.optimalRecovery,
        severity: InsightSeverity.positive,
        title: 'Efficient Heart Recovery (${diff.abs()} bpm lower)',
        message:
            'Your resting heart rate ($todayRhr bpm) is lower than your average (${baselineRhr.round()} bpm). '
            'Your cardiovascular system is rested, showing strong autonomic nervous system balance.',
        metricTag: 'Cardiovascular',
        icon: Icons.favorite_rounded,
        accentColor:
            HealthInsight.resolveSeverityColor(InsightSeverity.positive),
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. Sleep Debt Evaluation
  // ---------------------------------------------------------------------------
  static HealthInsight? _evaluateSleepDebt(
    HealthDaily today,
    List<HealthDaily> recentDays,
    UserGoals goals,
  ) {
    // Look back at the last up to 5 days
    final sleepDays = recentDays.reversed
        .where((d) => d.sleepMinutes != null && d.sleepMinutes! > 0)
        .take(5)
        .toList();

    if (sleepDays.isEmpty) return null;

    final targetMinutes = (goals.sleepHoursGoal * 60).round();
    int cumulativeDeficit = 0;

    for (final day in sleepDays) {
      final deficit = targetMinutes - day.sleepMinutes!;
      if (deficit > 0) {
        cumulativeDeficit += deficit;
      }
    }

    if (cumulativeDeficit >= 60) {
      final hours = cumulativeDeficit ~/ 60;
      final mins = cumulativeDeficit % 60;
      final formattedDeficit = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
      final severity = cumulativeDeficit >= 120
          ? InsightSeverity.warning
          : InsightSeverity.info;

      return HealthInsight(
        id: 'sleep_debt',
        type: InsightType.sleepDebt,
        severity: severity,
        title: 'Sleep Debt Detected ($formattedDeficit deficit)',
        message:
            'You have built up $formattedDeficit of sleep debt over recent nights compared to your ${goals.sleepHoursGoal.toStringAsFixed(1)}h target. '
            'Going to bed 30–45 minutes earlier tonight will accelerate physical recovery and morning readiness.',
        metricTag: 'Sleep Debt',
        icon: Icons.bedtime_rounded,
        accentColor: HealthInsight.resolveSeverityColor(severity),
        actionLabel: 'Sleep Insights',
      );
    } else if (sleepDays.length >= 3 &&
        sleepDays.every((d) => d.sleepMinutes! >= targetMinutes * 0.92)) {
      return HealthInsight(
        id: 'sleep_consistent',
        type: InsightType.optimalRecovery,
        severity: InsightSeverity.positive,
        title: 'Consistent Sleep Routine',
        message:
            'You are maintaining excellent sleep consistency near your ${goals.sleepHoursGoal.toStringAsFixed(1)}h target. '
            'Consistent circadian rhythm is the strongest predictor of long-term cardiovascular health.',
        metricTag: 'Sleep Quality',
        icon: Icons.bedtime_rounded,
        accentColor:
            HealthInsight.resolveSeverityColor(InsightSeverity.positive),
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 3. Readiness Pacing Evaluation
  // ---------------------------------------------------------------------------
  static HealthInsight? _evaluateReadinessPacing(
    ReadinessScore readiness,
    HealthDaily today,
    UserGoals goals,
  ) {
    if (readiness.score >= 85) {
      return HealthInsight(
        id: 'readiness_high',
        type: InsightType.readinessPacing,
        severity: InsightSeverity.positive,
        title: 'High Recovery Window (${readiness.score}/100)',
        message:
            'Your sleep and heart recovery are operating at peak efficiency. '
            'Today is an ideal day to push for high-intensity training, long endurance, or new personal fitness records.',
        metricTag: 'Readiness',
        icon: Icons.bolt_rounded,
        accentColor:
            HealthInsight.resolveSeverityColor(InsightSeverity.positive),
      );
    } else if (readiness.score < 50) {
      return HealthInsight(
        id: 'readiness_low',
        type: InsightType.readinessPacing,
        severity: InsightSeverity.warning,
        title: 'Recovery Recommended (${readiness.score}/100)',
        message:
            'Biometrics indicate physiological strain. To avoid overtraining and injury, '
            'substitute intense workouts with gentle walking, mobility, or restorative rest today.',
        metricTag: 'Recovery',
        icon: Icons.spa_rounded,
        accentColor:
            HealthInsight.resolveSeverityColor(InsightSeverity.warning),
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 4. Goal Proximity & Streak Keeper
  // ---------------------------------------------------------------------------
  static HealthInsight? _evaluateGoalProximity(
    HealthDaily today,
    UserGoals goals,
  ) {
    final steps = today.steps ?? 0;
    if (steps >= goals.stepGoal) {
      return HealthInsight(
        id: 'goal_met',
        type: InsightType.streakKeeper,
        severity: InsightSeverity.positive,
        title: 'Daily Step Goal Reached!',
        message:
            'You hit your target of ${goals.stepGoal} steps ($steps completed). '
            'Your daily activity streak is secured for today!',
        metricTag: 'Habit Streak',
        icon: Icons.emoji_events_rounded,
        accentColor:
            HealthInsight.resolveSeverityColor(InsightSeverity.positive),
      );
    }

    final remaining = goals.stepGoal - steps;
    if (remaining > 0 && remaining <= 2500 && steps >= (goals.stepGoal * 0.6)) {
      return HealthInsight(
        id: 'streak_guard',
        type: InsightType.streakKeeper,
        severity: InsightSeverity.info,
        title: 'Goal in Reach ($remaining steps left)',
        message:
            'You are only $remaining steps away from your daily goal! '
            'A brisk 15–20 minute walk will keep your active habit streak unbroken.',
        metricTag: 'Streak Keeper',
        icon: Icons.local_fire_department_rounded,
        accentColor: HealthInsight.resolveSeverityColor(InsightSeverity.info),
      );
    }

    return null;
  }
}
