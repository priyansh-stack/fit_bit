// lib/features/heart/cubit/heart_cubit.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/models/heart_rate_record.dart';
import '../../../core/utils/date_utils.dart';
import 'heart_state.dart';

export 'heart_state.dart';

class HeartCubit extends Cubit<HeartState> {
  HeartCubit({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(const HeartState()) {
    _subscribe();
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription? _dailySub;
  StreamSubscription? _hrSub;

  void _subscribe() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }

    final start = HealthDateUtils.lastNDates(14).first;

    _dailySub?.cancel();
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

    _hrSub?.cancel();
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

  void refresh() {
    emit(state.copyWith(isLoading: true));
    _subscribe();
  }

  @override
  Future<void> close() {
    _dailySub?.cancel();
    _hrSub?.cancel();
    return super.close();
  }
}
