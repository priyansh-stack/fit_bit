// lib/features/dashboard/cubit/dashboard_state.dart

import 'package:equatable/equatable.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/models/readiness_score.dart';
import '../../../core/models/streak_data.dart';
import '../../../core/models/weekly_trend.dart';

class DashboardState extends Equatable {
  const DashboardState({
    this.recentDays = const [],
    this.today,
    this.stepsChart = const {},
    this.caloriesChart = const {},
    this.sleepChart = const {},
    this.rhrChart = const {},
    this.readinessScore,
    this.streakData,
    this.weeklyTrend,
    this.isLoading = true,
    this.errorMessage,
  });

  final List<HealthDaily> recentDays;
  final HealthDaily? today;
  final Map<String, int> stepsChart;
  final Map<String, int> caloriesChart;
  final Map<String, double> sleepChart;
  final Map<String, int> rhrChart;
  final ReadinessScore? readinessScore;
  final StreakData? streakData;
  final WeeklyTrend? weeklyTrend;
  final bool isLoading;
  final String? errorMessage;

  DashboardState copyWith({
    List<HealthDaily>? recentDays,
    HealthDaily? today,
    Map<String, int>? stepsChart,
    Map<String, int>? caloriesChart,
    Map<String, double>? sleepChart,
    Map<String, int>? rhrChart,
    ReadinessScore? readinessScore,
    StreakData? streakData,
    WeeklyTrend? weeklyTrend,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return DashboardState(
      recentDays: recentDays ?? this.recentDays,
      today: today ?? this.today,
      stepsChart: stepsChart ?? this.stepsChart,
      caloriesChart: caloriesChart ?? this.caloriesChart,
      sleepChart: sleepChart ?? this.sleepChart,
      rhrChart: rhrChart ?? this.rhrChart,
      readinessScore: readinessScore ?? this.readinessScore,
      streakData: streakData ?? this.streakData,
      weeklyTrend: weeklyTrend ?? this.weeklyTrend,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        recentDays,
        today,
        stepsChart,
        caloriesChart,
        sleepChart,
        rhrChart,
        readinessScore,
        streakData,
        weeklyTrend,
        isLoading,
        errorMessage,
      ];
}
