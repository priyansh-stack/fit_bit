import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> fitbitBackgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('Fitbit FCM Background: Message ${message.messageId} - Data: ${message.data}');
    if (message.data['action'] == 'SYNC_FITBIT') {
      debugPrint('Fitbit FCM Background: Background sync requested.');
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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _currentUserId;

  static const AndroidNotificationChannel goalsChannel = AndroidNotificationChannel(
    'fitbit_goals_channel',
    'Fitbit Weekly & Daily Goals',
    description: 'Notifications celebrating weekly milestone achievements and progress summaries.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel deviceChannel = AndroidNotificationChannel(
    'fitbit_device_channel',
    'Fitbit Tracker & Battery Alerts',
    description: 'Critical battery level and wearable hardware status notifications.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel syncChannel = AndroidNotificationChannel(
    'fitbit_sync_channel',
    'Fitbit Sync Reminders',
    description: 'Sync status and background data ingestion updates.',
    importance: Importance.defaultImportance,
    playSound: false,
    enableVibration: false,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('Fitbit FCM: Authorization status: ${settings.authorizationStatus}');

      // 1. Initialize Local Notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Fitbit Notification clicked: ${response.payload}');
        },
      );

      final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(goalsChannel);
        await androidPlatform.createNotificationChannel(deviceChannel);
        await androidPlatform.createNotificationChannel(syncChannel);
      }

      // 2. Foreground Remote Message Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Fitbit FCM Foreground: ${message.notification?.title} - ${message.notification?.body}');
        final notification = message.notification;
        if (notification != null) {
          showLocalAlert(
            title: notification.title ?? 'Fitbit Health Notification',
            body: notification.body ?? '',
            channel: goalsChannel,
            payload: message.data.toString(),
          );
        }
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

  Future<void> updateTopicSubscription(String topic, bool enable) async {
    try {
      if (enable) {
        await _fcm.subscribeToTopic(topic);
        debugPrint('Fitbit FCM: Subscribed to $topic');
      } else {
        await _fcm.unsubscribeFromTopic(topic);
        debugPrint('Fitbit FCM: Unsubscribed from $topic');
      }
    } catch (e) {
      debugPrint('Fitbit FCM: Topic error: $e');
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

  Future<void> showLocalAlert({
    required String title,
    required String body,
    AndroidNotificationChannel channel = goalsChannel,
    String? payload,
    int? id,
  }) async {
    await _localNotifications.show(
      id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  Future<void> showWeeklyGoalCelebration({
    required String goalType,
    required int achieved,
    required int target,
    required String unit,
  }) async {
    await showLocalAlert(
      title: '🏆 Weekly $goalType Goal Crushed!',
      body: 'Outstanding consistency! You logged $achieved $unit (Target: $target $unit).',
      channel: goalsChannel,
      payload: '{"action":"weekly_goal_completed","goalType":"$goalType"}',
    );
  }

  Future<void> showWeeklyProgressSummary({
    required int stepsWeek,
    required int activeMinWeek,
    required double avgSleepHours,
  }) async {
    await showLocalAlert(
      title: '📊 Weekly Health & Fitness Summary',
      body: '$stepsWeek total steps • $activeMinWeek active mins • ${avgSleepHours.toStringAsFixed(1)}h avg sleep. Keep the momentum going!',
      channel: goalsChannel,
      payload: '{"action":"weekly_summary"}',
    );
  }

  Future<void> showLowBatteryAlert({required int batteryPercent}) async {
    await showLocalAlert(
      title: '⚠️ Tracker Battery Low ($batteryPercent%)',
      body: 'Connect your Fitbit tracker to avoid gaps in heart rate and sleep telemetry.',
      channel: deviceChannel,
      payload: '{"action":"battery_alert","level":$batteryPercent}',
    );
  }

  Future<void> showSyncReminder() async {
    await showLocalAlert(
      title: '🔄 Fitbit Sync Reminder',
      body: 'Open Fitbit to sync recent intraday heart rate and sleep staging data.',
      channel: syncChannel,
      payload: '{"action":"sync_reminder"}',
    );
  }
}
