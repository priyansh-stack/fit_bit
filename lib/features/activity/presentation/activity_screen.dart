// lib/features/activity/presentation/activity_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/models/exercise_record.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/metric_chart.dart';
import '../../../shared/widgets/error_view.dart';
import '../../health_connection/cubit/health_connection_cubit.dart';
import '../cubit/activity_cubit.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: RefreshIndicator(
        onRefresh: () async {
          await context
              .read<HealthConnectionCubit>()
              .syncHealthData();
          if (context.mounted) {
            context.read<ActivityCubit>().refresh();
          }
        },
        child: BlocBuilder<ActivityCubit, ActivityState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.errorMessage != null) {
              return ErrorView(
                message: 'Failed to load activity data.',
                onRetry: () => context.read<ActivityCubit>().refresh(),
              );
            }
            return _ActivityContent(
              days: state.history,
              exercises: state.exercises,
            );
          },
        ),
      ),
    );
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({required this.days, required this.exercises});

  final List<HealthDaily> days;
  final List<ExerciseRecord> exercises;

  @override
  Widget build(BuildContext context) {
    final last14Labels = HealthDateUtils.lastNDates(14);
    final stepsData = {
      for (final d in last14Labels)
        HealthDateUtils.toMonthDay(HealthDateUtils.fromIsoDate(d)): days
                .where((e) => e.date == d)
                .map((e) => e.steps ?? 0)
                .firstOrNull ??
            0,
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Summary row
        Row(
          children: [
            _SummaryTile(
              label: 'Avg Steps',
              value: _avg(days.map((d) => d.steps ?? 0).toList()),
              icon: Icons.directions_walk_rounded,
              color: AppTheme.stepsColor,
            ),
            const SizedBox(width: 12),
            _SummaryTile(
              label: 'Avg Calories',
              value: _avg(days.map((d) => d.calories ?? 0).toList()),
              icon: Icons.local_fire_department_rounded,
              color: AppTheme.caloriesColor,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Steps chart
        Text('Steps — Last 14 Days',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (stepsData.values.any((v) => v > 0))
          StepsBarChart(
              data: stepsData, color: AppTheme.stepsColor, goal: 10000)
        else
          const EmptyDataView(
            message: 'No step data yet.',
            icon: Icons.directions_walk_rounded,
          ),

        const SizedBox(height: 28),

        // Daily table
        Text('Daily Summary', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...days.reversed.map((d) => _DayTile(day: d)),

        const SizedBox(height: 28),

        // Exercises
        Text('Recent Workouts', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (exercises.isEmpty)
          const EmptyDataView(
            message: 'No workouts recorded yet.',
            icon: Icons.fitness_center_rounded,
          )
        else
          Column(children: exercises.map((e) => _ExerciseTile(ex: e)).toList()),
      ],
    );
  }

  String _avg(List<int> values) {
    if (values.isEmpty) return '--';
    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return '--';
    final avg = nonZero.reduce((a, b) => a + b) ~/ nonZero.length;
    if (avg >= 1000) return '${(avg / 1000).toStringAsFixed(1)}k';
    return avg.toString();
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});
  final HealthDaily day;

  @override
  Widget build(BuildContext context) {
    final dt = HealthDateUtils.fromIsoDate(day.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(HealthDateUtils.toDayLabel(dt),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11)),
                Text(dt.day.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.08),
              margin: const EdgeInsets.symmetric(horizontal: 14)),
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (day.steps != null)
                  _MetricText('${_fmt(day.steps!)} steps', AppTheme.stepsColor),
                if (day.calories != null)
                  _MetricText(
                      '${_fmt(day.calories!)} cal', AppTheme.caloriesColor),
                if (day.activeMinutes != null)
                  _MetricText(
                      '${day.activeMinutes}m active', AppTheme.activeColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : n.toString();
}

class _MetricText extends StatelessWidget {
  const _MetricText(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(text,
      style:
          TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600));
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.ex});
  final ExerciseRecord ex;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.activeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_activityIcon(ex.activityType),
                color: AppTheme.activeColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_capitalize(ex.activityType),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Text(
                  '${ex.durationMinutes} min'
                  '${ex.calories != null ? ' · ${ex.calories} cal' : ''}'
                  '${ex.distanceMeters != null ? ' · ${(ex.distanceMeters! / 1000).toStringAsFixed(2)} km' : ''}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            HealthDateUtils.toMonthDay(ex.startTime),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'run':
      case 'running':
        return Icons.directions_run_rounded;
      case 'bike':
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'swim':
      case 'swimming':
        return Icons.pool_rounded;
      case 'walk':
      case 'walking':
        return Icons.directions_walk_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
