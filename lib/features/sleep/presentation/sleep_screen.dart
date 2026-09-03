// lib/features/sleep/presentation/sleep_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/models/sleep_record.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/metric_chart.dart';
import '../../../shared/widgets/error_view.dart';
import '../../health_connection/cubit/health_connection_cubit.dart';
import '../cubit/sleep_cubit.dart';
import 'widgets/sleep_stage_hypnogram.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      body: RefreshIndicator(
        onRefresh: () async {
          await context
              .read<HealthConnectionCubit>()
              .syncHealthData(fullHistory: true);
          if (context.mounted) {
            context.read<SleepCubit>().refresh();
          }
        },
        child: BlocBuilder<SleepCubit, SleepState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.errorMessage != null) {
              return ErrorView(
                message: 'Failed to load sleep data.',
                onRetry: () => context.read<SleepCubit>().refresh(),
              );
            }
            return _SleepContent(sessions: state.sessions);
          },
        ),
      ),
    );
  }
}

class _SleepContent extends StatelessWidget {
  const _SleepContent({required this.sessions});

  final List<SleepRecord> sessions;

  @override
  Widget build(BuildContext context) {
    final labels = HealthDateUtils.lastNDates(14);
    final chartData = {
      for (final d in labels)
        HealthDateUtils.toMonthDay(HealthDateUtils.fromIsoDate(d)): sessions
                .where((s) => s.date == d)
                .map((s) => s.durationMinutes / 60.0)
                .firstOrNull ??
            0.0,
    };

    final avgSleep = sessions.isEmpty
        ? 0
        : sessions.map((s) => s.durationMinutes).reduce((a, b) => a + b) ~/
            sessions.length;

    final latestSession = sessions.isNotEmpty ? sessions.last : null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Average card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.sleepColor.withValues(alpha: 0.3),
                AppTheme.sleepColor.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: AppTheme.sleepColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bedtime_rounded,
                  color: AppTheme.sleepColor, size: 36),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    HealthDateUtils.formatSleepMinutes(avgSleep),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Average sleep (14 days)',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Sleep stage breakdown hypnogram for most recent night
        if (latestSession != null) ...[
          const SizedBox(height: 20),
          SleepStageHypnogram(session: latestSession),
        ],

        const SizedBox(height: 24),

        Text('Duration — Last 14 Nights',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        if (chartData.values.any((v) => v > 0))
          LineMetricChart(
            data: chartData.map((k, v) => MapEntry<String, double>(k, v > 0 ? v : 0.0)),
            color: AppTheme.sleepColor,
          )
        else
          const EmptyDataView(
            message: 'No sleep data yet.',
            icon: Icons.bedtime_rounded,
          ),

        const SizedBox(height: 28),

        Text('Sleep Sessions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        if (sessions.isEmpty)
          const EmptyDataView(
            message: 'No sleep sessions recorded.',
            icon: Icons.bedtime_rounded,
          )
        else
          ...sessions.reversed.map((s) => _SleepSessionTile(session: s)),
      ],
    );
  }
}

class _SleepSessionTile extends StatelessWidget {
  const _SleepSessionTile({required this.session});
  final SleepRecord session;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sleepColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                HealthDateUtils.toDisplayDate(session.startTime),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.sleepColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  HealthDateUtils.formatSleepMinutes(session.durationMinutes),
                  style: const TextStyle(
                      color: AppTheme.sleepColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stage breakdown bar
          if (session.deepMinutes != null) ...[
            _StageBar(session: session),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StageLegend(
                    'Awake', session.awakeMinutes, const Color(0xFFEF4444)),
                _StageLegend(
                    'Light', session.lightMinutes, const Color(0xFF60A5FA)),
                _StageLegend(
                    'Deep', session.deepMinutes, const Color(0xFF3B82F6)),
                _StageLegend(
                    'REM', session.remMinutes, const Color(0xFF8B5CF6)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.session});
  final SleepRecord session;

  @override
  Widget build(BuildContext context) {
    final total = session.durationMinutes.toDouble();
    if (total == 0) return const SizedBox();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          _barSegment(session.awakeMinutes, total, const Color(0xFFEF4444)),
          _barSegment(session.lightMinutes, total, const Color(0xFF60A5FA)),
          _barSegment(session.deepMinutes, total, const Color(0xFF3B82F6)),
          _barSegment(session.remMinutes, total, const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _barSegment(int? minutes, double total, Color color) {
    final flex = ((minutes ?? 0) / total * 100).round();
    if (flex == 0) return const SizedBox();
    return Expanded(
      flex: flex,
      child: Container(height: 8, color: color),
    );
  }
}

class _StageLegend extends StatelessWidget {
  const _StageLegend(this.label, this.minutes, this.color);
  final String label;
  final int? minutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          '$label ${HealthDateUtils.formatSleepMinutes(minutes ?? 0)}',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
