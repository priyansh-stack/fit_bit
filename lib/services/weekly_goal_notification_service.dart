import 'package:flutter/foundation.dart';
import '../core/models/user_goals.dart';
import '../core/services/fcm_service.dart';

class WeeklyGoalNotificationService {
  WeeklyGoalNotificationService._internal();
  static final WeeklyGoalNotificationService instance = WeeklyGoalNotificationService._internal();

  /// Evaluates weekly metrics against user targets and dispatches high-priority celebration/progress notifications.
  Future<void> evaluateWeeklyGoals({
    required List<int> dailyStepsLast7Days,
    required List<int> dailyActiveMinLast7Days,
    required List<double> dailySleepHoursLast7Days,
    required UserGoals goals,
  }) async {
    try {
      final totalSteps = dailyStepsLast7Days.fold<int>(0, (sum, val) => sum + val);
      final totalActiveMin = dailyActiveMinLast7Days.fold<int>(0, (sum, val) => sum + val);
      final avgSleep = dailySleepHoursLast7Days.isNotEmpty
          ? dailySleepHoursLast7Days.fold<double>(0.0, (sum, val) => sum + val) / dailySleepHoursLast7Days.length
          : 0.0;

      final weeklyStepTarget = goals.stepGoal * 7;
      final weeklyActiveTarget = goals.activeMinutesGoal * 7;

      // 1. Weekly Step Goal Celebration
      if (totalSteps >= weeklyStepTarget && weeklyStepTarget > 0) {
        await FitbitFcmService.instance.showWeeklyGoalCelebration(
          goalType: 'Steps',
          achieved: totalSteps,
          target: weeklyStepTarget,
          unit: 'steps',
        );
      }

      // 2. Weekly Active Zone Minutes Goal Celebration
      if (totalActiveMin >= weeklyActiveTarget && weeklyActiveTarget > 0) {
        await FitbitFcmService.instance.showWeeklyGoalCelebration(
          goalType: 'Active Zone Minutes',
          achieved: totalActiveMin,
          target: weeklyActiveTarget,
          unit: 'mins',
        );
      }

      // 3. Weekly Overall Digest
      await FitbitFcmService.instance.showWeeklyProgressSummary(
        stepsWeek: totalSteps,
        activeMinWeek: totalActiveMin,
        avgSleepHours: avgSleep,
      );
    } catch (e) {
      debugPrint('WeeklyGoalNotificationService evaluation error: $e');
    }
  }

  /// Sends an on-demand test celebration notification for weekly goal progress.
  Future<void> sendTestWeeklyGoalNotification() async {
    await FitbitFcmService.instance.showWeeklyGoalCelebration(
      goalType: 'Steps',
      achieved: 72450,
      target: 70000,
      unit: 'steps',
    );
  }

  /// Sends an on-demand test weekly health summary notification.
  Future<void> sendTestWeeklySummaryNotification() async {
    await FitbitFcmService.instance.showWeeklyProgressSummary(
      stepsWeek: 72450,
      activeMinWeek: 185,
      avgSleepHours: 7.8,
    );
  }
}
