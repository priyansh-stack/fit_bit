import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fitbit_health_dashboard/services/google_fitness_service.dart';
import 'package:fitbit_health_dashboard/services/google_health_service.dart';

void main() {
  group('GoogleFitnessService Tests', () {
    test(
        'fetchDailyAggregates parses steps, calories, distance, and heart rate correctly',
        () async {
      final mockResponse = {
        'bucket': [
          {
            'startTimeMillis': '1704067200000', // 2024-01-01 00:00:00 UTC
            'endTimeMillis': '1704153600000',
            'dataset': [
              {
                'point': [
                  {
                    'dataTypeName': 'com.google.step_count.delta',
                    'value': [
                      {'intVal': 8420}
                    ]
                  }
                ]
              },
              {
                'point': [
                  {
                    'dataTypeName': 'com.google.calories.expended',
                    'value': [
                      {'fpVal': 2150.5}
                    ]
                  }
                ]
              },
              {
                'point': [
                  {
                    'dataTypeName': 'com.google.distance.delta',
                    'value': [
                      {'fpVal': 6400.0}
                    ]
                  }
                ]
              },
              {
                'point': [
                  {
                    'dataTypeName': 'com.google.active_minutes',
                    'value': [
                      {'intVal': 45}
                    ]
                  }
                ]
              },
              {
                'point': [
                  {
                    'dataTypeName': 'com.google.heart_rate.bpm',
                    'value': [
                      {'fpVal': 65.0}, // avg
                      {'fpVal': 120.0}, // max
                      {'fpVal': 52.0} // min
                    ]
                  }
                ]
              }
            ]
          }
        ]
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('dataset:aggregate')) {
          return http.Response(jsonEncode(mockResponse), 200);
        }
        return http.Response('Not found', 404);
      });

      final service = GoogleFitnessService(client: client);
      final credentials = GoogleHealthCredentials(
        accessToken: 'fake_access_token',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
      );

      final result = await service.fetchDailyAggregates(
        credentials: credentials,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 1),
      );

      expect(result.length, 1);
      final daily = result.first;
      expect(daily.steps, 8420);
      expect(daily.calories, 2151);
      expect(daily.distanceMeters, 6400.0);
      expect(daily.activeMinutes, 45);
      expect(daily.restingHeartRate, 65);
      expect(daily.source, 'google_fitness');
    });

    test('fetchSleepSessions parses sleep sessions correctly', () async {
      final mockSleepResponse = {
        'session': [
          {
            'startTimeMillis': '1704067200000',
            'endTimeMillis': '1704096000000',
            'activityType': 72,
            'name': 'Sleep Session',
          }
        ]
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('sessions')) {
          return http.Response(jsonEncode(mockSleepResponse), 200);
        }
        return http.Response('Not found', 404);
      });

      final service = GoogleFitnessService(client: client);
      final credentials = GoogleHealthCredentials(
        accessToken: 'fake_access_token',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
      );

      final sessions = await service.fetchSleepSessions(
        credentials: credentials,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 2),
      );

      expect(sessions.length, 1);
      expect(sessions.first.durationMinutes, 480);
      expect(sessions.first.source, 'google_fitness');
    });
  });
}
