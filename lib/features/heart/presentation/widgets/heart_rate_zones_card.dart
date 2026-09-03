// lib/features/heart/presentation/widgets/heart_rate_zones_card.dart

import 'package:flutter/material.dart';
import '../../../../core/models/heart_rate_zones.dart';

class HeartRateZonesCard extends StatelessWidget {
  const HeartRateZonesCard({
    super.key,
    required this.zones,
  });

  final HeartRateZones zones;

  @override
  Widget build(BuildContext context) {
    final total = zones.outOfZoneMinutes +
        zones.fatBurnMinutes +
        zones.cardioMinutes +
        zones.peakMinutes;

    final fbFlex = total > 0 ? (zones.fatBurnMinutes * 1000 ~/ total).clamp(1, 1000) : 1;
    final cdFlex = total > 0 ? (zones.cardioMinutes * 1000 ~/ total).clamp(1, 1000) : 1;
    final pkFlex = total > 0 ? (zones.peakMinutes * 1000 ~/ total).clamp(1, 1000) : 1;
    final ozFlex = total > 0 ? (zones.outOfZoneMinutes * 1000 ~/ total).clamp(1, 1000) : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Heart Rate Zones',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Time in training intensities',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${zones.activeZoneMinutes} AZM',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stacked progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: total > 0
                  ? Row(
                      children: [
                        if (zones.outOfZoneMinutes > 0)
                          Expanded(
                            flex: ozFlex,
                            child: Container(color: const Color(0xFF475569)),
                          ),
                        if (zones.fatBurnMinutes > 0)
                          Expanded(
                            flex: fbFlex,
                            child: Container(color: const Color(0xFFF59E0B)),
                          ),
                        if (zones.cardioMinutes > 0)
                          Expanded(
                            flex: cdFlex,
                            child: Container(color: const Color(0xFFF97316)),
                          ),
                        if (zones.peakMinutes > 0)
                          Expanded(
                            flex: pkFlex,
                            child: Container(color: const Color(0xFFEF4444)),
                          ),
                      ],
                    )
                  : Container(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // 4-zone tiles
          Row(
            children: [
              Expanded(
                child: _ZoneTile(
                  title: 'Out of Zone',
                  bpmRange: '< ${zones.fatBurnMin}',
                  minutes: zones.outOfZoneMinutes,
                  color: const Color(0xFF94A3B8),
                  multiplier: '',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ZoneTile(
                  title: 'Fat Burn',
                  bpmRange: '${zones.fatBurnMin}–${zones.cardioMin - 1}',
                  minutes: zones.fatBurnMinutes,
                  color: const Color(0xFFF59E0B),
                  multiplier: '1x',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ZoneTile(
                  title: 'Cardio',
                  bpmRange: '${zones.cardioMin}–${zones.peakMin - 1}',
                  minutes: zones.cardioMinutes,
                  color: const Color(0xFFF97316),
                  multiplier: '2x',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ZoneTile(
                  title: 'Peak',
                  bpmRange: '≥ ${zones.peakMin}',
                  minutes: zones.peakMinutes,
                  color: const Color(0xFFEF4444),
                  multiplier: '2x',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Educational footnote
          Text(
            'Active Zone Minutes (AZM) gives 1 min credit for Fat Burn and 2 min for Cardio & Peak. Target: ~22 AZM/day (150/week) per AHA guidelines.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({
    required this.title,
    required this.bpmRange,
    required this.minutes,
    required this.color,
    required this.multiplier,
  });

  final String title;
  final String bpmRange;
  final int minutes;
  final Color color;
  final String multiplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              if (multiplier.isNotEmpty)
                Text(
                  multiplier,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$bpmRange bpm',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${minutes}m',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
