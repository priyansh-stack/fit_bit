// lib/features/sleep/cubit/sleep_cubit.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/sleep_record.dart';
import '../../../core/utils/date_utils.dart';
import 'sleep_state.dart';

export 'sleep_state.dart';

class SleepCubit extends Cubit<SleepState> {
  SleepCubit({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(const SleepState()) {
    _subscribe();
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription? _sleepSub;

  void _subscribe() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }

    final start = HealthDateUtils.lastNDates(14).first;

    _sleepSub?.cancel();
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

  void refresh() {
    emit(state.copyWith(isLoading: true));
    _subscribe();
  }

  @override
  Future<void> close() {
    _sleepSub?.cancel();
    return super.close();
  }
}
