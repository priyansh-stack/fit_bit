// lib/repositories/health_repository.dart
//
// Repository for reading and writing normalized health data in Firestore.
// Handles offline caching and Firestore stream watchers for UI screens.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_constants.dart';
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
          .collection(FirestorePaths.healthDaily)
          .doc(today)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return HealthDaily.fromFirestore(doc);
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
          .collection(FirestorePaths.healthDaily)
          .orderBy('date', descending: true)
          .limit(days)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map(HealthDaily.fromFirestore).toList();
        return list.reversed.toList(); // chronological order for charts
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
        .collection(FirestorePaths.healthDaily)
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
          .collection(FirestorePaths.healthDaily)
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
      final ref = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.healthDaily)
          .doc(s.date);
      batch.set(ref, s.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
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
          .collection(FirestorePaths.heartRate)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) {
        return snap.docs.map(HeartRateRecord.fromFirestore).toList();
      });
    });
  }

  Future<void> saveHeartRateRecord(HeartRateRecord record) async {
    final uid = _uid;
    if (uid == null) return;
    final docId = record.timestamp.toIso8601String().replaceAll(':', '-');
    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.heartRate)
        .doc(docId)
        .set(record.toJson(), SetOptions(merge: true));
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
          .collection(FirestorePaths.sleep)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) {
        return snap.docs.map(SleepRecord.fromFirestore).toList();
      });
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
          .collection(FirestorePaths.sleep)
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
    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sleep)
        .doc(record.date)
        .set(record.toJson(), SetOptions(merge: true));
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
    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sync)
        .doc(syncType)
        .set({
      'syncType': syncType,
      'status': status,
      'lastSyncAt': FieldValue.serverTimestamp(),
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (recordsWritten != null) 'recordsWritten': recordsWritten,
      if (lastSuccessfulDate != null) 'lastSuccessfulDate': lastSuccessfulDate,
    }, SetOptions(merge: true));
  }

  /// Purges all cached daily and sleep documents for the current user in Firestore.
  Future<void> clearAllHealthData() async {
    final uid = _uid;
    if (uid == null) return;
    final healthDailyDocs = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.healthDaily)
        .get();
    for (final doc in healthDailyDocs.docs) {
      await doc.reference.delete();
    }

    final sleepDocs = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sleep)
        .get();
    for (final doc in sleepDocs.docs) {
      await doc.reference.delete();
    }
  }
}
