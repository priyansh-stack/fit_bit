import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> fitbitBackgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('Fitbit FCM Background: Message ${message.messageId} - Data: ${message.data}');
    if (message.data['action'] == 'SYNC_FITBIT') {
      debugPrint('Fitbit FCM Background: Background sync requested.');
      // Background sync payload trigger
    }
  } catch (e) {
    debugPrint('Fitbit FCM Background error: $e');
  }
}

class FitbitFcmService {
  FitbitFcmService._internal();
  static final FitbitFcmService instance = FitbitFcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;
  String? _currentUserId;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('Fitbit FCM: Authorization status: ${settings.authorizationStatus}');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Fitbit FCM Foreground: ${message.notification?.title} - ${message.notification?.body}');
      });

      _fcm.onTokenRefresh.listen((newToken) {
        if (_currentUserId != null) {
          _persistTokenToFirestore(_currentUserId!, newToken);
        }
      });

      _initialized = true;
    } catch (e) {
      debugPrint('Fitbit FCM: Initialization error: $e');
    }
  }

  Future<void> syncUserSession(String userId) async {
    _currentUserId = userId;
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('Fitbit FCM: Device token for user $userId: $token');
        await _persistTokenToFirestore(userId, token);
      }
    } catch (e) {
      debugPrint('Fitbit FCM: Error syncing user token: $e');
    }
  }

  Future<void> _persistTokenToFirestore(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'fitbitFcmTokens': FieldValue.arrayUnion([token]),
        'lastFitbitFcmRegistration': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Fitbit FCM: Failed to save token to Firestore: $e');
    }
  }
}
