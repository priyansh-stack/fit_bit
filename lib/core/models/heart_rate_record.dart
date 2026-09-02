// lib/core/models/heart_rate_record.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// A single heart-rate data point stored in users/{uid}/heartRate/{docId}.
class HeartRateRecord {
  const HeartRateRecord({
    required this.timestamp,
    required this.bpm,
    this.source,
    this.updatedAt,
  });

  final DateTime timestamp;
  final int bpm;
  final String? source;
  final DateTime? updatedAt;

  factory HeartRateRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HeartRateRecord.fromJson(data);
  }

  factory HeartRateRecord.fromJson(Map<String, dynamic> json) {
    return HeartRateRecord(
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      bpm: (json['bpm'] as num).toInt(),
      source: json['source'] as String?,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': Timestamp.fromDate(timestamp),
        'bpm': bpm,
        if (source != null) 'source': source,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// Heart-rate variability record.
class HRVRecord {
  const HRVRecord({
    required this.date,
    required this.rmssd, // ms
    this.source,
    this.updatedAt,
  });

  final String date;
  final double rmssd;
  final String? source;
  final DateTime? updatedAt;

  factory HRVRecord.fromJson(Map<String, dynamic> json) {
    return HRVRecord(
      date: json['date'] as String,
      rmssd: (json['rmssd'] as num).toDouble(),
      source: json['source'] as String?,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'rmssd': rmssd,
        if (source != null) 'source': source,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
