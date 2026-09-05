// lib/features/sleep/cubit/sleep_cubit.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/sleep_record.dart';
import '../../../core/utils/date_utils.dart';
import '../../../repositories/health_repository.dart';
import 'sleep_state.dart';

export 'sleep_state.dart';

class SleepCubit extends Cubit<SleepState> {
  SleepCubit({
    HealthRepository? healthRepository,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _healthRepo = healthRepository,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(const SleepState()) {
    final user = _auth.currentUser;
    if (user != null) {
      _subscribe(user.uid);
    }
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _subscribe(user.uid);
      } else {
        _sleepSub?.cancel();
        emit(const SleepState(isLoading: false));
      }
    });
  }

  final HealthRepository? _healthRepo;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription? _authSub;
  StreamSubscription? _sleepSub;

  void _subscribe([String? targetUid]) {
    final uid = targetUid ?? _auth.currentUser?.uid;
    if (uid == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }

    _sleepSub?.cancel();
    final repo = _healthRepo;
    if (repo != null) {
      _sleepSub = repo.watchRecentSleepSessions(limit: 14).listen(
        (sessions) {
          emit(state.copyWith(
            sessions: sessions,
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
      _sleepSub = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.sleep)
          .where('date', isGreaterThanOrEqualTo: start)
          .orderBy('date')
          .snapshots()
          .map((s) => s.docs.map(SleepRecord.fromFirestore).toList())
          .listen(
        (sessions) {
          emit(state.copyWith(
            sessions: sessions,
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
    _sleepSub?.cancel();
    return super.close();
  }
}
