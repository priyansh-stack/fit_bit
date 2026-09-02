// lib/features/dashboard/cubit/dashboard_cubit.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/utils/date_utils.dart';
import '../../../repositories/health_repository.dart';
import 'dashboard_state.dart';

export 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required HealthRepository healthRepository,
  })  : _healthRepository = healthRepository,
        super(const DashboardState()) {
    _subscribe();
  }

  final HealthRepository _healthRepository;
  StreamSubscription? _summariesSub;

  void _subscribe() {
    _summariesSub?.cancel();
    _summariesSub = _healthRepository.watchRecentSummaries(days: 7).listen(
      (list) {
        final today = _computeToday(list);
        final steps = _computeStepsChart(list);
        final calories = _computeCaloriesChart(list);
        final sleep = _computeSleepChart(list);
        final rhr = _computeRhrChart(list);

        emit(state.copyWith(
          recentDays: list,
          today: today,
          stepsChart: steps,
          caloriesChart: calories,
          sleepChart: sleep,
          rhrChart: rhr,
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
