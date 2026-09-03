import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/user_goals.dart';
import 'goals_state.dart';

class GoalsCubit extends Cubit<GoalsState> {
  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String? _uid;
  StreamSubscription? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  GoalsCubit({
    required FirebaseFirestore firestore,
    FirebaseAuth? auth,
    String? uid,
  })  : _firestore = firestore,
        _auth = auth ??
            (uid == null && Firebase.apps.isNotEmpty
                ? FirebaseAuth.instance
                : null),
        _uid = uid,
        super(const GoalsLoaded(UserGoals.defaultGoals)) {
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      _subscribeToUid(uid);
    } else if (_auth != null) {
      _authSub = _auth.authStateChanges().listen((user) {
        if (user != null) {
          _subscribeToUid(user.uid);
        } else {
          _subscription?.cancel();
          emit(const GoalsLoaded(UserGoals.defaultGoals));
        }
      });
    }
  }

  void _subscribeToUid(String uid) {
    _subscription?.cancel();
    _subscription = _firestore
        .collection('users')
        .doc(uid)
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
        // Fallback gracefully to default goals if offline
        emit(const GoalsLoaded(UserGoals.defaultGoals));
      },
    );
  }

  Future<void> updateGoals(UserGoals newGoals) async {
    emit(GoalsLoaded(newGoals));

    final effectiveUid = _uid ?? _auth?.currentUser?.uid;
    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(effectiveUid)
            .collection('settings')
            .doc('goals')
            .set(newGoals.toJson(), SetOptions(merge: true));
      } catch (e) {
        try {
          await _firestore
              .collection('users')
              .doc(effectiveUid)
              .set({'goals': newGoals.toJson()}, SetOptions(merge: true));
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    _subscription?.cancel();
    return super.close();
  }
}
