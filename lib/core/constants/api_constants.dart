// lib/core/constants/api_constants.dart

/// Google Health API v4 endpoints and parameters.
class GoogleHealthApiConstants {
  GoogleHealthApiConstants._();

  /// Google Health REST API v4 base URL
  static const String baseUrl = 'https://health.googleapis.com/v4/users/me';

  /// Data Source Family for Fitbit & Google Wearables
  static const String dataSourceFamilyWearables = 'google-wearables';

  /// Daily RollUp endpoint path suffix
  static const String dailyRollUpSuffix = '/dataPoints:dailyRollUp';

  /// Physical RollUp endpoint path suffix
  static const String rollUpSuffix = '/dataPoints:rollUp';

  /// DataPoints endpoint path suffix
  static const String dataPointsSuffix = '/dataPoints';
}

/// Firestore collection / document paths.
class FirestorePaths {
  FirestorePaths._();

  // Top-level collections
  static const String users = 'users';

  // Sub-collections under users/{uid}
  static const String connections = 'connections';
  static const String healthDaily = 'healthDaily';
  static const String heartRate = 'heartRate';
  static const String sleep = 'sleep';
  static const String exercise = 'exercise';
  static const String healthMetrics = 'healthMetrics';
  static const String sync = 'sync';

  // Specific connection doc ID
  static const String googleHealthConnectionDoc = 'google_health';

  // Sync document IDs
  static const String syncActivity = 'activity';
  static const String syncHeartRate = 'heartRate';
  static const String syncSleep = 'sleep';
  static const String syncMetrics = 'metrics';
  static const String syncFull = 'full';
}

/// Secure Storage Keys used with flutter_secure_storage.
class SecureStorageKeys {
  SecureStorageKeys._();

  static const String googleHealthAccessToken = 'gh_access_token';
  static const String googleHealthRefreshToken = 'gh_refresh_token';
  static const String googleHealthTokenExpiry = 'gh_token_expiry';
  static const String googleHealthGrantedScopes = 'gh_granted_scopes';
  static const String googleHealthUserId = 'gh_user_id';
  static const String googleHealthClientSecret = 'gh_client_secret';
}

/// Google Health API v4 — data type names.
class HealthDataTypes {
  HealthDataTypes._();

  static const String steps = 'steps';
  static const String distance = 'distance';
  static const String calories = 'calories';
  static const String activeCalories = 'active-calories';
  static const String activeMinutes = 'active-minutes';
  static const String sedentaryPeriod = 'sedentary-period';
  static const String heartRate = 'heart-rate';
  static const String restingHeartRate = 'heart-rate';
  static const String heartRateVariability = 'heart-rate-variability';
  static const String sleep = 'sleep';
  static const String exercise = 'exercise';
  static const String oxygenSaturation = 'oxygen-saturation';
  static const String breathingRate = 'respiratory-rate';
  static const String skinTemperature = 'skin-temperature';
  static const String electrocardiogram = 'electrocardiogram';
  static const String irregularRhythmNotification =
      'irregular-rhythm-notification';
  static const String profile = 'profile';
  static const String settings = 'settings';
  static const String pairedDevices = 'paired-devices';
}

/// Application-level constants.
class AppConstants {
  AppConstants._();

  /// Initial historical sync period in days (14 days for fast, responsive sync).
  static const int initialSyncDays = 14;

  /// Days shown on the dashboard chart.
  static const int dashboardChartDays = 7;

  /// Default step goal
  static const int defaultDailyStepGoal = 10000;

  /// Default calorie goal (kcal)
  static const int defaultDailyCalorieGoal = 2200;

  /// Default active minutes goal (minutes)
  static const int defaultDailyActiveMinutesGoal = 30;

  /// Default sleep goal (minutes, 8h = 480m)
  static const int defaultDailySleepGoalMinutes = 480;
}
