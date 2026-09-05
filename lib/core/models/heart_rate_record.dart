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
    DateTime ts;
    final rawTs = json['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is DateTime) {
      ts = rawTs;
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else if (rawTs is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      ts = DateTime.now();
    }

    DateTime? updated;
    final rawUpdated = json['updatedAt'];
    if (rawUpdated is Timestamp) {
      updated = rawUpdated.toDate();
    } else if (rawUpdated is DateTime) {
      updated = rawUpdated;
    } else if (rawUpdated is String) {
      updated = DateTime.tryParse(rawUpdated);
    }

    return HeartRateRecord(
      timestamp: ts,
      bpm: (json['bpm'] as num?)?.toInt() ?? 0,
      source: json['source'] as String?,
      updatedAt: updated,
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
    DateTime? updated;
    final rawUpdated = json['updatedAt'];
    if (rawUpdated is Timestamp) {
      updated = rawUpdated.toDate();
    } else if (rawUpdated is DateTime) {
      updated = rawUpdated;
    } else if (rawUpdated is String) {
      updated = DateTime.tryParse(rawUpdated);
    }

    return HRVRecord(
      date: json['date'] as String? ?? '',
      rmssd: (json['rmssd'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String?,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'rmssd': rmssd,
        if (source != null) 'source': source,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
