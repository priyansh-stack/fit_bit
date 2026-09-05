// lib/features/dashboard/presentation/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/models/user_goals.dart';
import '../../../core/utils/date_utils.dart';
import '../../goals/cubit/goals_cubit.dart';
import '../../goals/cubit/goals_state.dart';
import '../../health_connection/cubit/health_connection_cubit.dart';
import '../../../core/models/health_insight.dart';
import '../../../core/utils/health_coach_engine.dart';
import '../cubit/dashboard_cubit.dart';
import 'widgets/daily_readiness_card.dart';
import 'widgets/smart_coach_banner.dart';
import 'widgets/streak_banner_card.dart';
import 'widgets/weekly_trend_card.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/metric_chart.dart';
import '../../../shared/widgets/error_view.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionState = context.watch<HealthConnectionCubit>().state;
    final dashboardState = context.watch<DashboardCubit>().state;
    final goalsState = context.watch<GoalsCubit>().state;
    final goals = goalsState is GoalsLoaded
        ? goalsState.goals
        : UserGoals.defaultGoals;

    final isConnected = connectionState.isConnected;
    final today = dashboardState.today;
    final stepsChart = dashboardState.stepsChart;

    final insights = (today != null && !dashboardState.isLoading)
        ? HealthCoachEngine.generateInsights(
            today: today,
            recentDays: dashboardState.recentDays,
            goals: goals,
            readiness: dashboardState.readinessScore,
          )
        : const <HealthInsight>[];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocListener<GoalsCubit, GoalsState>(
        listener: (context, state) {
          if (state is GoalsLoaded) {
            context.read<DashboardCubit>().updateGoals(state.goals);
          }
        },
        child: RefreshIndicator(
          onRefresh: () async {
            await context
                .read<HealthConnectionCubit>()
                .syncHealthData();
            if (context.mounted) {
              context.read<DashboardCubit>().refresh();
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                pinned: false,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                    ),
                    const Text(
                      'Your Health Today',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.sync_rounded, color: Colors.white70),
                    tooltip: 'Sync Health Data',
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Syncing health data...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      try {
                        await context
                            .read<HealthConnectionCubit>()
                            .syncHealthData();
                        if (context.mounted) {
                          context.read<DashboardCubit>().refresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sync complete!'),
                              backgroundColor: AppTheme.activeColor,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sync error: $e'),
                              backgroundColor: AppTheme.warningColor,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  if (!isConnected)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ElevatedButton.icon(
                        onPressed: () => context.go(AppRoute.connect),
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: const Text('Connect'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Offline / last-updated banner
                    if (today?.updatedAt != null)
                      _LastUpdatedBanner(updatedAt: today!.updatedAt!),

                    // Not connected banner
                    if (!isConnected && !connectionState.isLoading)
                      _NotConnectedBanner(
                          onConnect: () => context.go(AppRoute.connect)),

                    const SizedBox(height: 14),

                    // 1. Goal celebration banner if user hit or exceeded daily step goal
                    if (today != null &&
                        today.steps != null &&
                        today.steps! >= goals.stepGoal) ...[
                      _GoalCelebrationBanner(
                        steps: today.steps!,
                        goal: goals.stepGoal,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 2. Daily Readiness Score Card
                    if (dashboardState.readinessScore != null &&
                        !dashboardState.isLoading) ...[
                      DailyReadinessCard(
                          readiness: dashboardState.readinessScore!),
                      const SizedBox(height: 14),
                    ],

                    // 3. Streak & Habit Tracking Banner
                    if (dashboardState.streakData != null &&
                        !dashboardState.isLoading) ...[
                      StreakBannerCard(streak: dashboardState.streakData!),
                      const SizedBox(height: 16),
                    ],

                    // 4. Smart Health Coach Insights
                    if (insights.isNotEmpty && !dashboardState.isLoading) ...[
                      SmartCoachBanner(insights: insights),
                      const SizedBox(height: 16),
                    ],

                    // 4. Metric cards grid
                    if (dashboardState.isLoading)
                      _MetricGrid(today: null, isLoading: true, goals: goals)
                    else if (dashboardState.errorMessage != null)
                      ErrorView(
                        message:
                            'Could not load health data. Check your connection.',
                        onRetry: () => context.read<DashboardCubit>().refresh(),
                      )
                    else
                      _MetricGrid(
                        today: today,
                        isLoading: false,
                        goals: goals,
                        recentDays: dashboardState.recentDays,
                      ),

                    const SizedBox(height: 24),

                    // 5. Weekly Comparison & Coaching Card
                    if (dashboardState.weeklyTrend != null &&
                        !dashboardState.isLoading) ...[
                      WeeklyTrendCard(trend: dashboardState.weeklyTrend!),
                      const SizedBox(height: 24),
                    ],

                    // 6. Steps 7-day chart
                    const _SectionHeader(
                      title: 'Steps — Last 7 Days',
                      color: AppTheme.stepsColor,
                    ),
                    const SizedBox(height: 12),
                    if (dashboardState.isLoading)
                      const SizedBox(height: 160)
                    else if (stepsChart.values.any((v) => v > 0))
                      StepsBarChart(
                        data: stepsChart,
                        color: AppTheme.stepsColor,
                        goal: goals.stepGoal,
                      )
                    else
                      const EmptyDataView(
                        message:
                            'No step data yet. Connect your Fitbit to start tracking.',
                        icon: Icons.directions_walk_rounded,
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.today,
    required this.isLoading,
    required this.goals,
    this.recentDays = const [],
  });

  final HealthDaily? today;
  final bool isLoading;
  final UserGoals goals;
  final List<HealthDaily> recentDays;

  @override
  Widget build(BuildContext context) {
    final stepPercent = today?.steps != null
        ? (today!.steps! / goals.stepGoal * 100).round()
        : null;

    final calPercent = today?.calories != null && today!.calories! > 0
        ? (today!.calories! / goals.calorieGoal * 100).round()
        : null;

    final activePercent = today?.activeMinutes != null
        ? (today!.activeMinutes! / goals.activeMinutesGoal * 100).round()
        : null;

    // Look at today's sleep, or fallback to the most recent night with sleep
    final effectiveSleepDay =
        (today?.sleepMinutes != null && today!.sleepMinutes! > 0)
            ? today
            : recentDays.reversed
                .where((d) => d.sleepMinutes != null && d.sleepMinutes! > 0)
                .firstOrNull;

    final isPastNight =
        (today?.sleepMinutes == null || today!.sleepMinutes == 0) &&
            effectiveSleepDay != null;

    final sleepMinutes = effectiveSleepDay?.sleepMinutes;
    final sleepHours = sleepMinutes != null && sleepMinutes > 0
        ? (sleepMinutes / 60)
        : null;

    final score = effectiveSleepDay?.sleepScore;
    final qualityStr =
        score != null ? '$score · ${_getSleepQuality(score)}' : null;

    final sleepSubtitle = isPastNight
        ? 'Last night · ${qualityStr ?? (sleepHours != null ? "${sleepHours.toStringAsFixed(1)}h" : "")}'
        : (qualityStr ??
            (sleepHours != null
                ? '${sleepHours.toStringAsFixed(1)}h / ${goals.sleepHoursGoal.toStringAsFixed(1)}h goal'
                : null));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        HealthCard(
          title: 'Steps',
          value: today?.steps != null ? _fmt(today!.steps!) : '--',
          subtitle: stepPercent != null
              ? '$stepPercent% of ${_fmt(goals.stepGoal)} goal'
              : null,
          icon: Icons.directions_walk_rounded,
          color: AppTheme.stepsColor,
          isLoading: isLoading,
          isEmpty: today?.steps == null && !isLoading,
          onTap: () => context.go(AppRoute.activity),
        ),
        HealthCard(
          title: 'Calories',
          value: today?.calories != null && today!.calories! > 0
              ? '${_fmtCalories(today!.calories!)} kcal'
              : '--',
          subtitle: calPercent != null
              ? (today?.activeCalories != null && today!.activeCalories! > 0
                  ? '$calPercent% (${today!.activeCalories} active)'
                  : '$calPercent% of ${_fmtCalories(goals.calorieGoal)} kcal')
              : null,
          icon: Icons.local_fire_department_rounded,
          color: AppTheme.caloriesColor,
          isLoading: isLoading,
          isEmpty:
              (today?.calories == null || today!.calories == 0) && !isLoading,
          onTap: () => context.go(AppRoute.activity),
        ),
        HealthCard(
          title: 'Distance',
          value: (today != null && today!.distanceKm > 0)
              ? '${today!.distanceKm.toStringAsFixed(2)} km'
              : '--',
          icon: Icons.straighten_rounded,
          color: AppTheme.distanceColor,
          isLoading: isLoading,
          isEmpty: (today == null || today!.distanceKm == 0) && !isLoading,
          onTap: () => context.go(AppRoute.activity),
        ),
        HealthCard(
          title: 'Active Min',
          value: today?.activeMinutes != null
              ? '${today!.activeMinutes} min'
              : '--',
          subtitle: activePercent != null
              ? '$activePercent% of ${goals.activeMinutesGoal}m'
              : null,
          icon: Icons.bolt_rounded,
          color: AppTheme.activeColor,
          isLoading: isLoading,
          isEmpty: today?.activeMinutes == null && !isLoading,
          onTap: () => context.go(AppRoute.activity),
        ),
        HealthCard(
          title: 'Heart Rate',
          value: today?.restingHeartRate != null && today!.restingHeartRate! > 0
              ? '${today!.restingHeartRate} bpm'
              : '--',
          subtitle: 'Resting',
          icon: Icons.favorite_rounded,
          color: AppTheme.heartColor,
          isLoading: isLoading,
          isEmpty: (today?.restingHeartRate == null ||
                  today!.restingHeartRate == 0) &&
              !isLoading,
          onTap: () => context.go(AppRoute.heart),
        ),
        HealthCard(
          title: 'Sleep',
          value: HealthDateUtils.formatSleepMinutes(sleepMinutes),
          subtitle: sleepSubtitle,
          icon: Icons.bedtime_rounded,
          color: AppTheme.sleepColor,
          isLoading: isLoading,
          isEmpty: (sleepMinutes == null || sleepMinutes == 0) && !isLoading,
          onTap: () => context.go(AppRoute.sleep),
        ),
      ],
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
  }

  static String _fmtCalories(int n) {
    if (n >= 100000) {
      return '${(n / 1000).toStringAsFixed(0)}k';
    }
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  static String _getSleepQuality(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Poor';
  }
}

class _GoalCelebrationBanner extends StatelessWidget {
  final int steps;
  final int goal;

  const _GoalCelebrationBanner({required this.steps, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF00C896)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Step Goal Reached!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Amazing job! You crushed your target with $steps / $goal steps today.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _LastUpdatedBanner extends StatelessWidget {
  const _LastUpdatedBanner({required this.updatedAt});
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded,
              size: 14, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Text(
            'Last updated: ${HealthDateUtils.relativeTime(updatedAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _NotConnectedBanner extends StatelessWidget {
  const _NotConnectedBanner({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_off_rounded,
              color: Color(0xFF6366F1), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fitbit not connected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Connect to sync your health data',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onConnect,
            child: const Text('Connect',
                style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }
}
