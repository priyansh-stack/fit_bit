// test/unit/models/health_models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/core/models/health_daily.dart';
import 'package:fitbit_health_dashboard/core/models/heart_rate_record.dart';
import 'package:fitbit_health_dashboard/core/models/sleep_record.dart';
import 'package:fitbit_health_dashboard/core/models/health_connection.dart';

void main() {
  group('HealthDaily Model Tests', () {
    test('serializes and deserializes correctly', () {
      const daily = HealthDaily(
        date: '2026-08-31',
        steps: 8432,
        distanceMeters: 6120.0,
        calories: 2140,
        activeCalories: 620,
        activeMinutes: 48,
        sedentaryMinutes: 520,
        restingHeartRate: 61,
        sleepMinutes: 432,
        avgHrv: 45.5,
        avgSpo2: 98.2,
        breathingRate: 14.5,
        skinTempDeviation: -0.2,
        source: 'google_wearables',
      );

      final json = daily.toJson();
      expect(json['date'], '2026-08-31');
      expect(json['steps'], 8432);
      expect(json['distanceMeters'], 6120.0);
      expect(json['calories'], 2140);
      expect(json['activeMinutes'], 48);
      expect(json['sedentaryMinutes'], 520);
      expect(json['restingHeartRate'], 61);
      expect(json['sleepMinutes'], 432);
      expect(json['avgHrv'], 45.5);
      expect(json['avgSpo2'], 98.2);
      expect(json['breathingRate'], 14.5);
      expect(json['skinTempDeviation'], -0.2);
      expect(json['source'], 'google_wearables');

      expect(daily.distanceKm, 6.12);
      expect(daily.sleepFormatted, '7h 12m');

      final fromJson = HealthDaily.fromJson(json);
      expect(fromJson.date, '2026-08-31');
      expect(fromJson.steps, 8432);
      expect(fromJson.calories, 2140);
      expect(fromJson.restingHeartRate, 61);
    });

    test('handles nullable fields gracefully', () {
      const minimal = HealthDaily(date: '2026-08-31');
      expect(minimal.distanceKm, 0.0);
      expect(minimal.sleepFormatted, '--');

      final json = minimal.toJson();
      expect(json['date'], '2026-08-31');
      expect(json.containsKey('steps'), isFalse);
    });
  });

  group('HeartRateRecord Tests', () {
    test('creates and parses record', () {
      final now = DateTime(2026, 8, 31, 14, 30);
      final record = HeartRateRecord(
        timestamp: now,
        bpm: 72,
        source: 'google_wearables',
      );

      final json = record.toJson();
      expect(json['bpm'], 72);
      expect(json['source'], 'google_wearables');
    });
  });

  group('SleepRecord Tests', () {
    test('creates and parses sleep session with stages', () {
      final start = DateTime(2026, 8, 30, 23, 0);
      final end = DateTime(2026, 8, 31, 7, 0);
      final session = SleepRecord(
        date: '2026-08-31',
        startTime: start,
        endTime: end,
        durationMinutes: 480,
        awakeMinutes: 30,
        lightMinutes: 240,
        deepMinutes: 90,
        remMinutes: 120,
        sleepScore: 85,
        source: 'google_wearables',
      );

      final json = session.toJson();
      expect(json['date'], '2026-08-31');
      expect(json['durationMinutes'], 480);
      expect(json['deepMinutes'], 90);
      expect(json['sleepScore'], 85);
    });
  });

  group('HealthConnection Tests', () {
    test('status conversion and helpers', () {
      const conn = HealthConnection(
        id: 'google_health',
        status: ConnectionStatus.active,
        provider: 'google_health',
        displayName: 'John Doe',
      );

      expect(conn.isActive, isTrue);
      expect(conn.isDisconnected, isFalse);
    });
  });
}
