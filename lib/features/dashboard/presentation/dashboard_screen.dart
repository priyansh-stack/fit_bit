// lib/features/dashboard/presentation/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/utils/date_utils.dart';
import '../../health_connection/cubit/health_connection_cubit.dart';
import '../cubit/dashboard_cubit.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/metric_chart.dart';
import '../../../shared/widgets/error_view.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionState = context.watch<HealthConnectionCubit>().state;
    final dashboardState = context.watch<DashboardCubit>().state;

    final isConnected = connectionState.isConnected;
    final today = dashboardState.today;
    final stepsChart = dashboardState.stepsChart;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
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
                        .syncHealthData(fullHistory: true);
                    if (context.mounted) {
                      context.read<DashboardCubit>().refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Health data synchronized!'),
                          backgroundColor: AppTheme.successColor,
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

                const SizedBox(height: 16),

                // Metric cards grid
                if (dashboardState.isLoading)
                  const _MetricGrid(today: null, isLoading: true)
                else if (dashboardState.errorMessage != null)
                  ErrorView(
                    message:
                        'Could not load health data. Check your connection.',
                    onRetry: () => context.read<DashboardCubit>().refresh(),
                  )
                else
                  _MetricGrid(today: today, isLoading: false),

                const SizedBox(height: 28),

                // Steps 7-day chart
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
                    goal: 10000,
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
  const _MetricGrid({required this.today, required this.isLoading});

  final HealthDaily? today;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
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
          subtitle: today?.steps != null
              ? '${(today!.steps! / 10000 * 100).toStringAsFixed(0)}% of goal'
              : null,
          icon: Icons.directions_walk_rounded,
          color: AppTheme.stepsColor,
          isLoading: isLoading,
          isEmpty: today?.steps == null && !isLoading,
        ),
        HealthCard(
          title: 'Calories',
          value: today?.calories != null && today!.calories! > 0
              ? '${_fmt(today!.calories!)} kcal'
              : '--',
          icon: Icons.local_fire_department_rounded,
          color: AppTheme.caloriesColor,
          isLoading: isLoading,
          isEmpty:
              (today?.calories == null || today!.calories == 0) && !isLoading,
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
        ),
        HealthCard(
          title: 'Active Min',
          value: today?.activeMinutes != null && today!.activeMinutes! > 0
              ? '${today!.activeMinutes} min'
              : '--',
          icon: Icons.bolt_rounded,
          color: AppTheme.activeColor,
          isLoading: isLoading,
          isEmpty:
              (today?.activeMinutes == null || today!.activeMinutes == 0) &&
                  !isLoading,
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
        ),
        HealthCard(
          title: 'Sleep',
          value: HealthDateUtils.formatSleepMinutes(today?.sleepMinutes),
          subtitle:
              today?.sleepScore != null ? 'Score: ${today!.sleepScore}' : null,
          icon: Icons.bedtime_rounded,
          color: AppTheme.sleepColor,
          isLoading: isLoading,
          isEmpty: (today?.sleepMinutes == null || today!.sleepMinutes == 0) &&
              !isLoading,
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
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
