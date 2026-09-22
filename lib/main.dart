// lib/main.dart
//
// Entry point — resilient initialization that works even without a live

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/fcm_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseOk = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseOk = true;
  } catch (e) {
    debugPrint('[main] Firebase.initializeApp skipped: $e');
  }

  if (firebaseOk) {
    // Offline persistence — safe to call before any reads
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // Initialize FCM Background Handler & Service
      FirebaseMessaging.onBackgroundMessage(fitbitBackgroundMessageHandler);
      await FitbitFcmService.instance.initialize();
    } catch (_) {}
  }

  runApp(const App());
}
