// lib/core/models/exercise_record.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// An exercise/workout session stored in users/{uid}/exercise/{docId}.
class ExerciseRecord {
  const ExerciseRecord({
    required this.date,
    required this.startTime,
    required this.durationMinutes,
    required this.activityType,
    this.calories,
    this.distanceMeters,
    this.avgHeartRate,
    this.maxHeartRate,
    this.source,
    this.updatedAt,
  });

  final String date;
  final DateTime startTime;
  final int durationMinutes;
  final String activityType; // e.g. 'walk', 'run', 'bike'
  final int? calories;
  final double? distanceMeters;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final String? source;
  final DateTime? updatedAt;

  factory ExerciseRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExerciseRecord.fromJson(data);
  }

  factory ExerciseRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseRecord(
      date: json['date'] as String,
      startTime: (json['startTime'] as Timestamp).toDate(),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      activityType: json['activityType'] as String? ?? 'unknown',
      calories: (json['calories'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      avgHeartRate: (json['avgHeartRate'] as num?)?.toInt(),
      maxHeartRate: (json['maxHeartRate'] as num?)?.toInt(),
      source: json['source'] as String?,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'startTime': Timestamp.fromDate(startTime),
        'durationMinutes': durationMinutes,
        'activityType': activityType,
        if (calories != null) 'calories': calories,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (avgHeartRate != null) 'avgHeartRate': avgHeartRate,
        if (maxHeartRate != null) 'maxHeartRate': maxHeartRate,
        if (source != null) 'source': source,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
