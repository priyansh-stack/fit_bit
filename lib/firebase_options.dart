// File generated for Firebase project fitbit-health-dash-81a2f.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAZRC_xBlXVXamkM0WsZBrhT4p3VWXwn9U',
    appId: '1:589835266478:web:03202d8f6dfb6c3efd803f',
    messagingSenderId: '589835266478',
    projectId: 'fitbit-health-dash-81a2f',
    authDomain: 'fitbit-health-dash-81a2f.firebaseapp.com',
    storageBucket: 'fitbit-health-dash-81a2f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAZRC_xBlXVXamkM0WsZBrhT4p3VWXwn9U',
    appId: '1:589835266478:android:03202d8f6dfb6c3efd803f',
    messagingSenderId: '589835266478',
    projectId: 'fitbit-health-dash-81a2f',
    storageBucket: 'fitbit-health-dash-81a2f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAZRC_xBlXVXamkM0WsZBrhT4p3VWXwn9U',
    appId: '1:589835266478:ios:03202d8f6dfb6c3efd803f',
    messagingSenderId: '589835266478',
    projectId: 'fitbit-health-dash-81a2f',
    storageBucket: 'fitbit-health-dash-81a2f.firebasestorage.app',
    iosBundleId: 'com.healthdash.fitbit_health_dashboard',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAZRC_xBlXVXamkM0WsZBrhT4p3VWXwn9U',
    appId: '1:589835266478:ios:03202d8f6dfb6c3efd803f',
    messagingSenderId: '589835266478',
    projectId: 'fitbit-health-dash-81a2f',
    storageBucket: 'fitbit-health-dash-81a2f.firebasestorage.app',
    iosBundleId: 'com.healthdash.fitbit_health_dashboard',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAZRC_xBlXVXamkM0WsZBrhT4p3VWXwn9U',
    appId: '1:589835266478:web:03202d8f6dfb6c3efd803f',
    messagingSenderId: '589835266478',
    projectId: 'fitbit-health-dash-81a2f',
    authDomain: 'fitbit-health-dash-81a2f.firebaseapp.com',
    storageBucket: 'fitbit-health-dash-81a2f.firebasestorage.app',
  );
}
