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

  String? get _uid => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // 1. Connection Document Stream & Accessors
  // ---------------------------------------------------------------------------

  Stream<HealthConnection?> watchConnection() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _firestore
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .collection(FirestorePaths.connections)
          .doc(FirestorePaths.googleHealthConnectionDoc)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return HealthConnection.fromFirestore(doc);
      });
    });
  }

  Future<HealthConnection?> getConnection() async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
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
    final clientSecret = await OAuthConstants.resolveClientSecret();
    if (clientSecret.isEmpty) {
      throw const HealthConnectionException(
        message: 'OAuth client_secret is missing. '
            'Please run with --dart-define-from-file=.env or configure your secret.',
      );
    }

    final credentials = await _connector.exchangeCode(
      code: code,
      clientId: OAuthConstants.clientId,
      clientSecret: clientSecret,
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

    // 3. Save connection document to Firestore (with encrypted/scoped credential backup)
    final connection = HealthConnection(
      id: FirestorePaths.googleHealthConnectionDoc,
      status: ConnectionStatus.active,
      provider: 'google_fitness',
      displayName: profileName ?? profileEmail,
      connectedAt: DateTime.now(),
      lastSyncAt: DateTime.now(),
    );

    final uid = _uid;
    if (uid == null) {
      throw const HealthConnectionException(
        message: 'User is not logged in. Please sign in before connecting.',
      );
    }

    final connectionData = connection.toJson()
      ..addAll({
        'accessToken': credentials.accessToken,
        if (credentials.refreshToken != null)
          'refreshToken': credentials.refreshToken,
        'tokenExpiry': credentials.tokenExpiry.toIso8601String(),
        'grantedScopes': credentials.grantedScopes,
        if (credentials.userId != null) 'healthUserId': credentials.userId,
      });

    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.connections)
        .doc(FirestorePaths.googleHealthConnectionDoc)
        .set(connectionData, SetOptions(merge: true));

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
    var credentials = await GoogleHealthSession.loadCredentials();
    if (credentials == null) {
      // Try restoring from Firestore backup if local storage was cleared on app restart
      final uid = _uid;
      if (uid != null) {
        try {
          final doc = await _firestore
              .collection(FirestorePaths.users)
              .doc(uid)
              .collection(FirestorePaths.connections)
              .doc(FirestorePaths.googleHealthConnectionDoc)
              .get();

          if (doc.exists) {
            final data = doc.data();
            final accessToken = data?['accessToken'] as String?;
            final refreshToken = data?['refreshToken'] as String?;
            final expiryStr = data?['tokenExpiry'] as String?;
            final scopes = (data?['grantedScopes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList();

            if (accessToken != null && refreshToken != null) {
              credentials = GoogleHealthCredentials(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenExpiry: expiryStr != null
                    ? DateTime.tryParse(expiryStr) ?? DateTime.now()
                    : DateTime.now(),
                grantedScopes: scopes ?? [],
                userId: data?['healthUserId'] as String?,
              );
              await GoogleHealthSession.saveCredentials(credentials);
              debugPrint(
                  '[HealthConnectionRepository] Restored credentials from Firestore backup');
            }
          }
        } catch (e) {
          debugPrint(
              '[HealthConnectionRepository] Credential restoration non-fatal error: $e');
        }
      }
    }

    if (credentials == null) {
      throw const HealthConnectionException(
        message: 'Google Health is not connected. Please connect first.',
      );
    }
    final resolvedSecret = await OAuthConstants.resolveClientSecret();
    final GoogleHealthCredentials creds = await _connector.refreshTokenIfNeeded(
      credentials,
      clientId: OAuthConstants.clientId,
      clientSecret: resolvedSecret,
    );

    await _healthRepository.updateSyncStatus(
      syncType: FirestorePaths.syncFull,
      status: 'running',
    );

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayDate = now.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterdayDate);
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // 1. Retrieve existing Firestore summaries in parallel so we can perform incremental sync
    // and avoid re-fetching or modifying finalized past data.
    final initialReads = await Future.wait([
      _healthRepository.getRecentDailySummaries(
        days: fullHistory
            ? AppConstants.initialSyncDays
            : AppConstants.dashboardChartDays * 2,
      ),
      _healthRepository.getRecentSleepRecords(
        limit: fullHistory ? AppConstants.initialSyncDays : 14,
      ),
    ]);
    final existingDailies = initialReads[0] as Map<String, HealthDaily>;
    final existingSleeps = initialReads[1] as Map<String, SleepRecord>;

    // 2. Compute the exact incremental date range to query from the APIs.
    DateTime startDate;
    final DateTime endDate = now;

    if (fullHistory) {
      startDate =
          now.subtract(const Duration(days: AppConstants.initialSyncDays - 1));
    } else {
      // Find the earliest missing or unfinalized date in recent history
      DateTime candidate = now;
      for (int i = 1; i < AppConstants.dashboardChartDays; i++) {
        final d = now.subtract(Duration(days: i));
        final dStr = DateFormat('yyyy-MM-dd').format(d);
        final existing = existingDailies[dStr];
        final isPastFinalized = existing != null &&
            (dStr.compareTo(yesterdayStr) < 0 ||
                (existing.updatedAt != null &&
                    existing.updatedAt!.isAfter(todayMidnight)) ||
                ((existing.steps ?? 0) > 0 &&
                    existing.sleepMinutes != null &&
                    existing.sleepMinutes! > 0));

        if (!isPastFinalized) {
          candidate = d;
        }
      }
      startDate = DateTime(candidate.year, candidate.month, candidate.day);
    }

    final startStr = DateFormat('yyyy-MM-dd').format(startDate);

    // Determines whether a past date's data is already complete and finalized in Firestore.
    // Finalized data is NEVER re-queried from external APIs and NEVER re-written to Firestore.
    bool isDateFinalized(String dateStr) {
      if (dateStr.isEmpty || dateStr == todayStr) {
        return false; // Today is active and constantly accumulating metrics
      }

      // If date is before our sync window, ignore it (never write older outliers)
      if (!fullHistory && dateStr.compareTo(startStr) < 0) {
        return true;
      }

      final existing = existingDailies[dateStr];
      if (existing == null) {
        return false; // Not in Firestore yet -> needs to be fetched
      }

      // If date is 2 or more days ago (older than yesterday):
      // Once stored in Firestore, historical days are 100% complete and finalized.
      if (dateStr.compareTo(yesterdayStr) < 0) {
        return true;
      }

      // If date is yesterday:
      // Yesterday is finalized once it has been synced today (after midnight),
      // or if it already has both sleep and step metrics stored.
      if (existing.updatedAt != null &&
          existing.updatedAt!.isAfter(todayMidnight)) {
        return true;
      }
      if ((existing.steps ?? 0) > 0 &&
          existing.sleepMinutes != null &&
          existing.sleepMinutes! > 0) {
        return true;
      }

      return false;
    }

    debugPrint(
        '[syncHealthData] 🚀 Incremental sync window: $startDate to $endDate (fullHistory: $fullHistory)');

    int totalRecordsWritten = 0;
    final Map<String, HealthDaily> dailyBuckets = {};

    // Helper to get or create daily bucket for unfinalized dates
    HealthDaily getBucket(String date) {
      return dailyBuckets.putIfAbsent(
        date,
        () {
          final existing = existingDailies[date];
          if (existing != null) {
            // Seed from existing document to preserve all non-overlapping fields
            return existing.copyWith(
              updatedAt: date == todayStr ? now : existing.updatedAt,
            );
          }
          return HealthDaily(
            date: date,
            source: 'google_health',
            updatedAt: now,
          );
        },
      );
    }

    // Atomic synchronous updater to prevent race conditions during parallel fetches
    void updateBucket(
        String date, HealthDaily Function(HealthDaily current) updater) {
      final current = getBucket(date);
      dailyBuckets[date] = updater(current);
    }

    // Pre-seed daily buckets for the active sync window
    for (DateTime d = startDate;
        !d.isAfter(endDate);
        d = d.add(const Duration(days: 1))) {
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      if (!isDateFinalized(dateStr)) {
        getBucket(dateStr);
      }
    }

    try {
      // -----------------------------------------------------------------------
      // Run independent data fetches CONCURRENTLY for maximum speed
      // -----------------------------------------------------------------------
      await Future.wait([
        // ---------------------------------------------------------------------
        // A. Google Fitness REST API (legacy fallback if granted)
        // ---------------------------------------------------------------------
        () async {
          final hasFitnessScope =
              creds.grantedScopes.any((s) => s.contains('fitness'));
          if (!hasFitnessScope) return;
          try {
            debugPrint(
                '[syncHealthData] Querying Google Fitness API for $startDate to $endDate...');
            final fitnessDailies = await _fitnessService.fetchDailyAggregates(
              credentials: creds,
              startDate: startDate,
              endDate: endDate,
            );

            for (final item in fitnessDailies) {
              if (item.date.isEmpty) continue;
              if (isDateFinalized(item.date)) continue;
              updateBucket(item.date, (_) => item);
            }

            final sleepSessions = await _fitnessService.fetchSleepSessions(
              credentials: creds,
              startDate: startDate,
              endDate: endDate,
            );

            for (final sleep in sleepSessions) {
              if (isDateFinalized(sleep.date)) continue;
              if (!existingSleeps.containsKey(sleep.date)) {
                await _healthRepository.saveSleepRecord(sleep);
              }
              updateBucket(
                sleep.date,
                (cur) => cur.copyWith(
                  sleepMinutes: (cur.sleepMinutes ?? 0) + sleep.durationMinutes,
                ),
              );
            }
          } catch (e) {
            debugPrint('[syncHealthData] Google Fitness sync error: $e');
          }
        }(),

        // ---------------------------------------------------------------------
        // B. Activity: Steps (RollUp)
        // ---------------------------------------------------------------------
        () async {
          try {
            final stepsManager =
                GoogleHealthStepsDataManager(credentials: creds);
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
              if (isDateFinalized(item.date)) continue;
              dailyStepsSum[item.date] =
                  (dailyStepsSum[item.date] ?? 0) + item.countSum;
              if (item.distanceMetersSum != null &&
                  item.distanceMetersSum! > 0) {
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
              if (isDateFinalized(date)) continue;
              final stepCount = entry.value;
              final estDistance =
                  (dailyDistSum[date] != null && dailyDistSum[date]! >= 10)
                      ? dailyDistSum[date]!
                      : (stepCount * 0.762);
              final estCalories =
                  (dailyCalSum[date] != null && dailyCalSum[date]! > 0)
                      ? dailyCalSum[date]!
                      : (1400 + (stepCount * 0.04).round());

              updateBucket(
                date,
                (cur) => cur.copyWith(
                  steps: stepCount,
                  distanceMeters: estDistance,
                  calories: estCalories,
                  source: 'google_health',
                ),
              );
            }
          } catch (e) {
            debugPrint('[syncHealthData] Steps sync warning: $e');
          }
        }(),

        // ---------------------------------------------------------------------
        // C. Activity: Active Minutes & Sedentary (RollUp)
        // ---------------------------------------------------------------------
        () async {
          try {
            final activeMinutesManager =
                GoogleHealthActiveMinutesDataManager(credentials: creds);
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
              if (isDateFinalized(item.date)) continue;
              dailyActiveSum[item.date] =
                  (dailyActiveSum[item.date] ?? 0) + item.activeMinutesSum;
              if (item.activeCaloriesSum != null &&
                  item.activeCaloriesSum! > 0) {
                dailyActiveCalSum[item.date] =
                    (dailyActiveCalSum[item.date] ?? 0) +
                        item.activeCaloriesSum!;
              }
            }

            for (final entry in dailyActiveSum.entries) {
              final date = entry.key;
              if (isDateFinalized(date)) continue;
              final activeMin = entry.value;
              updateBucket(date, (cur) {
                final stepCount = cur.steps ?? 0;
                final estActiveCal = dailyActiveCalSum[date] ??
                    ((stepCount * 0.04).round() + (activeMin * 4));
                final estTotalCal = 1400 + estActiveCal;
                return cur.copyWith(
                  activeMinutes: activeMin,
                  activeCalories: estActiveCal > 0 ? estActiveCal : null,
                  calories: estTotalCal,
                );
              });
            }

            final sedentaryManager =
                GoogleHealthSedentaryPeriodDataManager(credentials: creds);
            final sedentaryResult = await sedentaryManager.fetch(
              GoogleHealthSedentaryPeriodAPIURL.dateRange(
                startDate: startDate,
                endDate: endDate,
              ),
            );

            final Map<String, int> dailySedentarySum = {};
            for (final item in sedentaryResult.data) {
              if (item.date.isEmpty) continue;
              if (isDateFinalized(item.date)) continue;
              dailySedentarySum[item.date] =
                  (dailySedentarySum[item.date] ?? 0) +
                      item.sedentaryMinutesSum;
            }

            for (final entry in dailySedentarySum.entries) {
              final date = entry.key;
              if (isDateFinalized(date)) continue;
              final sedentaryMin = entry.value;
              updateBucket(
                date,
                (cur) => cur.copyWith(sedentaryMinutes: sedentaryMin),
              );
            }
          } catch (e) {
            debugPrint('[syncHealthData] Active minutes warning: $e');
          }
        }(),

        // ---------------------------------------------------------------------
        // D. Cardiovascular: Resting Heart Rate & HRV
        // ---------------------------------------------------------------------
        () async {
          try {
            final rhrManager =
                GoogleHealthRestingHeartRateDataManager(credentials: creds);
            final rhrResult = await rhrManager.fetch(
              GoogleHealthRestingHeartRateAPIURL.dateRange(
                startDate: startDate,
                endDate: endDate,
              ),
            );

            final hrValuesPerDate = <String, List<int>>{};
            for (final item in rhrResult.data) {
              if (item.date.isEmpty || item.bpm <= 0) continue;
              if (isDateFinalized(item.date)) continue;
              hrValuesPerDate.putIfAbsent(item.date, () => []).add(item.bpm);
            }
            for (final entry in hrValuesPerDate.entries) {
              final date = entry.key;
              if (isDateFinalized(date)) continue;
              final list = entry.value;
              final avgBpm = list.reduce((a, b) => a + b) ~/ list.length;
              updateBucket(date, (cur) {
                final currentRhr = cur.restingHeartRate;
                return cur.copyWith(
                  restingHeartRate: (currentRhr != null && currentRhr > 0)
                      ? currentRhr
                      : avgBpm,
                );
              });
            }

            final hrvManager =
                GoogleHealthHrvDataManager(credentials: creds);
            final hrvResult = await hrvManager.fetch(
              GoogleHealthHrvAPIURL.dateRange(
                startDate: startDate,
                endDate: endDate,
              ),
            );

            for (final item in hrvResult.data) {
              if (item.date.isEmpty) continue;
              if (isDateFinalized(item.date)) continue;
              updateBucket(item.date, (cur) => cur.copyWith(avgHrv: item.rmssd));
            }
          } catch (e) {
            debugPrint('[syncHealthData] Heart rate sync warning: $e');
          }
        }(),

        // ---------------------------------------------------------------------
        // E. Sleep: Sessions & Stages
        // ---------------------------------------------------------------------
        () async {
          try {
            final sleepManager =
                GoogleHealthSleepDataManager(credentials: creds);
            final sleepResult = await sleepManager.fetch(
              GoogleHealthSleepAPIURL.dateRange(
                startDate: startDate,
                endDate: endDate,
              ),
            );

            for (final session in sleepResult.data) {
              if (session.date.isEmpty) continue;
              if (isDateFinalized(session.date)) continue;
              updateBucket(
                session.date,
                (cur) => cur.copyWith(
                  sleepMinutes: session.durationMinutes,
                  sleepScore: session.sleepScore ?? cur.sleepScore,
                ),
              );

              // Save individual sleep session record if not already stored
              if (!existingSleeps.containsKey(session.date)) {
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
                  updatedAt: now,
                );
                await _healthRepository.saveSleepRecord(sleepRecord);
              }
            }
          } catch (e) {
            debugPrint('[syncHealthData] Sleep sync warning: $e');
          }
        }(),

        // ---------------------------------------------------------------------
        // F. Health Metrics: SpO2, Breathing Rate, Skin Temperature
        // ---------------------------------------------------------------------
        () async {
          try {
            final spo2Manager =
                GoogleHealthOxygenSaturationDataManager(credentials: creds);
            final spo2Result = await spo2Manager.fetch(
              GoogleHealthOxygenSaturationAPIURL.dateRange(
                startDate: startDate,
                endDate: endDate,
              ),
            );
            for (final item in spo2Result.data) {
              if (item.date.isEmpty) continue;
              if (isDateFinalized(item.date)) continue;
              updateBucket(
                item.date,
                (cur) => cur.copyWith(avgSpo2: item.percentage),
              );
            }
          } catch (e) {
            debugPrint('[syncHealthData] SpO2 sync note: $e');
          }

          try {
            final brManager =
                GoogleHealthBreathingRateDataManager(credentials: creds);
            final brResult = await brManager.fetch(
              GoogleHealthBreathingRateAPIURL.dateRange(
                startDate: startDate,
                endDate: endDate,
              ),
            );
            for (final item in brResult.data) {
              if (item.date.isEmpty) continue;
              if (isDateFinalized(item.date)) continue;
              updateBucket(
                item.date,
                (cur) => cur.copyWith(breathingRate: item.breathsPerMinute),
              );
            }
          } catch (e) {
            debugPrint('[syncHealthData] Breathing rate sync note: $e');
          }

          try {
            final stManager =
                GoogleHealthSkinTemperatureDataManager(credentials: creds);
            final stResult = await stManager.fetch(
              GoogleHealthSkinTemperatureAPIURL.dateRange(
                startDate: startDate,
                endDate: endDate,
              ),
            );
            for (final item in stResult.data) {
              if (item.date.isEmpty) continue;
              if (isDateFinalized(item.date)) continue;
              updateBucket(
                item.date,
                (cur) =>
                    cur.copyWith(skinTempDeviation: item.deviationCelsius),
              );
            }
          } catch (e) {
            debugPrint('[syncHealthData] Skin temp sync note: $e');
          }
        }(),
      ]);

      // -----------------------------------------------------------------------
      // F. Batch persist only new or modified daily summaries to Firestore
      // -----------------------------------------------------------------------
      final List<HealthDaily> summariesToPersist = [];

      for (final summary in dailyBuckets.values) {
        if (summary.date.isEmpty) continue;
        if (isDateFinalized(summary.date)) continue;

        final existing = existingDailies[summary.date];
        if (existing != null && summary.date != todayStr) {
          // Compare past day metrics: if unchanged, do NOT touch document or updatedAt
          final hasChanged = existing.steps != summary.steps ||
              existing.distanceMeters != summary.distanceMeters ||
              existing.calories != summary.calories ||
              existing.activeMinutes != summary.activeMinutes ||
              existing.restingHeartRate != summary.restingHeartRate ||
              existing.sleepMinutes != summary.sleepMinutes ||
              existing.avgSpo2 != summary.avgSpo2 ||
              existing.avgHrv != summary.avgHrv;

          if (!hasChanged) {
            debugPrint(
                '[syncHealthData] Date ${summary.date} is unchanged. Skipping Firestore write.');
            continue;
          }
        }

        // Today or newly finalized past date with real changes gets updatedAt = now
        summariesToPersist.add(summary.copyWith(updatedAt: now));
      }

      if (summariesToPersist.isNotEmpty) {
        debugPrint(
            '[syncHealthData] 💾 Persisting ${summariesToPersist.length} modified/new summaries to Firestore: '
            '${summariesToPersist.map((e) => "${e.date}: ${e.steps} steps").toList()}');
        await _healthRepository.batchSaveDailySummaries(summariesToPersist);
        totalRecordsWritten += summariesToPersist.length;
      } else {
        debugPrint(
            '[syncHealthData] 💾 No daily summaries needed Firestore update.');
      }

      // -----------------------------------------------------------------------
      // G. Update connection & sync status
      // -----------------------------------------------------------------------
      final uid = _uid;
      if (uid != null) {
        await _firestore
            .collection(FirestorePaths.users)
            .doc(uid)
            .collection(FirestorePaths.connections)
            .doc(FirestorePaths.googleHealthConnectionDoc)
            .set({
          'lastSyncAt': FieldValue.serverTimestamp(),
          'status': ConnectionStatus.active.name,
        }, SetOptions(merge: true));
      }

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

      final uid = _uid;
      if (e is TokenRevokedException && uid != null) {
        // Mark connection disconnected
        await _firestore
            .collection(FirestorePaths.users)
            .doc(uid)
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

      final uid = _uid;
      if (uid != null) {
        await _firestore
            .collection(FirestorePaths.users)
            .doc(uid)
            .collection(FirestorePaths.connections)
            .doc(FirestorePaths.googleHealthConnectionDoc)
            .set({
          'status': ConnectionStatus.disconnected.name,
          'lastDisconnectedAt': FieldValue.serverTimestamp(),
          'accessToken': FieldValue.delete(),
          'refreshToken': FieldValue.delete(),
          'tokenExpiry': FieldValue.delete(),
        }, SetOptions(merge: true));

        await _firestore.collection(FirestorePaths.users).doc(uid).set({
          'healthConnected': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  Stream<List<SyncStatus>> watchSyncStatuses() =>
      _healthRepository.watchSyncStatuses();

  Future<void> clearAllHealthData() => _healthRepository.clearAllHealthData();
}
