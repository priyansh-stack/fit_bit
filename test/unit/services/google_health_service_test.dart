// test/unit/services/google_health_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/services/google_health_service.dart';
import 'package:fitbit_health_dashboard/core/constants/api_constants.dart';

void main() {
  group('GoogleHealthAPIURL Factory Tests', () {
    test('builds daily rollup URL correctly', () {
      final date = DateTime(2026, 8, 31);
      final url = GoogleHealthStepsAPIURL.day(date: date);

      expect(url.isRollUp, isTrue);
      expect(
        url.url,
        '${GoogleHealthApiConstants.baseUrl}/dataTypes/steps${GoogleHealthApiConstants.dailyRollUpSuffix}',
      );
      expect(url.requestBody?['range'], isNotNull);
      final start = url.requestBody?['range']['start']['date'];
      expect(start['year'], 2026);
      expect(start['month'], 8);
      expect(start['day'], 31);
    });

    test('builds date range rollup URL correctly', () {
      final start = DateTime(2026, 8, 1);
      final end = DateTime(2026, 8, 31);
      final url = GoogleHealthStepsAPIURL.dateRange(
        startDate: start,
        endDate: end,
      );

      expect(url.isRollUp, isTrue);
      expect(
        url.url,
        '${GoogleHealthApiConstants.baseUrl}/dataTypes/steps${GoogleHealthApiConstants.dailyRollUpSuffix}',
      );
      expect(url.requestBody?['range'], isNotNull);
      final startDate = url.requestBody?['range']['start']['date'];
      final endDate = url.requestBody?['range']['end']['date'];
      expect(startDate['day'], 1);
      expect(endDate['day'], 31);
    });

    test('builds resting heart rate datapoints URL correctly', () {
      final start = DateTime(2026, 8, 1);
      final end = DateTime(2026, 8, 31);
      final url = GoogleHealthRestingHeartRateAPIURL.dateRange(
        startDate: start,
        endDate: end,
      );

      expect(url.isRollUp, isFalse);
      expect(url.url, contains('/dataTypes/heart-rate/dataPoints'));
    });
  });

  group('GoogleHealthCredentials Model Tests', () {
    test('detects expiring token within 60 seconds', () {
      final validCreds = GoogleHealthCredentials(
        accessToken: 'valid_token',
        tokenExpiry: DateTime.now().add(const Duration(minutes: 10)),
      );
      expect(validCreds.isExpiredOrExpiring, isFalse);

      final expiringCreds = GoogleHealthCredentials(
        accessToken: 'expiring_token',
        tokenExpiry: DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(expiringCreds.isExpiredOrExpiring, isTrue);
    });

    test('serializes and deserializes correctly', () {
      final now = DateTime.now();
      final creds = GoogleHealthCredentials(
        accessToken: 'test_access',
        refreshToken: 'test_refresh',
        tokenExpiry: now,
        grantedScopes: ['scope1', 'scope2'],
        userId: 'user_123',
      );

      final json = creds.toJson();
      expect(json['accessToken'], 'test_access');
      expect(json['refreshToken'], 'test_refresh');
      expect(json['grantedScopes'], ['scope1', 'scope2']);
      expect(json['userId'], 'user_123');

      final fromJson = GoogleHealthCredentials.fromJson(json);
      expect(fromJson.accessToken, 'test_access');
      expect(fromJson.refreshToken, 'test_refresh');
      expect(fromJson.userId, 'user_123');
    });
  });

  group('GoogleHealthActiveMinutesData Model Tests', () {
    test('correctly parses activeMinutesRollupByActivityLevel from Google Health API', () {
      final json = {
        'civilStartTime': {
          'date': {'year': 2026, 'month': 9, 'day': 1}
        },
        'activeMinutes': {
          'activeMinutesRollupByActivityLevel': [
            {'activityLevel': 'LIGHT', 'activeMinutesSum': '64'},
            {'activityLevel': 'MODERATE', 'activeMinutesSum': '12'},
            {'activityLevel': 'VIGOROUS', 'activeMinutesSum': '35'},
          ]
        }
      };

      final data = GoogleHealthActiveMinutesData.fromJson(json);
      expect(data.date, '2026-09-01');
      expect(data.activeMinutesSum, 111); // 64 + 12 + 35
    });

    test('correctly parses direct activeMinutesSum scalar', () {
      final json = {
        'civilStartTime': {
          'date': {'year': 2026, 'month': 9, 'day': 2}
        },
        'activeMinutes': {
          'activeMinutesSum': 45,
        }
      };

      final data = GoogleHealthActiveMinutesData.fromJson(json);
      expect(data.date, '2026-09-02');
      expect(data.activeMinutesSum, 45);
    });
  });
}
