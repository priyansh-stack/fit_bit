// lib/features/dashboard/cubit/dashboard_cubit.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/models/user_goals.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/readiness_calculator.dart';
import '../../../core/utils/streak_calculator.dart';
import '../../../core/utils/weekly_comparison.dart';
import '../../../repositories/health_repository.dart';
import 'dashboard_state.dart';

export 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required HealthRepository healthRepository,
    UserGoals? initialGoals,
  })  : _healthRepository = healthRepository,
        _currentGoals = initialGoals ?? UserGoals.defaultGoals,
        super(const DashboardState()) {
    _subscribe();
  }

  final HealthRepository _healthRepository;
  UserGoals _currentGoals;
  StreamSubscription? _summariesSub;

  void updateGoals(UserGoals goals) {
    _currentGoals = goals;
    if (state.recentDays.isNotEmpty && state.today != null) {
      final readiness = ReadinessCalculator.calculate(
        today: state.today!,
        recentDays: state.recentDays,
        goals: _currentGoals,
      );
      final streak = StreakCalculator.calculate(
        days: state.recentDays,
        stepGoal: _currentGoals.stepGoal,
      );
      emit(state.copyWith(
        readinessScore: readiness,
        streakData: streak,
      ));
    }
  }

  void _subscribe() {
    _summariesSub?.cancel();
    // Watch 14 days of history to compute 14-day RHR baselines, streaks, and weekly deltas
    _summariesSub = _healthRepository.watchRecentSummaries(days: 14).listen(
      (list) {
        final today = _computeToday(list);
        final steps = _computeStepsChart(list);
        final calories = _computeCaloriesChart(list);
        final sleep = _computeSleepChart(list);
        final rhr = _computeRhrChart(list);

        final readiness = ReadinessCalculator.calculate(
          today: today,
          recentDays: list,
          goals: _currentGoals,
        );

        final streak = StreakCalculator.calculate(
          days: list,
          stepGoal: _currentGoals.stepGoal,
        );

        final weeklyTrend = WeeklyComparison.compare(days: list);

        emit(state.copyWith(
          recentDays: list,
          today: today,
          stepsChart: steps,
          caloriesChart: calories,
          sleepChart: sleep,
          rhrChart: rhr,
          readinessScore: readiness,
          streakData: streak,
          weeklyTrend: weeklyTrend,
          isLoading: false,
          errorMessage: () => null,
        ));
      },
      onError: (e) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: () => e.toString(),
        ));
      },
    );
  }

  void refresh() {
    emit(state.copyWith(isLoading: true));
    _subscribe();
  }

  HealthDaily _computeToday(List<HealthDaily> list) {
    final today = HealthDateUtils.todayIso();
    final found = list.where((d) => d.date == today).firstOrNull;
    if (found != null) return found;
    if (list.isNotEmpty) return list.last;
    return HealthDaily(
      date: today,
      steps: 0,
      calories: 0,
      distanceMeters: 0,
      activeMinutes: 0,
      source: 'google_health',
      updatedAt: DateTime.now(),
    );
  }

  Map<String, int> _computeStepsChart(List<HealthDaily> list) {
    final dates = HealthDateUtils.lastNDates(7);
    return {
      for (final date in dates)
        _shortLabel(date): list
                .where((d) => d.date == date)
                .map((d) => d.steps ?? 0)
                .firstOrNull ??
            0,
    };
  }

  Map<String, int> _computeCaloriesChart(List<HealthDaily> list) {
    final dates = HealthDateUtils.lastNDates(7);
    return {
      for (final date in dates)
        _shortLabel(date): list
                .where((d) => d.date == date)
                .map((d) => d.calories ?? 0)
                .firstOrNull ??
            0,
    };
  }

  Map<String, double> _computeSleepChart(List<HealthDaily> list) {
    final dates = HealthDateUtils.lastNDates(7);
    return {
      for (final date in dates)
        _shortLabel(date): (list
                    .where((d) => d.date == date)
                    .map((d) => d.sleepMinutes ?? 0)
                    .firstOrNull ??
                0) /
            60.0,
    };
  }

  Map<String, int> _computeRhrChart(List<HealthDaily> list) {
    final dates = HealthDateUtils.lastNDates(7);
    return {
      for (final date in dates)
        _shortLabel(date): list
                .where((d) => d.date == date)
                .map((d) => d.restingHeartRate ?? 0)
                .firstOrNull ??
            0,
    };
  }

  String _shortLabel(String isoDate) {
    final dt = HealthDateUtils.fromIsoDate(isoDate);
    return HealthDateUtils.toDayLabel(dt);
  }

  @override
  Future<void> close() {
    _summariesSub?.cancel();
    return super.close();
  }
}
