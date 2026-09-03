// lib/features/dashboard/presentation/widgets/streak_banner_card.dart

import 'package:flutter/material.dart';
import '../../../../core/models/streak_data.dart';

class StreakBannerCard extends StatelessWidget {
  const StreakBannerCard({
    super.key,
    required this.streak,
  });

  final StreakData streak;

  @override
  Widget build(BuildContext context) {
    final hasStreak = streak.currentStreak > 0;
    const flameColor = Color(0xFFF97316); // Vibrant Orange

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasStreak
              ? flameColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Flame Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasStreak
                    ? [flameColor, const Color(0xFFEF4444)]
                    : [Colors.grey.shade700, Colors.grey.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: hasStreak
                  ? [
                      BoxShadow(
                        color: flameColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Streak Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hasStreak
                          ? '${streak.currentStreak}-Day Streak!'
                          : 'Daily Habit Tracker',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (streak.bestStreak > streak.currentStreak) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(Best: ${streak.bestStreak}d)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  streak.isGoalHitToday
                      ? 'Goal crushed today! Keep momentum.'
                      : '${streak.daysHitThisWeek}/7 days hit this week',
                  style: TextStyle(
                    color: streak.isGoalHitToday
                        ? const Color(0xFF10B981)
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: streak.isGoalHitToday
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // 7-Day Dot Timeline
          if (streak.weeklyItems.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: streak.weeklyItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.dayLabel,
                        style: TextStyle(
                          color: item.isToday
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 9,
                          fontWeight: item.isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.isCompleted
                              ? const Color(0xFF10B981)
                              : (item.isToday
                                  ? flameColor.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.1)),
                          border: item.isToday
                              ? Border.all(
                                  color: item.isCompleted
                                      ? const Color(0xFF10B981)
                                      : flameColor,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: item.isCompleted
                            ? const Icon(
                                Icons.check,
                                size: 9,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
