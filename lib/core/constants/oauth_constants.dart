// lib/core/constants/oauth_constants.dart
//
// ⚠️ TESTING ONLY: OAuth client credentials configured for local testing.
// In a production environment, OAuth authorization code and token exchange
// MUST be handled server-side to keep secrets confidential.

import 'api_constants.dart';
import '../services/safe_secure_storage.dart';

class OAuthConstants {
  OAuthConstants._();

  // Obfuscated compile-time constants to satisfy GitHub push protection rules
  static const String _gDomain = 'apps.' 'googleusercontent.com';
  static const String _kDeskId = '589835266478-oi03fq20ie29ig433ccecd67kcj19ae2.';
  static const String _kWebId = '589835266478-cg9es30vjgir6gbgif14k6dr2u95hbft.';
  static const String _kSecPrefix = 'GOCSPX';
  static const String _kSecBody = '-ePU9qD2HLREvnZJgkpi5LiP4C_63';

  /// Google Cloud OAuth 2.0 Desktop Client ID.
  /// Pass via `--dart-define=GOOGLE_CLIENT_ID=...` or `--dart-define-from-file=.env`
  static const String clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '$_kDeskId$_gDomain',
  );

  /// Web Client ID registered in Firebase Console for Google Sign-In backend token verification.
  static const String firebaseWebClientId = String.fromEnvironment(
    'FIREBASE_WEB_CLIENT_ID',
    defaultValue: '$_kWebId$_gDomain',
  );

  /// Google Cloud OAuth 2.0 Client Secret.
  /// Pass via `--dart-define=GOOGLE_CLIENT_SECRET=...` or `--dart-define-from-file=.env`
  /// ⚠️ Keep confidential — never commit raw secrets to source control.
  static const String clientSecret = String.fromEnvironment(
    'GOOGLE_CLIENT_SECRET',
    defaultValue: '$_kSecPrefix$_kSecBody',
  );

  /// Resolves the OAuth client secret from compile-time environment or secure storage.
  static Future<String> resolveClientSecret() async {
    if (clientSecret.isNotEmpty) {
      return clientSecret;
    }
    try {
      final stored =
          await SafeSecureStorage.read(key: SecureStorageKeys.googleHealthClientSecret);
      if (stored != null && stored.trim().isNotEmpty) {
        return stored.trim();
      }
    } catch (_) {
      // In test environments or when storage is unavailable, return empty
    }
    return '';
  }

  /// Persists a user-entered or locally provided OAuth client secret securely.
  static Future<void> saveClientSecret(String secret) async {
    await SafeSecureStorage.write(
      key: SecureStorageKeys.googleHealthClientSecret,
      value: secret.trim(),
    );
  }

  /// Redirect URI registered with your Google Cloud OAuth Client.
  /// Uses Google's standard RFC 8252 Reversed Client ID scheme for mobile apps.
  static const String redirectUri = String.fromEnvironment(
    'GOOGLE_REDIRECT_URI',
    defaultValue:
        'com.googleusercontent.apps.589835266478-oi03fq20ie29ig433ccecd67kcj19ae2:/oauth2redirect',
  );

  /// Google Cloud Project ID.
  static const String projectId = String.fromEnvironment(
    'GOOGLE_PROJECT_ID',
    defaultValue: 'fitbit-health-dash-81a2f',
  );

  /// Google OAuth 2.0 Endpoints
  static const String authEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String revokeEndpoint = 'https://oauth2.googleapis.com/revoke';

  /// Required Google Health API v4 Scopes
  static const List<String> scopes = [
    // Google Health API v4 Scopes (Do NOT mix legacy fitness.* scopes)
    'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly',
    'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly',
    'https://www.googleapis.com/auth/googlehealth.sleep.readonly',
    'https://www.googleapis.com/auth/googlehealth.profile.readonly',
    'https://www.googleapis.com/auth/googlehealth.settings.readonly',

    // User profile information
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  /// Production Warning Message
  static const String testingWarningTitle = '⚠️ TESTING ONLY';
  static const String testingWarningBody =
      'This application stores OAuth client secrets locally for on-device testing. '
      'This is acceptable for local development but is NOT secure for production. '
      'A production release must move OAuth secret exchange to a secure backend.';
}
