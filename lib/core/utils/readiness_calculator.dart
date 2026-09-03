// lib/core/utils/readiness_calculator.dart

import 'package:flutter/material.dart';
import '../models/health_daily.dart';
import '../models/readiness_score.dart';
import '../models/user_goals.dart';

class ReadinessCalculator {
  const ReadinessCalculator._();

  static ReadinessScore calculate({
    required HealthDaily today,
    required List<HealthDaily> recentDays,
    required UserGoals goals,
  }) {
    // 1. Sleep Component (40%)
    final sleepScore = _calculateSleepComponent(today, recentDays, goals);

    // 2. Resting Heart Rate Component (35%)
    final rhrScore = _calculateRhrComponent(today, recentDays);

    // 3. Activity Strain Balance Component (25%)
    final strainScore = _calculateStrainComponent(today, recentDays, goals);

    // Weighted composite
    final composite =
        (sleepScore * 0.40) + (rhrScore * 0.35) + (strainScore * 0.25);
    final finalScore = composite.round().clamp(15, 100);

    // Determine Tier & Message
    final (tier, label, color, message) = _resolveTier(finalScore, sleepScore, rhrScore);

    return ReadinessScore(
      score: finalScore,
      tier: tier,
      tierLabel: label,
      tierColor: color,
      message: message,
      sleepComponent: sleepScore,
      restingHrComponent: rhrScore,
      strainComponent: strainScore,
    );
  }

  static double _calculateSleepComponent(
    HealthDaily today,
    List<HealthDaily> recentDays,
    UserGoals goals,
  ) {
    // Look at today's sleep, or if not yet awake/synced, the most recent recorded night
    int? sleepMin = today.sleepMinutes;
    int? sleepScore = today.sleepScore;

    if (sleepMin == null || sleepMin == 0) {
      final lastWithSleep = recentDays.reversed
          .where((d) => d.sleepMinutes != null && d.sleepMinutes! > 0)
          .firstOrNull;
      if (lastWithSleep != null) {
        sleepMin = lastWithSleep.sleepMinutes;
        sleepScore = lastWithSleep.sleepScore;
      }
    }

    if (sleepMin == null || sleepMin == 0) {
      return 75.0; // Sensible default when no sleep data is yet tracked
    }

    final targetMin = (goals.sleepHoursGoal * 60).clamp(300.0, 720.0);
    final ratio = sleepMin / targetMin;

    double durationScore;
    if (ratio >= 1.0) {
      durationScore = 100.0;
    } else if (ratio >= 0.85) {
      durationScore = 85.0 + (ratio - 0.85) * 100;
    } else if (ratio >= 0.70) {
      durationScore = 70.0 + (ratio - 0.70) * 100;
    } else {
      durationScore = (ratio * 100).clamp(20.0, 70.0);
    }

    if (sleepScore != null && sleepScore > 0) {
      return (durationScore * 0.5 + sleepScore * 0.5).clamp(0.0, 100.0);
    }
    return durationScore.clamp(0.0, 100.0);
  }

  static double _calculateRhrComponent(
    HealthDaily today,
    List<HealthDaily> recentDays,
  ) {
    final todayRhr = today.restingHeartRate;

    // Calculate 14-day baseline excluding today
    final baselineDays = recentDays
        .where((d) =>
            d.date != today.date &&
            d.restingHeartRate != null &&
            d.restingHeartRate! > 0)
        .toList();

    if (todayRhr == null || todayRhr == 0 || baselineDays.isEmpty) {
      return 80.0; // Default when baseline or today's RHR is unavailable
    }

    final baselineAvg = baselineDays
            .map((d) => d.restingHeartRate!)
            .reduce((a, b) => a + b) /
        baselineDays.length;

    final delta = todayRhr - baselineAvg;

    if (delta <= -2.0) {
      return 100.0; // RHR is well below baseline (exceptional cardiovascular recovery)
    } else if (delta <= 1.0) {
      return 90.0; // RHR is stable at baseline
    } else if (delta <= 3.0) {
      return 75.0; // Slightly elevated
    } else if (delta <= 6.0) {
      return 60.0; // Moderately elevated
    } else {
      return (60.0 - (delta - 6.0) * 5.0).clamp(25.0, 60.0); // High elevation
    }
  }

  static double _calculateStrainComponent(
    HealthDaily today,
    List<HealthDaily> recentDays,
    UserGoals goals,
  ) {
    // Find yesterday's record
    final yesterday = recentDays.reversed
        .where((d) => d.date != today.date && (d.steps != null || d.activeMinutes != null))
        .firstOrNull;

    if (yesterday == null) return 85.0;

    final ySteps = yesterday.steps ?? 0;
    final stepRatio = ySteps / goals.stepGoal;

    if (stepRatio > 1.6) {
      return 65.0; // High exertion yesterday requires muscular rest
    } else if (stepRatio >= 0.8) {
      return 92.0; // Balanced optimal exertion
    } else if (stepRatio >= 0.4) {
      return 82.0;
    } else {
      return 75.0; // Sedentary day
    }
  }

  static (ReadinessTier, String, Color, String) _resolveTier(
    int score,
    double sleep,
    double rhr,
  ) {
    if (score >= 80) {
      return (
        ReadinessTier.optimal,
        'Optimal',
        const Color(0xFF10B981), // Emerald
        'Your body is well-recovered. Excellent day for high-intensity training or hitting new fitness milestones.',
      );
    } else if (score >= 65) {
      return (
        ReadinessTier.good,
        'Good Recovery',
        const Color(0xFF38BDF8), // Sky blue
        'You are in good shape for your regular workout routine and daily step targets.',
      );
    } else if (score >= 45) {
      return (
        ReadinessTier.moderate,
        'Moderate Fatigue',
        const Color(0xFFF59E0B), // Amber
        sleep < 65
            ? 'Sleep deficit detected. Consider an easier routine with light walking and early bedtime.'
            : 'Slightly elevated strain detected. Keep activity moderate and focus on hydration.',
      );
    } else {
      return (
        ReadinessTier.rest,
        'Rest & Recover',
        const Color(0xFFF43F5E), // Rose red
        'Your body needs recovery. Prioritize quality sleep, stretching, and gentle active rest today.',
      );
    }
  }
}
