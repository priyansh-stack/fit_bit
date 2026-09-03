import 'package:flutter/material.dart';
import '../../../../core/models/sleep_record.dart';
import '../../../../core/utils/date_utils.dart';

class SleepStageHypnogram extends StatelessWidget {
  final SleepRecord session;

  const SleepStageHypnogram({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final deep = session.deepMinutes ?? 0;
    final rem = session.remMinutes ?? 0;
    final light = session.lightMinutes ?? 0;
    final awake = session.awakeMinutes ?? 0;
    final total = deep + rem + light + awake;

    // Has stage data
    final hasStages = total > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF43BCCD).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Color(0xFF43BCCD),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Sleep Stages & Quality',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (session.sleepScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C896).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Score: ${session.sleepScore}',
                    style: const TextStyle(
                      color: Color(0xFF00C896),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (hasStages) ...[
            // Stacked Bar Hypnogram
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 20,
                child: Row(
                  children: [
                    if (deep > 0)
                      Expanded(
                        flex: deep,
                        child: Container(
                          color: const Color(0xFF7B2CBF),
                          alignment: Alignment.center,
                        ),
                      ),
                    if (rem > 0)
                      Expanded(
                        flex: rem,
                        child: Container(
                          color: const Color(0xFF43BCCD),
                          alignment: Alignment.center,
                        ),
                      ),
                    if (light > 0)
                      Expanded(
                        flex: light,
                        child: Container(
                          color: const Color(0xFF4361EE),
                          alignment: Alignment.center,
                        ),
                      ),
                    if (awake > 0)
                      Expanded(
                        flex: awake,
                        child: Container(
                          color: const Color(0xFFFF758F),
                          alignment: Alignment.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Legend and Breakdown
            Row(
              children: [
                Expanded(
                  child: _StageItem(
                    label: 'Deep',
                    minutes: deep,
                    percent: (deep / total * 100).round(),
                    color: const Color(0xFF7B2CBF),
                  ),
                ),
                Expanded(
                  child: _StageItem(
                    label: 'REM',
                    minutes: rem,
                    percent: (rem / total * 100).round(),
                    color: const Color(0xFF43BCCD),
                  ),
                ),
                Expanded(
                  child: _StageItem(
                    label: 'Light',
                    minutes: light,
                    percent: (light / total * 100).round(),
                    color: const Color(0xFF4361EE),
                  ),
                ),
                Expanded(
                  child: _StageItem(
                    label: 'Awake',
                    minutes: awake,
                    percent: (awake / total * 100).round(),
                    color: const Color(0xFFFF758F),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Standard session breakdown when Fitbit records duration
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: Color(0xFF43BCCD), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Duration: ${HealthDateUtils.formatSleepMinutes(session.durationMinutes)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${HealthDateUtils.toDisplayTime(session.startTime)} – ${HealthDateUtils.toDisplayTime(session.endTime)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF43BCCD).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Restful',
                      style: TextStyle(
                        color: Color(0xFF43BCCD),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageItem extends StatelessWidget {
  final String label;
  final int minutes;
  final int percent;
  final Color color;

  const _StageItem({
    required this.label,
    required this.minutes,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          HealthDateUtils.formatSleepMinutes(minutes),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          '$percent%',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
