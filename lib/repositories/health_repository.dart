// lib/repositories/health_repository.dart
//
// Repository for reading and writing normalized health data in Firestore.
// Handles offline caching and Firestore stream watchers for UI screens.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_constants.dart';
import '../core/models/exercise_record.dart';
import '../core/models/health_daily.dart';
import '../core/models/heart_rate_record.dart';
import '../core/models/sleep_record.dart';
import '../core/models/sync_status.dart';

class HealthRepository {
  HealthRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // 1. HEALTH DAILY (Aggregated Day Summaries)
  // ---------------------------------------------------------------------------

  /// Watch today's summary (or latest available)
  Stream<HealthDaily?> watchTodaySummary() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _firestore
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categoryDaily)
          .collection(FirestorePaths.records)
          .doc(today)
          .snapshots()
          .asyncMap((doc) async {
        if (doc.exists) return HealthDaily.fromFirestore(doc);
        // Fallback: check legacy healthDaily
        final legacyDoc = await _firestore
            .collection(FirestorePaths.users)
            .doc(user.uid)
            .collection(FirestorePaths.healthDaily)
            .doc(today)
            .get();
        if (legacyDoc.exists) return HealthDaily.fromFirestore(legacyDoc);
        return null;
      });
    });
  }

  /// Watch latest N days of daily summaries for charts (default 7)
  Stream<List<HealthDaily>> watchRecentSummaries({int days = 7}) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<HealthDaily>[]);
      return _firestore
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categoryDaily)
          .collection(FirestorePaths.records)
          .orderBy('date', descending: true)
          .limit(days)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map(HealthDaily.fromFirestore).toList();
        return list.reversed.toList();
      });
    });
  }

  /// Save or merge a daily summary
  Future<void> saveDailySummary(HealthDaily summary) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sharedHealth)
        .doc(FirestorePaths.categoryDaily)
        .collection(FirestorePaths.records)
        .doc(summary.date)
        .set(summary.toJson(), SetOptions(merge: true));
  }

  /// Retrieves recent daily summaries from Firestore mapped by date (yyyy-MM-dd).
  Future<Map<String, HealthDaily>> getRecentDailySummaries({int days = 35}) async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final snap = await _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categoryDaily)
          .collection(FirestorePaths.records)
          .orderBy('date', descending: true)
          .limit(days)
          .get();

      final result = <String, HealthDaily>{};
      for (final doc in snap.docs) {
        final summary = HealthDaily.fromFirestore(doc);
        if (summary.date.isNotEmpty) {
          result[summary.date] = summary;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Batch write daily summaries
  Future<void> batchSaveDailySummaries(List<HealthDaily> summaries) async {
    final uid = _uid;
    if (uid == null || summaries.isEmpty) return;
    final batch = _firestore.batch();
    for (final s in summaries) {
      final primaryRef = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categoryDaily)
          .collection(FirestorePaths.records)
          .doc(s.date);
      batch.set(primaryRef, s.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // 1B. EXERCISE & WORKOUT SESSIONS
  // ---------------------------------------------------------------------------

  /// Watch recent exercise/workout sessions from shared_health (fallback: legacy exercise).
  Stream<List<ExerciseRecord>> watchRecentExercises({int limit = 20}) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<ExerciseRecord>[]);
      return _firestore
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categoryExercise)
          .collection(FirestorePaths.records)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .snapshots()
          .asyncMap((snap) async {
        if (snap.docs.isNotEmpty) {
          return snap.docs.map(ExerciseRecord.fromFirestore).toList();
        }
        final legacySnap = await _firestore
            .collection(FirestorePaths.users)
            .doc(user.uid)
            .collection(FirestorePaths.exercise)
            .orderBy('startTime', descending: true)
            .limit(limit)
            .get();
        return legacySnap.docs.map(ExerciseRecord.fromFirestore).toList();
      });
    });
  }

  /// Batch save exercise records to both shared_health and legacy collections.
  /// Only writes records if new or modified compared to existing Firestore documents.
  Future<int> batchSaveExerciseRecords(List<ExerciseRecord> exercises) async {
    final uid = _uid;
    if (uid == null || exercises.isEmpty) return 0;

    final existingSnap = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sharedHealth)
        .doc(FirestorePaths.categoryExercise)
        .collection(FirestorePaths.records)
        .get();

    final existingMap = <String, Map<String, dynamic>>{};
    for (final doc in existingSnap.docs) {
      existingMap[doc.id] = doc.data();
    }

    final batch = _firestore.batch();
    int modifiedOrNewCount = 0;

    for (final ex in exercises) {
      final docId = '${ex.date}_${ex.startTime.millisecondsSinceEpoch}';
      final existingData = existingMap[docId];

      if (existingData != null) {
        final exDur = (existingData['durationMinutes'] as num?)?.toInt();
        final exCal = (existingData['calories'] as num?)?.toInt();
        final exDist = (existingData['distanceMeters'] as num?)?.toDouble();
        final exType = existingData['activityType'] as String?;

        if (exDur == ex.durationMinutes &&
            exCal == ex.calories &&
            exDist == ex.distanceMeters &&
            exType == ex.activityType) {
          // Unchanged: skip writing
          continue;
        }
      }

      final sharedRef = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categoryExercise)
          .collection(FirestorePaths.records)
          .doc(docId);
      batch.set(sharedRef, ex.toJson(), SetOptions(merge: true));

      final legacyRef = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.exercise)
          .doc(docId);
      batch.set(legacyRef, ex.toJson(), SetOptions(merge: true));

      modifiedOrNewCount++;
    }

    if (modifiedOrNewCount > 0) {
      final categoryDocRef = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categoryExercise);
      batch.set(categoryDocRef, {'lastUpdatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      await batch.commit();
    }

    return modifiedOrNewCount;
  }

  // ---------------------------------------------------------------------------
  // 2. HEART RATE & METRICS
  // ---------------------------------------------------------------------------

  Stream<List<HeartRateRecord>> watchRecentHeartRates({int limit = 50}) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<HeartRateRecord>[]);
      return _firestore
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categoryHeartRate)
          .collection(FirestorePaths.records)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) =>
              snap.docs.map(HeartRateRecord.fromFirestore).toList());
    });
  }

  Future<void> saveHeartRateRecord(HeartRateRecord record) async {
    final uid = _uid;
    if (uid == null) return;
    final docId = record.timestamp.toIso8601String().replaceAll(':', '-');
    final docRef = _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sharedHealth)
        .doc(FirestorePaths.categoryHeartRate)
        .collection(FirestorePaths.records)
        .doc(docId);
    final existing = await docRef.get();
    if (existing.exists) return;
    await docRef.set(record.toJson(), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // 3. SLEEP SESSIONS
  // ---------------------------------------------------------------------------

  Stream<List<SleepRecord>> watchRecentSleepSessions({int limit = 14}) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<SleepRecord>[]);
      return _firestore
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categorySleep)
          .collection(FirestorePaths.records)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) =>
              snap.docs.map(SleepRecord.fromFirestore).toList());
    });
  }

  /// Retrieves recent sleep records from Firestore mapped by date (yyyy-MM-dd).
  Future<Map<String, SleepRecord>> getRecentSleepRecords({int limit = 14}) async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final snap = await _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.sharedHealth)
          .doc(FirestorePaths.categorySleep)
          .collection(FirestorePaths.records)
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      final result = <String, SleepRecord>{};
      for (final doc in snap.docs) {
        final record = SleepRecord.fromFirestore(doc);
        if (record.date.isNotEmpty) {
          result[record.date] = record;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveSleepRecord(SleepRecord record) async {
    final uid = _uid;
    if (uid == null) return;
    final docRef = _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sharedHealth)
        .doc(FirestorePaths.categorySleep)
        .collection(FirestorePaths.records)
        .doc(record.date);

    final existingDoc = await docRef.get();
    if (existingDoc.exists) {
      final existing = SleepRecord.fromFirestore(existingDoc);
      final isUnchanged = existing.durationMinutes == record.durationMinutes &&
          existing.sleepScore == record.sleepScore &&
          existing.deepMinutes == record.deepMinutes &&
          existing.remMinutes == record.remMinutes &&
          existing.lightMinutes == record.lightMinutes &&
          existing.awakeMinutes == record.awakeMinutes;
      if (isUnchanged) return;
    }

    await docRef.set(record.toJson(), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // 4. SYNC CHECKPOINTS & STATUS
  // ---------------------------------------------------------------------------

  Stream<List<SyncStatus>> watchSyncStatuses() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<SyncStatus>[]);
      return _firestore
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .collection(FirestorePaths.apps)
          .doc(FirestorePaths.appFitbit)
          .collection(FirestorePaths.sync)
          .snapshots()
          .map((snap) => snap.docs.map(SyncStatus.fromFirestore).toList());
    });
  }

  Future<void> updateSyncStatus({
    required String syncType,
    required String status,
    String? errorMessage,
    int? recordsWritten,
    String? lastSuccessfulDate,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final payload = {
      'syncType': syncType,
      'status': status,
      'lastSyncAt': FieldValue.serverTimestamp(),
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (recordsWritten != null) 'recordsWritten': recordsWritten,
      if (lastSuccessfulDate != null) 'lastSuccessfulDate': lastSuccessfulDate,
    };

    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.apps)
        .doc(FirestorePaths.appFitbit)
        .collection(FirestorePaths.sync)
        .doc(syncType)
        .set(payload, SetOptions(merge: true));
  }

  /// Purges all cached daily and sleep documents for the current user in Firestore.
  Future<void> clearAllHealthData() async {
    final uid = _uid;
    if (uid == null) return;
    final dailyDocs = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sharedHealth)
        .doc(FirestorePaths.categoryDaily)
        .collection(FirestorePaths.records)
        .get();
    for (final doc in dailyDocs.docs) {
      await doc.reference.delete();
    }

    final sleepDocs = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sharedHealth)
        .doc(FirestorePaths.categorySleep)
        .collection(FirestorePaths.records)
        .get();
    for (final doc in sleepDocs.docs) {
      await doc.reference.delete();
    }
  }
}
