// lib/features/heart/presentation/heart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/models/heart_rate_record.dart';
import '../../../core/models/heart_rate_zones.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/metric_chart.dart';
import '../../../shared/widgets/error_view.dart';
import '../../health_connection/cubit/health_connection_cubit.dart';
import '../cubit/heart_cubit.dart';
import 'widgets/heart_rate_zones_card.dart';

class HeartScreen extends StatelessWidget {
  const HeartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heart & Cardiovascular')),
      body: RefreshIndicator(
        onRefresh: () async {
          await context
              .read<HealthConnectionCubit>()
              .syncHealthData();
          if (context.mounted) {
            context.read<HeartCubit>().refresh();
          }
        },
        child: BlocBuilder<HeartCubit, HeartState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.errorMessage != null) {
              return ErrorView(
                message: 'Failed to load heart rate data.',
                onRetry: () => context.read<HeartCubit>().refresh(),
              );
            }
            return _HeartContent(days: state.daily, recentHR: state.recentHR);
          },
        ),
      ),
    );
  }
}

class _HeartContent extends StatelessWidget {
  const _HeartContent({required this.days, required this.recentHR});
  final List<HealthDaily> days;
  final List<HeartRateRecord> recentHR;

  @override
  Widget build(BuildContext context) {
    // Resting HR line chart data
    final labels = HealthDateUtils.lastNDates(14);
    final restingHrData = <String, double>{
      for (final d in labels)
        HealthDateUtils.toMonthDay(HealthDateUtils.fromIsoDate(d)): days
                .where((e) =>
                    e.date == d &&
                    e.restingHeartRate != null &&
                    e.restingHeartRate! > 0)
                .map((e) => e.restingHeartRate!.toDouble())
                .firstOrNull ??
            0.0,
    }..removeWhere((_, v) => v <= 0);

    final validRHR = days
        .where((d) => d.restingHeartRate != null && d.restingHeartRate! > 0)
        .toList();
    final avgRHR = validRHR.isNotEmpty
        ? validRHR.map((d) => d.restingHeartRate!).reduce((a, b) => a + b) ~/
            validRHR.length
        : null;

    final latestRHR = days.reversed
        .where((d) => d.restingHeartRate != null && d.restingHeartRate! > 0)
        .map((d) => d.restingHeartRate!)
        .firstOrNull;

    final latestHrv = days.reversed
        .where((d) => d.avgHrv != null && d.avgHrv! > 0)
        .map((d) => d.avgHrv!)
        .firstOrNull;

    final latestSpo2 = days.reversed
        .where((d) => d.avgSpo2 != null && d.avgSpo2! > 0)
        .map((d) => d.avgSpo2!)
        .firstOrNull;

    final latestBreathing = days.reversed
        .where((d) => d.breathingRate != null && d.breathingRate! > 0)
        .map((d) => d.breathingRate!)
        .firstOrNull;

    final latestActiveMinutes = days.reversed
        .where((d) => d.activeMinutes != null && d.activeMinutes! > 0)
        .map((d) => d.activeMinutes!)
        .firstOrNull;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Hero RHR card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.heartColor.withValues(alpha: 0.3),
                AppTheme.heartColor.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: AppTheme.heartColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.favorite_rounded,
                  color: AppTheme.heartColor, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latestRHR != null ? '$latestRHR bpm' : '-- bpm',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Resting Heart Rate',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (avgRHR != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$avgRHR bpm',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '14-Day Avg',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Key Health Metrics (HRV, SpO2, Breathing Rate)
        Row(
          children: [
            _MetricCard(
              title: 'HRV (rMSSD)',
              value: latestHrv != null
                  ? '${latestHrv.toStringAsFixed(0)} ms'
                  : '--',
              icon: Icons.graphic_eq_rounded,
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(width: 10),
            _MetricCard(
              title: 'SpO2',
              value: latestSpo2 != null
                  ? '${latestSpo2.toStringAsFixed(1)}%'
                  : '--',
              icon: Icons.water_drop_rounded,
              color: const Color(0xFF06B6D4),
            ),
            const SizedBox(width: 10),
            _MetricCard(
              title: 'Breathing',
              value: latestBreathing != null
                  ? '${latestBreathing.toStringAsFixed(1)} rpm'
                  : '--',
              icon: Icons.air_rounded,
              color: const Color(0xFF10B981),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Heart Rate Training Zones & Active Zone Minutes
        HeartRateZonesCard(
          zones: HeartRateZones.fromBiometrics(
            records: recentHR,
            totalActiveMinutes: latestActiveMinutes,
          ),
        ),

        const SizedBox(height: 24),

        Text('Resting Heart Rate — Last 14 Days',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        if (restingHrData.isNotEmpty)
          LineMetricChart(
            data: restingHrData,
            color: AppTheme.heartColor,
          )
        else
          const EmptyDataView(
            message: 'No resting heart rate data yet.',
            icon: Icons.favorite_border_rounded,
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
