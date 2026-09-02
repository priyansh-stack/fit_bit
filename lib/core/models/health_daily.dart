// lib/core/models/health_daily.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Normalized daily health summary stored in Firestore at
/// users/{uid}/healthDaily/{date}.
///
/// All numeric fields are nullable — not every wearable or day provides every metric.
class HealthDaily {
  const HealthDaily({
    required this.date,
    this.steps,
    this.distanceMeters,
    this.calories,
    this.activeCalories,
    this.activeMinutes,
    this.sedentaryMinutes,
    this.floors,
    this.restingHeartRate,
    this.sleepMinutes,
    this.sleepScore,
    this.avgHrv,
    this.avgSpo2,
    this.breathingRate,
    this.skinTempDeviation,
    this.weight,
    this.bodyFatPercent,
    this.source = 'google_health',
    this.updatedAt,
  });

  final String date; // yyyy-MM-dd (local date)
  final int? steps;
  final double? distanceMeters;
  final int? calories;
  final int? activeCalories;
  final int? activeMinutes;
  final int? sedentaryMinutes;
  final int? floors;
  final int? restingHeartRate;
  final int? sleepMinutes;
  final int? sleepScore;
  final double? avgHrv; // ms (rMSSD)
  final double? avgSpo2; // % (0 - 100)
  final double? breathingRate; // breaths per minute
  final double? skinTempDeviation; // °C deviation from baseline
  final double? weight; // kg
  final double? bodyFatPercent; // %
  final String? source; // 'google_health' | 'google_wearables'
  final DateTime? updatedAt;

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  factory HealthDaily.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    if (!data.containsKey('date') ||
        data['date'] == null ||
        (data['date'] as String).isEmpty) {
      data['date'] = doc.id;
    }
    return HealthDaily.fromJson(data);
  }

  factory HealthDaily.fromJson(Map<String, dynamic> json) {
    return HealthDaily(
      date: json['date'] as String? ?? '',
      steps: (json['steps'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      calories: (json['calories'] as num?)?.toInt(),
      activeCalories: (json['activeCalories'] as num?)?.toInt(),
      activeMinutes: (json['activeMinutes'] as num?)?.toInt(),
      sedentaryMinutes: (json['sedentaryMinutes'] as num?)?.toInt(),
      floors: (json['floors'] as num?)?.toInt(),
      restingHeartRate: (json['restingHeartRate'] as num?)?.toInt(),
      sleepMinutes: (json['sleepMinutes'] as num?)?.toInt(),
      sleepScore: (json['sleepScore'] as num?)?.toInt(),
      avgHrv: (json['avgHrv'] as num?)?.toDouble(),
      avgSpo2: (json['avgSpo2'] as num?)?.toDouble(),
      breathingRate: (json['breathingRate'] as num?)?.toDouble(),
      skinTempDeviation: (json['skinTempDeviation'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      source: json['source'] as String? ?? 'google_health',
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : json['updatedAt'] is DateTime
              ? json['updatedAt'] as DateTime
              : json['updatedAt'] is String
                  ? DateTime.tryParse(json['updatedAt'] as String)
                  : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      if (steps != null) 'steps': steps,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
      if (calories != null) 'calories': calories,
      if (activeCalories != null) 'activeCalories': activeCalories,
      if (activeMinutes != null) 'activeMinutes': activeMinutes,
      if (sedentaryMinutes != null) 'sedentaryMinutes': sedentaryMinutes,
      if (floors != null) 'floors': floors,
      if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
      if (sleepMinutes != null) 'sleepMinutes': sleepMinutes,
      if (sleepScore != null) 'sleepScore': sleepScore,
      if (avgHrv != null) 'avgHrv': avgHrv,
      if (avgSpo2 != null) 'avgSpo2': avgSpo2,
      if (breathingRate != null) 'breathingRate': breathingRate,
      if (skinTempDeviation != null) 'skinTempDeviation': skinTempDeviation,
      if (weight != null) 'weight': weight,
      if (bodyFatPercent != null) 'bodyFatPercent': bodyFatPercent,
      if (source != null) 'source': source,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

  double get distanceKm {
    if (distanceMeters != null && distanceMeters! >= 10) {
      return distanceMeters! / 1000;
    }
    if (steps != null && steps! > 0) {
      return (steps! * 0.762) / 1000;
    }
    return 0.0;
  }

  String get sleepFormatted {
    if (sleepMinutes == null || sleepMinutes == 0) return '--';
    final hours = sleepMinutes! ~/ 60;
    final mins = sleepMinutes! % 60;
    return '${hours}h ${mins}m';
  }

  HealthDaily copyWith({
    String? date,
    int? steps,
    double? distanceMeters,
    int? calories,
    int? activeCalories,
    int? activeMinutes,
    int? sedentaryMinutes,
    int? floors,
    int? restingHeartRate,
    int? sleepMinutes,
    int? sleepScore,
    double? avgHrv,
    double? avgSpo2,
    double? breathingRate,
    double? skinTempDeviation,
    double? weight,
    double? bodyFatPercent,
    String? source,
    DateTime? updatedAt,
  }) {
    return HealthDaily(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      calories: calories ?? this.calories,
      activeCalories: activeCalories ?? this.activeCalories,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      sedentaryMinutes: sedentaryMinutes ?? this.sedentaryMinutes,
      floors: floors ?? this.floors,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      sleepScore: sleepScore ?? this.sleepScore,
      avgHrv: avgHrv ?? this.avgHrv,
      avgSpo2: avgSpo2 ?? this.avgSpo2,
      breathingRate: breathingRate ?? this.breathingRate,
      skinTempDeviation: skinTempDeviation ?? this.skinTempDeviation,
      weight: weight ?? this.weight,
      bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
