// lib/core/models/readiness_score.dart

import 'package:flutter/material.dart';

enum ReadinessTier {
  optimal,
  good,
  moderate,
  rest,
}

class ReadinessScore {
  const ReadinessScore({
    required this.score,
    required this.tier,
    required this.tierLabel,
    required this.tierColor,
    required this.message,
    required this.sleepComponent,
    required this.restingHrComponent,
    required this.strainComponent,
  });

  final int score; // 0 - 100
  final ReadinessTier tier;
  final String tierLabel; // 'Optimal', 'Good Recovery', etc.
  final Color tierColor;
  final String message; // Daily coaching advice
  final double sleepComponent; // 0.0 - 100.0
  final double restingHrComponent; // 0.0 - 100.0
  final double strainComponent; // 0.0 - 100.0

  static const defaultScore = ReadinessScore(
    score: 80,
    tier: ReadinessTier.good,
    tierLabel: 'Good Recovery',
    tierColor: Color(0xFF38BDF8), // Sky blue
    message: 'Your body is recovered and ready for your regular daily activity.',
    sleepComponent: 80,
    restingHrComponent: 80,
    strainComponent: 80,
  );
}
