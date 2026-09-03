// test/unit/utils/health_coach_engine_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/core/models/health_daily.dart';
import 'package:fitbit_health_dashboard/core/models/health_insight.dart';
import 'package:fitbit_health_dashboard/core/models/readiness_score.dart';
import 'package:fitbit_health_dashboard/core/models/user_goals.dart';
import 'package:fitbit_health_dashboard/core/utils/health_coach_engine.dart';

void main() {
  group('HealthCoachEngine Tests', () {
    const goals = UserGoals(
      stepGoal: 10000,
      calorieGoal: 2000,
      sleepHoursGoal: 8.0,
      activeMinutesGoal: 30,
    );

    test('detects elevated resting heart rate anomaly and creates warning insight', () {
      final history = [
        const HealthDaily(date: '2026-09-01', restingHeartRate: 60),
        const HealthDaily(date: '2026-09-02', restingHeartRate: 61),
        const HealthDaily(date: '2026-09-03', restingHeartRate: 59),
      ];

      // Today RHR is 66 (elevated +6 bpm vs baseline 60)
      const today = HealthDaily(date: '2026-09-04', restingHeartRate: 66);

      final insights = HealthCoachEngine.generateInsights(
        today: today,
        recentDays: history,
        goals: goals,
      );

      final rhrInsight =
          insights.where((i) => i.type == InsightType.elevatedRhr).firstOrNull;

      expect(rhrInsight, isNotNull);
      expect(rhrInsight!.severity, InsightSeverity.warning);
      expect(rhrInsight.title, contains('+6 bpm'));
      expect(rhrInsight.message, contains('fatigue'));
    });

    test('detects optimal heart recovery when RHR is significantly lower than baseline', () {
      final history = [
        const HealthDaily(date: '2026-09-01', restingHeartRate: 65),
        const HealthDaily(date: '2026-09-02', restingHeartRate: 64),
        const HealthDaily(date: '2026-09-03', restingHeartRate: 66),
      ];

      // Today RHR is 60 (5 bpm lower than baseline 65)
      const today = HealthDaily(date: '2026-09-04', restingHeartRate: 60);

      final insights = HealthCoachEngine.generateInsights(
        today: today,
        recentDays: history,
        goals: goals,
      );

      final rhrInsight =
          insights.where((i) => i.type == InsightType.optimalRecovery).firstOrNull;

      expect(rhrInsight, isNotNull);
      expect(rhrInsight!.severity, InsightSeverity.positive);
      expect(rhrInsight.title, contains('5 bpm lower'));
    });

    test('calculates cumulative sleep debt and suggests recovery bedtime', () {
      // Goal is 8.0h (480 mins). Past 3 nights were 6.5h (390m), deficit = 90m per night * 3 = 270m
      final history = [
        const HealthDaily(date: '2026-09-01', sleepMinutes: 390),
        const HealthDaily(date: '2026-09-02', sleepMinutes: 390),
        const HealthDaily(date: '2026-09-03', sleepMinutes: 390),
      ];
      const today = HealthDaily(date: '2026-09-04');

      final insights = HealthCoachEngine.generateInsights(
        today: today,
        recentDays: history,
        goals: goals,
      );

      final sleepInsight =
          insights.where((i) => i.type == InsightType.sleepDebt).firstOrNull;

      expect(sleepInsight, isNotNull);
      expect(sleepInsight!.severity, InsightSeverity.warning);
      expect(sleepInsight.title, contains('Sleep Debt Detected'));
      expect(sleepInsight.title, contains('4h 30m')); // 270 mins
    });

    test('generates readiness pacing advice based on readiness score tier', () {
      const today = HealthDaily(date: '2026-09-04');

      const highReadiness = ReadinessScore(
        score: 92,
        tier: ReadinessTier.optimal,
        tierLabel: 'Optimal',
        tierColor: Color(0xFF10B981),
        message: 'Great',
        sleepComponent: 95,
        restingHrComponent: 90,
        strainComponent: 90,
      );

      final insights = HealthCoachEngine.generateInsights(
        today: today,
        recentDays: [],
        goals: goals,
        readiness: highReadiness,
      );

      final pacing = insights
          .where((i) => i.type == InsightType.readinessPacing)
          .firstOrNull;

      expect(pacing, isNotNull);
      expect(pacing!.severity, InsightSeverity.positive);
      expect(pacing.title, contains('High Recovery Window'));
    });

    test('generates streak keeper insight when daily step goal is in reach', () {
      // 8,500 steps when goal is 10,000 (1,500 steps remaining)
      const today = HealthDaily(date: '2026-09-04', steps: 8500);

      final insights = HealthCoachEngine.generateInsights(
        today: today,
        recentDays: [],
        goals: goals,
      );

      final streakInsight =
          insights.where((i) => i.type == InsightType.streakKeeper).firstOrNull;

      expect(streakInsight, isNotNull);
      expect(streakInsight!.title, contains('1500 steps left'));
    });
  });
}
