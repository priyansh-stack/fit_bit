// lib/core/models/sleep_record.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Sleep stage type enum.
enum SleepStage { awake, light, deep, rem, unknown }

SleepStage sleepStageFromString(String? s) {
  switch (s?.toLowerCase()) {
    case 'awake':
      return SleepStage.awake;
    case 'light':
      return SleepStage.light;
    case 'deep':
      return SleepStage.deep;
    case 'rem':
      return SleepStage.rem;
    default:
      return SleepStage.unknown;
  }
}

/// Sleep session stored in users/{uid}/sleep/{docId}.
class SleepRecord {
  const SleepRecord({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.awakeMinutes,
    this.lightMinutes,
    this.deepMinutes,
    this.remMinutes,
    this.sleepScore,
    this.stages,
    this.source,
    this.updatedAt,
  });

  final String date; // yyyy-MM-dd of the night
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final int? awakeMinutes;
  final int? lightMinutes;
  final int? deepMinutes;
  final int? remMinutes;
  final int? sleepScore;
  final List<SleepStageSegment>? stages;
  final String? source;
  final DateTime? updatedAt;

  static DateTime _parseDateTime(dynamic val, [String? fallbackDate]) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) {
      final parsed = DateTime.tryParse(val);
      if (parsed != null) return parsed;
    }
    if (fallbackDate != null && fallbackDate.isNotEmpty) {
      final dt = DateTime.tryParse(fallbackDate);
      if (dt != null) return dt;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory SleepRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SleepRecord.fromJson(data);
  }

  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    final stagesList = (json['stages'] as List<dynamic>?)
        ?.map((e) => SleepStageSegment.fromJson(e as Map<String, dynamic>))
        .toList();

    final dateStr = json['date']?.toString() ?? '';
    return SleepRecord(
      date: dateStr,
      startTime: _parseDateTime(json['startTime'], dateStr),
      endTime: _parseDateTime(json['endTime'], dateStr),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      awakeMinutes: (json['awakeMinutes'] as num?)?.toInt(),
      lightMinutes: (json['lightMinutes'] as num?)?.toInt(),
      deepMinutes: (json['deepMinutes'] as num?)?.toInt(),
      remMinutes: (json['remMinutes'] as num?)?.toInt(),
      sleepScore: (json['sleepScore'] as num?)?.toInt(),
      stages: stagesList,
      source: json['source'] as String?,
      updatedAt: json['updatedAt'] != null ? _parseDateTime(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': durationMinutes,
        if (awakeMinutes != null) 'awakeMinutes': awakeMinutes,
        if (lightMinutes != null) 'lightMinutes': lightMinutes,
        if (deepMinutes != null) 'deepMinutes': deepMinutes,
        if (remMinutes != null) 'remMinutes': remMinutes,
        if (sleepScore != null) 'sleepScore': sleepScore,
        if (stages != null) 'stages': stages!.map((s) => s.toJson()).toList(),
        if (source != null) 'source': source,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// A single stage segment within a sleep session.
class SleepStageSegment {
  const SleepStageSegment({
    required this.start,
    required this.end,
    required this.stage,
  });

  final DateTime start;
  final DateTime end;
  final SleepStage stage;

  factory SleepStageSegment.fromJson(Map<String, dynamic> json) {
    return SleepStageSegment(
      start: SleepRecord._parseDateTime(json['start']),
      end: SleepRecord._parseDateTime(json['end']),
      stage: sleepStageFromString(json['stage'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'stage': stage.name,
      };
}
