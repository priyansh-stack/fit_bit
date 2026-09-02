// lib/features/auth/data/auth_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/app_exception.dart';

/// Handles Firebase Authentication with Google Sign-In.
/// Creates/updates user document in Firestore on sign-in.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
            );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Signs in with Google and creates/updates the Firestore user document.
  Future<User> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const SignInCancelledException();
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // Create or update user document in Firestore
      await _upsertUserDocument(user);

      return user;
    } on SignInCancelledException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        message: e.message ?? 'Authentication failed.',
        cause: e,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException(message: 'Sign-in failed: $e', cause: e);
    }
  }

  /// Signs in anonymously or as guest for testing/demo purposes.
  Future<User> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user!;
      await _upsertUserDocument(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        message: e.message ?? 'Guest sign-in failed.',
        cause: e,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException(message: 'Guest sign-in failed: $e', cause: e);
    }
  }

  /// Signs out from Firebase and Google.
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Creates or updates users/{uid} in Firestore.
  Future<void> _upsertUserDocument(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      await docRef.update({
        'displayName': user.displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'updatedAt': now,
      });
    } else {
      await docRef.set({
        'displayName': user.displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'createdAt': now,
        'updatedAt': now,
        'healthConnected': false,
      });
    }
  }
}
