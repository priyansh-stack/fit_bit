// lib/features/activity/cubit/activity_cubit.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/exercise_record.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/utils/date_utils.dart';
import 'activity_state.dart';

export 'activity_state.dart';

class ActivityCubit extends Cubit<ActivityState> {
  ActivityCubit({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(const ActivityState()) {
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _subscribe(user.uid);
      } else {
        _historySub?.cancel();
        _exerciseSub?.cancel();
        emit(const ActivityState(isLoading: false));
      }
    });
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription? _authSub;
  StreamSubscription? _historySub;
  StreamSubscription? _exerciseSub;

  void _subscribe([String? targetUid]) {
    final uid = targetUid ?? _auth.currentUser?.uid;
    if (uid == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }

    final start = HealthDateUtils.lastNDates(14).first;

    _historySub?.cancel();
    _historySub = _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.healthDaily)
        .where('date', isGreaterThanOrEqualTo: start)
        .orderBy('date')
        .snapshots()
        .map((s) => s.docs.map(HealthDaily.fromFirestore).toList())
        .listen(
      (history) {
        emit(state.copyWith(
          history: history,
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

    _exerciseSub?.cancel();
    _exerciseSub = _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.exercise)
        .orderBy('startTime', descending: true)
        .limit(10)
        .snapshots()
        .map((s) => s.docs.map(ExerciseRecord.fromFirestore).toList())
        .listen(
      (exercises) {
        emit(state.copyWith(
          exercises: exercises,
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

  void refresh() {
    emit(state.copyWith(isLoading: true));
    _subscribe();
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    _historySub?.cancel();
    _exerciseSub?.cancel();
    return super.close();
  }
}
