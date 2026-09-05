// lib/features/heart/cubit/heart_cubit.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/models/heart_rate_record.dart';
import '../../../core/utils/date_utils.dart';
import '../../../repositories/health_repository.dart';
import 'heart_state.dart';

export 'heart_state.dart';

class HeartCubit extends Cubit<HeartState> {
  HeartCubit({
    HealthRepository? healthRepository,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _healthRepo = healthRepository,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(const HeartState()) {
    final user = _auth.currentUser;
    if (user != null) {
      _subscribe(user.uid);
    }
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _subscribe(user.uid);
      } else {
        _dailySub?.cancel();
        _hrSub?.cancel();
        emit(const HeartState(isLoading: false));
      }
    });
  }

  final HealthRepository? _healthRepo;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription? _authSub;
  StreamSubscription? _dailySub;
  StreamSubscription? _hrSub;

  void _subscribe([String? targetUid]) {
    final uid = targetUid ?? _auth.currentUser?.uid;
    if (uid == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }

    _dailySub?.cancel();
    final repo = _healthRepo;
    if (repo != null) {
      _dailySub = repo.watchRecentSummaries(days: 14).listen(
        (daily) {
          emit(state.copyWith(
            daily: daily,
            isLoading: false,
            errorMessage: () => null,
          ));
        },
        onError: (e) {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: () => e.toString(),
          ));
        },
      );
    } else {
      final start = HealthDateUtils.lastNDates(14).first;
      _dailySub = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.healthDaily)
          .where('date', isGreaterThanOrEqualTo: start)
          .orderBy('date')
          .snapshots()
          .map((s) => s.docs.map(HealthDaily.fromFirestore).toList())
          .listen(
        (daily) {
          emit(state.copyWith(
            daily: daily,
            isLoading: false,
            errorMessage: () => null,
          ));
        },
        onError: (e) {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: () => e.toString(),
          ));
        },
      );
    }

    _hrSub?.cancel();
    if (repo != null) {
      _hrSub = repo.watchRecentHeartRates(limit: 48).listen(
        (recentHR) {
          emit(state.copyWith(
            recentHR: recentHR,
            isLoading: false,
            errorMessage: () => null,
          ));
        },
        onError: (e) {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: () => e.toString(),
          ));
        },
      );
    } else {
      _hrSub = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.heartRate)
          .orderBy('timestamp', descending: true)
          .limit(48)
          .snapshots()
          .map((s) => s.docs.map(HeartRateRecord.fromFirestore).toList())
          .listen(
        (recentHR) {
          emit(state.copyWith(
            recentHR: recentHR,
            isLoading: false,
            errorMessage: () => null,
          ));
        },
        onError: (e) {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: () => e.toString(),
          ));
        },
      );
    }
  }

  void refresh() {
    emit(state.copyWith(isLoading: true));
    _subscribe();
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    _dailySub?.cancel();
    _hrSub?.cancel();
    return super.close();
  }
}
