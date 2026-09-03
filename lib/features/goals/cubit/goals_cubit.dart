import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/user_goals.dart';
import 'goals_state.dart';

class GoalsCubit extends Cubit<GoalsState> {
  final FirebaseFirestore _firestore;
  final String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  GoalsCubit({
    required FirebaseFirestore firestore,
    required String? uid,
  })  : _firestore = firestore,
        _uid = uid,
        super(const GoalsLoaded(UserGoals.defaultGoals)) {
    _init();
  }

  void _init() {
    if (_uid == null || _uid.isEmpty) {
      emit(const GoalsLoaded(UserGoals.defaultGoals));
      return;
    }

    _subscription = _firestore
        .collection('users')
        .doc(_uid)
        .collection('settings')
        .doc('goals')
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          try {
            final goals = UserGoals.fromJson(snapshot.data()!);
            emit(GoalsLoaded(goals));
          } catch (e) {
            emit(const GoalsLoaded(UserGoals.defaultGoals));
          }
        } else {
          emit(const GoalsLoaded(UserGoals.defaultGoals));
        }
      },
      onError: (e) {
        // Fallback gracefully to default goals if offline or Firestore rule denies
        emit(const GoalsLoaded(UserGoals.defaultGoals));
      },
    );
  }

  Future<void> updateGoals(UserGoals newGoals) async {
    emit(GoalsLoaded(newGoals));

    if (_uid != null && _uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('goals')
            .set(newGoals.toJson(), SetOptions(merge: true));
      } catch (e) {
        // Local state was already updated; Firestore write can retry on next online sync
      }
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
