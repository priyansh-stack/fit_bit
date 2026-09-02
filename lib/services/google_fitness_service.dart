// lib/services/google_fitness_service.dart
//
// Direct integration with the Google Fitness REST API (https://www.googleapis.com/fitness/v1).
// Queries real-time and historical aggregated datasets for steps, calories, distance,
// active minutes, heart rate, and sleep sessions for the authenticated Google Account.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/constants/oauth_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/models/health_daily.dart';
import '../core/models/sleep_record.dart';
import 'google_health_service.dart';

class GoogleFitnessService {
  GoogleFitnessService({
    http.Client? client,
    GoogleHealthConnector? connector,
  })  : _client = client ?? http.Client(),
        _connector = connector ?? GoogleHealthConnector();

  final http.Client _client;
  final GoogleHealthConnector _connector;

  static const String _fitnessBaseUrl =
      'https://www.googleapis.com/fitness/v1/users/me';

  /// Queries daily aggregate summaries for a given date range.
  Future<List<HealthDaily>> fetchDailyAggregates({
    required GoogleHealthCredentials credentials,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1. Refresh token if expiring
    final creds = await _connector.refreshTokenIfNeeded(
      credentials,
      clientId: OAuthConstants.clientId,
      clientSecret: OAuthConstants.clientSecret,
    );

    // Compute start and end milliseconds at local day boundaries
    final startOfDay =
        DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final endOfDay =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    final startTimeMillis = startOfDay.millisecondsSinceEpoch;
    final endTimeMillis = endOfDay.millisecondsSinceEpoch;

    final requestBody = {
      'aggregateBy': [
        {'dataTypeName': 'com.google.step_count.delta'},
        {'dataTypeName': 'com.google.calories.expended'},
        {'dataTypeName': 'com.google.distance.delta'},
        {'dataTypeName': 'com.google.active_minutes'},
        {'dataTypeName': 'com.google.heart_rate.bpm'},
      ],
      'bucketByTime': {
        'durationMillis': 86400000, // 24 hours per bucket
      },
      'startTimeMillis': startTimeMillis,
      'endTimeMillis': endTimeMillis,
    };

    final response = await _client
        .post(
          Uri.parse('$_fitnessBaseUrl/dataset:aggregate'),
          headers: {
            'Authorization': 'Bearer ${creds.accessToken}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw const TokenRevokedException(
        message: 'Google Fitness access token expired. Please reconnect.',
      );
    }
    if (response.statusCode == 403) {
      throw const ScopeMissingException(
        message:
            'Insufficient Google Fitness permissions. Please grant fitness scopes.',
      );
    }
    if (response.statusCode != 200) {
      debugPrint(
          '[GoogleFitnessService] Aggregate API error ${response.statusCode}: ${response.body}');
      throw SyncException(
        message:
            'Google Fitness API returned HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final buckets = data['bucket'] as List<dynamic>? ?? [];
    debugPrint(
        '[GoogleFitnessService] Received ${buckets.length} buckets from Google Fitness');
    for (final b in buckets) {
      final ds = b['dataset'] as List<dynamic>? ?? [];
      for (final d in ds) {
        final pts = d['point'] as List<dynamic>? ?? [];
        if (pts.isNotEmpty) {
          debugPrint('[GoogleFitnessService] Non-empty point: $pts');
        }
      }
    }

    final List<HealthDaily> dailyList = [];

    for (final bucket in buckets) {
      final startTimeStr = bucket['startTimeMillis'] as String?;
      if (startTimeStr == null) continue;
      final bucketStartMillis = int.tryParse(startTimeStr) ?? 0;
      if (bucketStartMillis == 0) continue;

      final date = DateTime.fromMillisecondsSinceEpoch(bucketStartMillis);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      int steps = 0;
      double calories = 0.0;
      double distanceMeters = 0.0;
      int activeMinutes = 0;
      int? restingHeartRate;

      final datasets = bucket['dataset'] as List<dynamic>? ?? [];
      for (final dataset in datasets) {
        final points = dataset['point'] as List<dynamic>? ?? [];
        for (final point in points) {
          final dataTypeName = point['dataTypeName'] as String? ?? '';
          final values = point['value'] as List<dynamic>? ?? [];
          if (values.isEmpty) continue;

          switch (dataTypeName) {
            case 'com.google.step_count.delta':
              steps += (values[0]['intVal'] as int? ?? 0);
              break;

            case 'com.google.calories.expended':
              calories += (values[0]['fpVal'] as num? ?? 0.0).toDouble();
              break;

            case 'com.google.distance.delta':
              distanceMeters += (values[0]['fpVal'] as num? ?? 0.0).toDouble();
              break;

            case 'com.google.active_minutes':
              activeMinutes += (values[0]['intVal'] as int? ?? 0);
              break;

            case 'com.google.heart_rate.bpm':
              // Values: [avg, max, min]
              if (values.isNotEmpty) {
                final avgBpm = (values[0]['fpVal'] as num?)?.round();
                if (avgBpm != null && avgBpm > 0) {
                  restingHeartRate = avgBpm;
                }
              }
              break;
          }
        }
      }

      dailyList.add(HealthDaily(
        date: dateStr,
        steps: steps,
        calories: calories > 0 ? calories.round() : null,
        distanceMeters: distanceMeters > 0 ? distanceMeters : null,
        activeMinutes: activeMinutes > 0 ? activeMinutes : null,
        restingHeartRate: restingHeartRate,
        source: 'google_fitness',
        updatedAt: DateTime.now(),
      ));
    }

    return dailyList;
  }

  /// Queries sleep sessions from Google Fitness API.
  Future<List<SleepRecord>> fetchSleepSessions({
    required GoogleHealthCredentials credentials,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final creds = await _connector.refreshTokenIfNeeded(
      credentials,
      clientId: OAuthConstants.clientId,
      clientSecret: OAuthConstants.clientSecret,
    );

    final startIso = startDate.toUtc().toIso8601String();
    final endIso = endDate.toUtc().toIso8601String();

    // activityType 72 corresponds to SLEEP in Google Fitness API
    final url = Uri.parse(
      '$_fitnessBaseUrl/sessions?startTime=$startIso&endTime=$endIso&activityType=72',
    );

    final response = await _client.get(
      url,
      headers: {
        'Authorization': 'Bearer ${creds.accessToken}',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      debugPrint(
          '[GoogleFitnessService] Sleep sessions query returned HTTP ${response.statusCode}');
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final sessions = data['session'] as List<dynamic>? ?? [];

    final List<SleepRecord> sleepRecords = [];

    for (final session in sessions) {
      final startMillis =
          int.tryParse(session['startTimeMillis']?.toString() ?? '') ?? 0;
      final endMillis =
          int.tryParse(session['endTimeMillis']?.toString() ?? '') ?? 0;
      if (startMillis == 0 || endMillis == 0) continue;

      final start = DateTime.fromMillisecondsSinceEpoch(startMillis);
      final end = DateTime.fromMillisecondsSinceEpoch(endMillis);
      final durationMin = end.difference(start).inMinutes;
      final dateStr = DateFormat('yyyy-MM-dd').format(start);

      sleepRecords.add(SleepRecord(
        date: dateStr,
        startTime: start,
        endTime: end,
        durationMinutes: durationMin,
        source: 'google_fitness',
        updatedAt: DateTime.now(),
      ));
    }

    return sleepRecords;
  }
}
