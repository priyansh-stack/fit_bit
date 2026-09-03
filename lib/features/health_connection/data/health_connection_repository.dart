// lib/features/health_connection/data/health_connection_repository.dart
//
// On-device repository for all Google Health / Fitbit connection & data sync operations.
// All logic runs directly in Flutter — NO Cloud Functions required.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/oauth_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models/health_connection.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/models/sleep_record.dart';
import '../../../core/models/sync_status.dart';
import '../../../repositories/health_repository.dart';
import '../../../services/google_fitness_service.dart';
import '../../../services/google_health_service.dart';

class HealthConnectionRepository {
  HealthConnectionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    HealthRepository? healthRepository,
    GoogleHealthConnector? connector,
    GoogleFitnessService? fitnessService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _healthRepository = healthRepository ?? HealthRepository(),
        _connector = connector ?? GoogleHealthConnector(),
        _fitnessService = fitnessService ?? GoogleFitnessService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final HealthRepository _healthRepository;
  final GoogleHealthConnector _connector;
  final GoogleFitnessService _fitnessService;

  String get _uid => _auth.currentUser?.uid ?? 'local_user';

  // ---------------------------------------------------------------------------
  // 1. Connection Document Stream & Accessors
  // ---------------------------------------------------------------------------

  Stream<HealthConnection?> watchConnection() {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(_uid)
        .collection(FirestorePaths.connections)
        .doc(FirestorePaths.googleHealthConnectionDoc)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return HealthConnection.fromFirestore(doc);
    });
  }

  Future<HealthConnection?> getConnection() async {
    final doc = await _firestore
        .collection(FirestorePaths.users)
        .doc(_uid)
        .collection(FirestorePaths.connections)
        .doc(FirestorePaths.googleHealthConnectionDoc)
        .get();

    if (!doc.exists) return null;
    return HealthConnection.fromFirestore(doc);
  }

  // ---------------------------------------------------------------------------
  // 2. OAuth 2.0 Flow (Direct on-device authorization)
  // ---------------------------------------------------------------------------

  /// Launches Google Health OAuth 2.0 consent in an external browser.
  Future<void> startOAuthFlow() async {
    try {
      final authUrl = GoogleHealthConnector.buildAuthUrl(
        clientId: OAuthConstants.clientId,
        redirectUri: OAuthConstants.redirectUri,
        scopes: OAuthConstants.scopes,
        state: _uid,
      );

      final uri = Uri.parse(authUrl);
      if (!await canLaunchUrl(uri)) {
        throw const HealthConnectionException(
          message: 'Could not open the authorization browser.',
        );
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (e is AppException) rethrow;
      throw HealthConnectionException(
        message: 'Failed to start authorization: $e',
        cause: e,
      );
    }
  }

  /// Handles incoming OAuth deep link redirect (e.g. from app_links).
  /// Extracts code, exchanges tokens, saves credentials, and runs initial sync.
  Future<void> handleOAuthRedirect(Uri uri) async {
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      if (error == 'access_denied') {
        throw const HealthConnectionException(
          message: 'Authorization cancelled by user.',
        );
      }
      throw HealthConnectionException(
        message: 'OAuth authorization error: $error',
      );
    }

    if (code == null || code.isEmpty) {
      throw const HealthConnectionException(
        message: 'No authorization code received in redirect.',
      );
    }

    // 1. Exchange code for credentials
    final credentials = await _connector.exchangeCode(
      code: code,
      clientId: OAuthConstants.clientId,
      clientSecret: OAuthConstants.clientSecret,
      redirectUri: OAuthConstants.redirectUri,
    );

    // 2. Retrieve user's Google Health profile & paired devices
    String? profileName;
    String? profileEmail;
    try {
      final profileManager =
          GoogleHealthProfileDataManager(credentials: credentials);
      final profileResult =
          await profileManager.fetch(GoogleHealthProfileAPIURL.profile());
      if (profileResult.data.isNotEmpty) {
        final prof = profileResult.data.first;
        profileName = prof.displayName;
        profileEmail = prof.email;
      }
    } catch (e) {
      debugPrint('[HealthConnectionRepository] Profile fetch non-fatal: $e');
    }

    // 3. Save connection document to Firestore
    final connection = HealthConnection(
      id: FirestorePaths.googleHealthConnectionDoc,
      status: ConnectionStatus.active,
      provider: 'google_fitness',
      displayName: profileName ?? profileEmail,
      connectedAt: DateTime.now(),
      lastSyncAt: DateTime.now(),
    );

    await _firestore
        .collection(FirestorePaths.users)
        .doc(_uid)
        .collection(FirestorePaths.connections)
        .doc(FirestorePaths.googleHealthConnectionDoc)
        .set(connection.toJson(), SetOptions(merge: true));

    // 4. Trigger initial 30-day historical data synchronization
    await syncHealthData(fullHistory: true);
  }

  // ---------------------------------------------------------------------------
  // 3. Data Synchronization Pipeline (Google Fitness & Google Health -> Firestore)
  // ---------------------------------------------------------------------------

  /// Syncs health data from Google Fitness & Google Health API into Firestore.
  /// If [fullHistory] is true, fetches 30 days; otherwise fetches last 7 days.
  Future<Map<String, dynamic>> syncHealthData(
      {bool fullHistory = false}) async {
    final credentials = await GoogleHealthSession.loadCredentials();
    if (credentials == null) {
      throw const TokenRevokedException(
        message: 'Google Health is not connected. Please connect first.',
      );
    }

    await _healthRepository.updateSyncStatus(
      syncType: FirestorePaths.syncFull,
      status: 'running',
    );

    final daysToFetch = fullHistory
        ? AppConstants.initialSyncDays
        : AppConstants.dashboardChartDays;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: daysToFetch - 1));
    final endDate = now;

    int totalRecordsWritten = 0;
    final Map<String, HealthDaily> dailyBuckets = {};

    // Helper to get or create daily bucket
    HealthDaily getBucket(String date) {
      return dailyBuckets.putIfAbsent(
        date,
        () => HealthDaily(
          date: date,
          source: 'google_fitness',
          updatedAt: DateTime.now(),
        ),
      );
    }

    try {
      // -----------------------------------------------------------------------
      // A. Real-time Google Fitness REST API (legacy fallback if granted)
      // -----------------------------------------------------------------------
      final hasFitnessScope =
          credentials.grantedScopes.any((s) => s.contains('fitness'));
      if (hasFitnessScope) {
        try {
          debugPrint(
              '[syncHealthData] Querying Google Fitness API for $startDate to $endDate...');
          final fitnessDailies = await _fitnessService.fetchDailyAggregates(
            credentials: credentials,
            startDate: startDate,
            endDate: endDate,
          );

          for (final item in fitnessDailies) {
            if (item.date.isEmpty) continue;
            dailyBuckets[item.date] = item;
          }

          final sleepSessions = await _fitnessService.fetchSleepSessions(
            credentials: credentials,
            startDate: startDate,
            endDate: endDate,
          );

          for (final sleep in sleepSessions) {
            await _healthRepository.saveSleepRecord(sleep);
            final existing = getBucket(sleep.date);
            dailyBuckets[sleep.date] = existing.copyWith(
              sleepMinutes:
                  (existing.sleepMinutes ?? 0) + sleep.durationMinutes,
            );
          }
          debugPrint(
              '[syncHealthData] Google Fitness query completed: ${fitnessDailies.length} days returned');
        } catch (e) {
          debugPrint('[syncHealthData] Google Fitness sync error: $e');
        }
      }

      // -----------------------------------------------------------------------
      // B. Activity: Steps (RollUp)
      // -----------------------------------------------------------------------
      try {
        final stepsManager =
            GoogleHealthStepsDataManager(credentials: credentials);
        final stepsResult = await stepsManager.fetch(
          GoogleHealthStepsAPIURL.dateRange(
            startDate: startDate,
            endDate: endDate,
          ),
        );

        final Map<String, int> dailyStepsSum = {};
        final Map<String, double> dailyDistSum = {};
        final Map<String, int> dailyCalSum = {};

        for (final item in stepsResult.data) {
          if (item.date.isEmpty) continue;
          dailyStepsSum[item.date] =
              (dailyStepsSum[item.date] ?? 0) + item.countSum;
          if (item.distanceMetersSum != null && item.distanceMetersSum! > 0) {
            dailyDistSum[item.date] =
                (dailyDistSum[item.date] ?? 0.0) + item.distanceMetersSum!;
          }
          if (item.caloriesSum != null && item.caloriesSum! > 0) {
            dailyCalSum[item.date] =
                (dailyCalSum[item.date] ?? 0) + item.caloriesSum!;
          }
        }

        debugPrint(
            '[syncHealthData] Steps aggregated: ${dailyStepsSum.length} dates -> $dailyStepsSum');

        for (final entry in dailyStepsSum.entries) {
          final date = entry.key;
          final stepCount = entry.value;
          final existing = getBucket(date);
          final estDistance =
              (dailyDistSum[date] != null && dailyDistSum[date]! >= 10)
                  ? dailyDistSum[date]!
                  : (stepCount * 0.762);
          final estCalories =
              (dailyCalSum[date] != null && dailyCalSum[date]! > 0)
                  ? dailyCalSum[date]!
                  : (1400 + (stepCount * 0.04).round());

          dailyBuckets[date] = existing.copyWith(
            steps: stepCount,
            distanceMeters: estDistance,
            calories: estCalories,
            source: 'google_health',
          );
        }

        // Progressive save: push steps immediately to Firestore so UI updates in real-time
        if (dailyBuckets.isNotEmpty) {
          await _healthRepository
              .batchSaveDailySummaries(dailyBuckets.values.toList());
        }
      } catch (e) {
        debugPrint('[syncHealthData] Steps sync warning: $e');
      }

      // -----------------------------------------------------------------------
      // B. Activity: Active Minutes & Sedentary (RollUp)
      // -----------------------------------------------------------------------
      try {
        final activeMinutesManager =
            GoogleHealthActiveMinutesDataManager(credentials: credentials);
        final activeResult = await activeMinutesManager.fetch(
          GoogleHealthActiveMinutesAPIURL.dateRange(
            startDate: startDate,
            endDate: endDate,
          ),
        );

        final Map<String, int> dailyActiveSum = {};
        final Map<String, int> dailyActiveCalSum = {};

        for (final item in activeResult.data) {
          if (item.date.isEmpty) continue;
          dailyActiveSum[item.date] =
              (dailyActiveSum[item.date] ?? 0) + item.activeMinutesSum;
          if (item.activeCaloriesSum != null && item.activeCaloriesSum! > 0) {
            dailyActiveCalSum[item.date] =
                (dailyActiveCalSum[item.date] ?? 0) + item.activeCaloriesSum!;
          }
        }

        for (final entry in dailyActiveSum.entries) {
          final date = entry.key;
          final activeMin = entry.value;
          final existing = getBucket(date);
          final stepCount = existing.steps ?? 0;
          final estActiveCal = dailyActiveCalSum[date] ??
              ((stepCount * 0.04).round() + (activeMin * 4));
          final estTotalCal =
              (existing.calories != null && existing.calories! > 1400)
                  ? (1400 + estActiveCal)
                  : (1400 + estActiveCal);
          dailyBuckets[date] = existing.copyWith(
            activeMinutes: activeMin,
            activeCalories: estActiveCal > 0 ? estActiveCal : null,
            calories: estTotalCal,
          );
        }

        final sedentaryManager =
            GoogleHealthSedentaryPeriodDataManager(credentials: credentials);
        final sedentaryResult = await sedentaryManager.fetch(
          GoogleHealthSedentaryPeriodAPIURL.dateRange(
            startDate: startDate,
            endDate: endDate,
          ),
        );

        final Map<String, int> dailySedentarySum = {};
        for (final item in sedentaryResult.data) {
          if (item.date.isEmpty) continue;
          dailySedentarySum[item.date] =
              (dailySedentarySum[item.date] ?? 0) + item.sedentaryMinutesSum;
        }

        for (final entry in dailySedentarySum.entries) {
          final date = entry.key;
          final sedentaryMin = entry.value;
          final existing = getBucket(date);
          dailyBuckets[date] = existing.copyWith(
            sedentaryMinutes: sedentaryMin,
          );
        }

        // Progressive save: active minutes & sedentary
        if (dailyBuckets.isNotEmpty) {
          await _healthRepository
              .batchSaveDailySummaries(dailyBuckets.values.toList());
        }
      } catch (e) {
        debugPrint('[syncHealthData] Active minutes warning: $e');
      }

      // -----------------------------------------------------------------------
      // C. Cardiovascular: Resting Heart Rate & HRV (DataPoints)
      // -----------------------------------------------------------------------
      try {
        final rhrManager =
            GoogleHealthRestingHeartRateDataManager(credentials: credentials);
        final rhrResult = await rhrManager.fetch(
          GoogleHealthRestingHeartRateAPIURL.dateRange(
            startDate: startDate,
            endDate: endDate,
          ),
        );

        final hrValuesPerDate = <String, List<int>>{};
        for (final item in rhrResult.data) {
          if (item.date.isEmpty || item.bpm <= 0) continue;
          hrValuesPerDate.putIfAbsent(item.date, () => []).add(item.bpm);
        }
        for (final entry in hrValuesPerDate.entries) {
          final date = entry.key;
          final list = entry.value;
          final avgBpm = list.reduce((a, b) => a + b) ~/ list.length;
          final existing = getBucket(date);
          final currentRhr = existing.restingHeartRate;
          dailyBuckets[date] = existing.copyWith(
            restingHeartRate:
                (currentRhr != null && currentRhr > 0) ? currentRhr : avgBpm,
          );
        }

        final hrvManager = GoogleHealthHrvDataManager(credentials: credentials);
        final hrvResult = await hrvManager.fetch(
          GoogleHealthHrvAPIURL.dateRange(
            startDate: startDate,
            endDate: endDate,
          ),
        );

        for (final item in hrvResult.data) {
          if (item.date.isEmpty) continue;
          final existing = getBucket(item.date);
          dailyBuckets[item.date] = existing.copyWith(
            avgHrv: item.rmssd,
          );
        }

        // Progressive save: heart rate & HRV
        if (dailyBuckets.isNotEmpty) {
          await _healthRepository
              .batchSaveDailySummaries(dailyBuckets.values.toList());
        }
      } catch (e) {
        debugPrint('[syncHealthData] Heart rate sync warning: $e');
      }

      // -----------------------------------------------------------------------
      // D. Sleep: Sessions & Stages
      // -----------------------------------------------------------------------
      try {
        final sleepManager =
            GoogleHealthSleepDataManager(credentials: credentials);
        final sleepResult = await sleepManager.fetch(
          GoogleHealthSleepAPIURL.dateRange(
            startDate: startDate,
            endDate: endDate,
          ),
        );

        for (final session in sleepResult.data) {
          if (session.date.isEmpty) continue;
          final existing = getBucket(session.date);
          dailyBuckets[session.date] = existing.copyWith(
            sleepMinutes: session.durationMinutes,
            sleepScore: session.sleepScore ?? existing.sleepScore,
          );

          // Save individual sleep session record
          final sleepRecord = SleepRecord(
            date: session.date,
            startTime: session.startTime,
            endTime: session.endTime,
            durationMinutes: session.durationMinutes,
            awakeMinutes: session.awakeMinutes,
            lightMinutes: session.lightMinutes,
            deepMinutes: session.deepMinutes,
            remMinutes: session.remMinutes,
            sleepScore: session.sleepScore,
            source: session.source ?? 'google_wearables',
            updatedAt: DateTime.now(),
          );
          await _healthRepository.saveSleepRecord(sleepRecord);
        }

        // Progressive save: sleep
        if (dailyBuckets.isNotEmpty) {
          await _healthRepository
              .batchSaveDailySummaries(dailyBuckets.values.toList());
        }
      } catch (e) {
        debugPrint('[syncHealthData] Sleep sync warning: $e');
      }

      // -----------------------------------------------------------------------
      // E. Health Metrics: SpO2, Breathing Rate, Skin Temperature
      // -----------------------------------------------------------------------
      try {
        final spo2Manager =
            GoogleHealthOxygenSaturationDataManager(credentials: credentials);
        final spo2Result = await spo2Manager.fetch(
          GoogleHealthOxygenSaturationAPIURL.dateRange(
            startDate: startDate,
            endDate: endDate,
          ),
        );
        for (final item in spo2Result.data) {
          if (item.date.isEmpty) continue;
          final existing = getBucket(item.date);
          dailyBuckets[item.date] = existing.copyWith(avgSpo2: item.percentage);
        }
      } catch (e) {
        debugPrint('[syncHealthData] SpO2 sync note: $e');
      }

      try {
        final brManager =
            GoogleHealthBreathingRateDataManager(credentials: credentials);
        final brResult = await brManager.fetch(
          GoogleHealthBreathingRateAPIURL.dateRange(
            startDate: startDate,
            endDate: endDate,
          ),
        );
        for (final item in brResult.data) {
          if (item.date.isEmpty) continue;
          final existing = getBucket(item.date);
          dailyBuckets[item.date] =
              existing.copyWith(breathingRate: item.breathsPerMinute);
        }
      } catch (e) {
        debugPrint('[syncHealthData] Breathing rate sync note: $e');
      }

      try {
        final stManager =
            GoogleHealthSkinTemperatureDataManager(credentials: credentials);
        final stResult = await stManager.fetch(
          GoogleHealthSkinTemperatureAPIURL.dateRange(
            startDate: startDate,
            endDate: endDate,
          ),
        );
        for (final item in stResult.data) {
          if (item.date.isEmpty) continue;
          final existing = getBucket(item.date);
          dailyBuckets[item.date] =
              existing.copyWith(skinTempDeviation: item.deviationCelsius);
        }
      } catch (e) {
        debugPrint('[syncHealthData] Skin temp sync note: $e');
      }

      // -----------------------------------------------------------------------
      // F. Batch persist normalized daily summaries to Firestore
      // -----------------------------------------------------------------------
      if (dailyBuckets.isNotEmpty) {
        debugPrint(
            '[syncHealthData] 💾 Persisting ${dailyBuckets.length} summaries to Firestore: ${dailyBuckets.entries.map((e) => "${e.key}: ${e.value.steps} steps").toList()}');
        await _healthRepository
            .batchSaveDailySummaries(dailyBuckets.values.toList());
        totalRecordsWritten += dailyBuckets.length;
      }

      // -----------------------------------------------------------------------
      // G. Update connection & sync status
      // -----------------------------------------------------------------------
      await _firestore
          .collection(FirestorePaths.users)
          .doc(_uid)
          .collection(FirestorePaths.connections)
          .doc(FirestorePaths.googleHealthConnectionDoc)
          .set({
        'lastSyncAt': FieldValue.serverTimestamp(),
        'status': ConnectionStatus.active.name,
      }, SetOptions(merge: true));

      await _healthRepository.updateSyncStatus(
        syncType: FirestorePaths.syncFull,
        status: 'success',
        recordsWritten: totalRecordsWritten,
        lastSuccessfulDate: DateFormat('yyyy-MM-dd').format(now),
      );

      return {
        'success': true,
        'recordsWritten': totalRecordsWritten,
        'syncedDays': dailyBuckets.length,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      await _healthRepository.updateSyncStatus(
        syncType: FirestorePaths.syncFull,
        status: 'error',
        errorMessage: e.toString(),
      );

      if (e is TokenRevokedException) {
        // Mark connection disconnected
        await _firestore
            .collection(FirestorePaths.users)
            .doc(_uid)
            .collection(FirestorePaths.connections)
            .doc(FirestorePaths.googleHealthConnectionDoc)
            .set({
          'status': ConnectionStatus.disconnected.name,
          'errorMessage': 'Token revoked or expired. Please reconnect.',
        }, SetOptions(merge: true));
        rethrow;
      }

      throw SyncException(
        message: 'Health data synchronization failed: $e',
        cause: e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Disconnect
  // ---------------------------------------------------------------------------

  Future<void> disconnectGoogleHealth() async {
    try {
      final creds = await GoogleHealthSession.loadCredentials();
      if (creds != null) {
        await _connector.revoke(creds);
      }
    } catch (e) {
      debugPrint('[HealthConnectionRepository] Disconnect non-fatal: $e');
    } finally {
      await GoogleHealthSession.logout();

      await _firestore
          .collection(FirestorePaths.users)
          .doc(_uid)
          .collection(FirestorePaths.connections)
          .doc(FirestorePaths.googleHealthConnectionDoc)
          .set({
        'status': ConnectionStatus.disconnected.name,
        'lastDisconnectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection(FirestorePaths.users).doc(_uid).set({
        'healthConnected': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Stream<List<SyncStatus>> watchSyncStatuses() =>
      _healthRepository.watchSyncStatuses();

  Future<void> clearAllHealthData() => _healthRepository.clearAllHealthData();
}
