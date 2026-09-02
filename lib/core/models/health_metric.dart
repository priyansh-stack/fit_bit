// lib/core/models/health_metric.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// A point-in-time health metric (SpO2, respiratory rate, weight, body fat).
/// Stored in users/{uid}/healthMetrics/{docId}.
enum HealthMetricType {
  spo2,
  respiratoryRate,
  weight,
  bodyFat,
  temperature,
}

class HealthMetric {
  const HealthMetric({
    required this.date,
    required this.type,
    required this.value,
    required this.unit,
    this.source,
    this.updatedAt,
  });

  final String date;
  final HealthMetricType type;
  final double value;
  final String unit; // e.g. '%', 'breaths/min', 'kg', '%'
  final String? source;
  final DateTime? updatedAt;

  factory HealthMetric.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthMetric.fromJson(data);
  }

  factory HealthMetric.fromJson(Map<String, dynamic> json) {
    return HealthMetric(
      date: json['date'] as String,
      type: HealthMetricType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => HealthMetricType.spo2,
      ),
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String? ?? '',
      source: json['source'] as String?,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'type': type.name,
        'value': value,
        'unit': unit,
        if (source != null) 'source': source,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
