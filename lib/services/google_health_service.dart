// lib/services/google_health_service.dart
//
// Direct Google Health API v4 implementation.
// Wraps Google Health REST API in a type-safe, Dart-idiomatic interface.
// Includes OAuth 2.0 PKCE / Authorization Code authorization, transparent token refresh,
// and typed DataManagers with day() and dateRange() factories.
// Source filtering uses dataSourceFamily=google-wearables for Fitbit devices.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/constants/api_constants.dart';
import '../core/constants/oauth_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/services/safe_secure_storage.dart';

// =============================================================================
// 1. OAUTH CREDENTIALS & SESSION
// =============================================================================

class GoogleHealthCredentials {
  GoogleHealthCredentials({
    required this.accessToken,
    this.refreshToken,
    required this.tokenExpiry,
    this.grantedScopes = const [],
    this.userId,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime tokenExpiry;
  final List<String> grantedScopes;
  final String? userId;

  bool get isExpiredOrExpiring =>
      DateTime.now().isAfter(tokenExpiry.subtract(const Duration(seconds: 60)));

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        if (refreshToken != null) 'refreshToken': refreshToken,
        'tokenExpiry': tokenExpiry.toIso8601String(),
        'grantedScopes': grantedScopes,
        if (userId != null) 'userId': userId,
      };

  factory GoogleHealthCredentials.fromJson(Map<String, dynamic> json) {
    return GoogleHealthCredentials(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      tokenExpiry: DateTime.parse(json['tokenExpiry'] as String),
      grantedScopes: (json['grantedScopes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      userId: json['userId'] as String?,
    );
  }
}

class GoogleHealthSession {
  GoogleHealthSession._();

  static Future<void> saveCredentials(GoogleHealthCredentials creds) async {
    await SafeSecureStorage.write(
      key: SecureStorageKeys.googleHealthAccessToken,
      value: creds.accessToken,
    );
    if (creds.refreshToken != null) {
      await SafeSecureStorage.write(
        key: SecureStorageKeys.googleHealthRefreshToken,
        value: creds.refreshToken,
      );
    }
    await SafeSecureStorage.write(
      key: SecureStorageKeys.googleHealthTokenExpiry,
      value: creds.tokenExpiry.toIso8601String(),
    );
    await SafeSecureStorage.write(
      key: SecureStorageKeys.googleHealthGrantedScopes,
      value: jsonEncode(creds.grantedScopes),
    );
    if (creds.userId != null) {
      await SafeSecureStorage.write(
        key: SecureStorageKeys.googleHealthUserId,
        value: creds.userId,
      );
    }
  }

  static Future<GoogleHealthCredentials?> loadCredentials() async {
    try {
      final token = await SafeSecureStorage.read(
          key: SecureStorageKeys.googleHealthAccessToken);
      final expiryStr = await SafeSecureStorage.read(
          key: SecureStorageKeys.googleHealthTokenExpiry);
      if (token == null || expiryStr == null) return null;

      final refreshToken = await SafeSecureStorage.read(
          key: SecureStorageKeys.googleHealthRefreshToken);
      final scopesStr = await SafeSecureStorage.read(
          key: SecureStorageKeys.googleHealthGrantedScopes);
      final userId =
          await SafeSecureStorage.read(key: SecureStorageKeys.googleHealthUserId);

      List<String> scopes = [];
      if (scopesStr != null) {
        try {
          scopes = (jsonDecode(scopesStr) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {}
      }

      return GoogleHealthCredentials(
        accessToken: token,
        refreshToken: refreshToken,
        tokenExpiry: DateTime.tryParse(expiryStr) ?? DateTime.now(),
        grantedScopes: scopes,
        userId: userId,
      );
    } catch (e) {
      debugPrint('[GoogleHealthSession] loadCredentials failed non-fatally: $e');
      return null;
    }
  }

  static Future<void> logout() async {
    await SafeSecureStorage.delete(key: SecureStorageKeys.googleHealthAccessToken);
    await SafeSecureStorage.delete(key: SecureStorageKeys.googleHealthRefreshToken);
    await SafeSecureStorage.delete(key: SecureStorageKeys.googleHealthTokenExpiry);
    await SafeSecureStorage.delete(key: SecureStorageKeys.googleHealthGrantedScopes);
    await SafeSecureStorage.delete(key: SecureStorageKeys.googleHealthUserId);
  }
}

class GoogleHealthConnector {
  GoogleHealthConnector({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Builds OAuth authorization URL and launches external browser.
  static String buildAuthUrl({
    required String clientId,
    required String redirectUri,
    required List<String> scopes,
    String? state,
  }) {
    final uri = Uri.parse(OAuthConstants.authEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'access_type': 'offline',
        'prompt': 'consent',
        'include_granted_scopes': 'true',
        if (state != null) 'state': state,
      },
    );
    return uri.toString();
  }

  /// Exchanges authorization code for access and refresh tokens.
  Future<GoogleHealthCredentials> exchangeCode({
    required String code,
    required String clientId,
    required String clientSecret,
    required String redirectUri,
  }) async {
    final response = await _client.post(
      Uri.parse(OAuthConstants.tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': code,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      final errorMsg =
          body['error_description'] ?? body['error'] ?? response.body;
      throw HealthConnectionException(
        message: 'Google Health token exchange failed: $errorMsg',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    final scopeStr = data['scope'] as String? ?? '';
    final scopes = scopeStr.split(' ').where((s) => s.isNotEmpty).toList();

    final credentials = GoogleHealthCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenExpiry: DateTime.now().add(Duration(seconds: expiresIn)),
      grantedScopes: scopes,
    );

    await GoogleHealthSession.saveCredentials(credentials);
    return credentials;
  }

  /// Refreshes token if expiring within 60s.
  Future<GoogleHealthCredentials> refreshTokenIfNeeded(
    GoogleHealthCredentials creds, {
    required String clientId,
    required String clientSecret,
  }) async {
    if (!creds.isExpiredOrExpiring) return creds;
    if (creds.refreshToken == null) {
      throw const TokenRevokedException(
        message: 'No refresh token available. Please reconnect Google Health.',
      );
    }

    final response = await _client.post(
      Uri.parse(OAuthConstants.tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': creds.refreshToken!,
        'grant_type': 'refresh_token',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 400 || response.statusCode == 401) {
      await GoogleHealthSession.logout();
      throw const TokenRevokedException(
        message: 'Authorization expired or revoked. Please reconnect.',
      );
    }

    if (response.statusCode != 200) {
      throw SyncException(
        message: 'Token refresh failed with HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final newAccessToken = data['access_token'] as String;
    final expiresIn = data['expires_in'] as int? ?? 3600;

    final updated = GoogleHealthCredentials(
      accessToken: newAccessToken,
      refreshToken: creds.refreshToken,
      tokenExpiry: DateTime.now().add(Duration(seconds: expiresIn)),
      grantedScopes: creds.grantedScopes,
      userId: creds.userId,
    );

    await GoogleHealthSession.saveCredentials(updated);
    return updated;
  }

  /// Revokes credentials and logs out.
  Future<void> revoke(GoogleHealthCredentials creds) async {
    try {
      final token = creds.refreshToken ?? creds.accessToken;
      await _client.post(
        Uri.parse(OAuthConstants.revokeEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'token': token},
      );
    } catch (e) {
      debugPrint('[GoogleHealthConnector] Revoke call non-fatal error: $e');
    } finally {
      await GoogleHealthSession.logout();
    }
  }
}

// =============================================================================
// 2. DATA RESULT & BASE MANAGER
// =============================================================================

class GoogleHealthResult<T> {
  const GoogleHealthResult({
    required this.data,
    this.sourceFamily,
    this.nextPageToken,
  });

  final List<T> data;
  final String? sourceFamily;
  final String? nextPageToken;
}

abstract class BaseGoogleHealthDataManager<T> {
  BaseGoogleHealthDataManager({
    required this.credentials,
    http.Client? client,
    this.clientId = OAuthConstants.clientId,
    this.clientSecret = OAuthConstants.clientSecret,
  })  : _client = client ?? http.Client(),
        _connector = GoogleHealthConnector(client: client);

  GoogleHealthCredentials credentials;
  final http.Client _client;
  final GoogleHealthConnector _connector;
  final String clientId;
  final String clientSecret;

  Future<GoogleHealthResult<T>> fetch(GoogleHealthAPIURL url);

  @protected
  Future<List<Map<String, dynamic>>> fetchAllPages(
      GoogleHealthAPIURL url) async {
    final allItems = <Map<String, dynamic>>[];
    final seenTokens = <String>{};
    String? nextPageToken;
    int pageCount = 0;

    do {
      pageCount++;
      GoogleHealthAPIURL pageUrl = url;
      if (nextPageToken != null && nextPageToken.isNotEmpty) {
        if (url.isRollUp) {
          final updatedBody = Map<String, dynamic>.from(url.requestBody ?? {});
          updatedBody['pageToken'] = nextPageToken;
          pageUrl = GoogleHealthAPIURL(
            url: url.url,
            isRollUp: true,
            requestBody: updatedBody,
          );
        } else {
          final sep = url.url.contains('?') ? '&' : '?';
          pageUrl = GoogleHealthAPIURL(
            url: '${url.url}${sep}pageToken=$nextPageToken',
            isRollUp: false,
          );
        }
      }

      final json = await executeRequest(pageUrl);
      final items = (json['rollupDataPoints'] as List<dynamic>? ??
              json['dataPoints'] as List<dynamic>? ??
              json['rollUps'] as List<dynamic>? ??
              json['sessions'] as List<dynamic>? ??
              json['data'] as List<dynamic>? ??
              (json.containsKey('steps') ||
                      json.containsKey('interval') ||
                      json.containsKey('sampleTime') ||
                      json.containsKey('civilStartTime')
                  ? [json]
                  : []))
          .whereType<Map<String, dynamic>>()
          .toList();

      allItems.addAll(items);
      nextPageToken = json['nextPageToken'] as String?;
      if (nextPageToken != null && !seenTokens.add(nextPageToken)) {
        break; // PREVENT DUPLICATE PAGE TOKEN LOOP
      }
    } while (
        nextPageToken != null && nextPageToken.isNotEmpty && pageCount < 15);

    return allItems;
  }

  @protected
  Future<Map<String, dynamic>> executeRequest(GoogleHealthAPIURL url) async {
    // 1. Transparent token refresh within 60 seconds of expiry
    final resolvedSecret = clientSecret.isNotEmpty
        ? clientSecret
        : await OAuthConstants.resolveClientSecret();
    credentials = await _connector.refreshTokenIfNeeded(
      credentials,
      clientId: clientId,
      clientSecret: resolvedSecret,
    );

    final requestUri = Uri.parse(url.url);
    final headers = {
      'Authorization': 'Bearer ${credentials.accessToken}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    http.Response response;
    if (url.isRollUp) {
      // POST for RollUp endpoint
      response = await _client
          .post(
            requestUri,
            headers: headers,
            body: jsonEncode(url.requestBody ?? {}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 400) {
        String dataPointsUrl = url.url.replaceAll(
          GoogleHealthApiConstants.dailyRollUpSuffix,
          GoogleHealthApiConstants.dataPointsSuffix,
        );
        if (url.requestBody?['pageToken'] != null) {
          final sep = dataPointsUrl.contains('?') ? '&' : '?';
          dataPointsUrl =
              '$dataPointsUrl${sep}pageToken=${url.requestBody!['pageToken']}';
        }
        final dataPointsUri = Uri.parse(dataPointsUrl);
        final fallbackResponse = await _client
            .get(dataPointsUri, headers: headers)
            .timeout(const Duration(seconds: 30));
        if (fallbackResponse.statusCode == 200) {
          response = fallbackResponse;
        }
      }
    } else {
      // GET for DataPoints endpoint
      response = await _client
          .get(requestUri, headers: headers)
          .timeout(const Duration(seconds: 30));
    }

    debugPrint(
        '[GoogleHealth] HTTP ${response.statusCode} on ${url.url}\nPayload: ${jsonEncode(url.requestBody)}\nResponse: ${response.body}');

    if (response.statusCode == 401) {
      throw const TokenRevokedException(
        message: 'Google Health token unauthorized. Please reconnect.',
      );
    }
    if (response.statusCode == 403) {
      throw ScopeMissingException(
        message: 'Google Health API 403: ${response.body}',
      );
    }
    if (response.statusCode == 429) {
      throw const RateLimitException(
        message: 'Google Health API rate limit exceeded. Please retry shortly.',
      );
    }
    if (response.statusCode != 200) {
      debugPrint(
          '[GoogleHealth] ERROR ${response.statusCode} on ${url.url}\nPayload: ${jsonEncode(url.requestBody)}\nResponse: ${response.body}');
      throw GoogleHealthApiException(
        message:
            'Google Health API request failed: HTTP ${response.statusCode} - ${response.body}',
        statusCode: response.statusCode,
      );
    }

    debugPrint(
        '[GoogleHealth] 🟢 SUCCESS 200 on ${url.url} (Body: ${response.body})');
    return jsonDecode(response.body) as Map<String, dynamic>? ?? {};
  }
}

// =============================================================================
// 3. API URL FACTORIES
// =============================================================================

class GoogleHealthAPIURL {
  const GoogleHealthAPIURL({
    required this.url,
    this.isRollUp = false,
    this.requestBody,
  });

  final String url;
  final bool isRollUp;
  final Map<String, dynamic>? requestBody;

  /// Daily Rollup Factory
  static GoogleHealthAPIURL day({
    required String dataType,
    required DateTime date,
    String dataSourceFamily =
        GoogleHealthApiConstants.dataSourceFamilyWearables,
  }) {
    final url =
        '${GoogleHealthApiConstants.baseUrl}/dataTypes/$dataType${GoogleHealthApiConstants.dailyRollUpSuffix}';

    return GoogleHealthAPIURL(
      url: url,
      isRollUp: true,
      requestBody: {
        'range': {
          'start': {
            'date': {
              'year': date.year,
              'month': date.month,
              'day': date.day,
            },
            'time': {
              'hours': 0,
              'minutes': 0,
              'seconds': 0,
              'nanos': 0,
            },
          },
          'end': {
            'date': {
              'year': date.year,
              'month': date.month,
              'day': date.day,
            },
            'time': {
              'hours': 23,
              'minutes': 59,
              'seconds': 59,
              'nanos': 0,
            },
          },
        },
      },
    );
  }

  /// Date Range Factory
  static GoogleHealthAPIURL dateRange({
    required String dataType,
    required DateTime startDate,
    required DateTime endDate,
    bool isRollUp = true,
    String dataSourceFamily =
        GoogleHealthApiConstants.dataSourceFamilyWearables,
  }) {
    if (isRollUp) {
      final url =
          '${GoogleHealthApiConstants.baseUrl}/dataTypes/$dataType${GoogleHealthApiConstants.dailyRollUpSuffix}';
      return GoogleHealthAPIURL(
        url: url,
        isRollUp: true,
        requestBody: {
          'range': {
            'start': {
              'date': {
                'year': startDate.year,
                'month': startDate.month,
                'day': startDate.day,
              },
              'time': {
                'hours': 0,
                'minutes': 0,
                'seconds': 0,
                'nanos': 0,
              },
            },
            'end': {
              'date': {
                'year': endDate.year,
                'month': endDate.month,
                'day': endDate.day,
              },
              'time': {
                'hours': 23,
                'minutes': 59,
                'seconds': 59,
                'nanos': 0,
              },
            },
          },
        },
      );
    } else {
      final uri = Uri.parse(
        '${GoogleHealthApiConstants.baseUrl}/dataTypes/$dataType${GoogleHealthApiConstants.dataPointsSuffix}',
      );

      return GoogleHealthAPIURL(url: uri.toString(), isRollUp: false);
    }
  }
}

// Specific URL builders per data type
class GoogleHealthStepsAPIURL {
  static GoogleHealthAPIURL day({required DateTime date}) =>
      GoogleHealthAPIURL.day(dataType: HealthDataTypes.steps, date: date);
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.steps,
        startDate: startDate,
        endDate: endDate,
      );
}

class GoogleHealthActiveMinutesAPIURL {
  static GoogleHealthAPIURL day({required DateTime date}) =>
      GoogleHealthAPIURL.day(
          dataType: HealthDataTypes.activeMinutes, date: date);
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.activeMinutes,
        startDate: startDate,
        endDate: endDate,
      );
}

class GoogleHealthSedentaryPeriodAPIURL {
  static GoogleHealthAPIURL day({required DateTime date}) =>
      GoogleHealthAPIURL.day(
          dataType: HealthDataTypes.sedentaryPeriod, date: date);
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.sedentaryPeriod,
        startDate: startDate,
        endDate: endDate,
      );
}

class GoogleHealthRestingHeartRateAPIURL {
  static GoogleHealthAPIURL day({required DateTime date}) =>
      GoogleHealthAPIURL.day(
          dataType: HealthDataTypes.restingHeartRate, date: date);
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.restingHeartRate,
        startDate: startDate,
        endDate: endDate,
        isRollUp: false,
      );
}

class GoogleHealthHrvAPIURL {
  static GoogleHealthAPIURL day({required DateTime date}) =>
      GoogleHealthAPIURL.day(
          dataType: HealthDataTypes.heartRateVariability, date: date);
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.heartRateVariability,
        startDate: startDate,
        endDate: endDate,
        isRollUp: false,
      );
}

class GoogleHealthSleepAPIURL {
  static GoogleHealthAPIURL day({required DateTime date}) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.sleep,
        startDate: date.subtract(const Duration(days: 1)),
        endDate: date,
        isRollUp: false,
      );
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.sleep,
        startDate: startDate,
        endDate: endDate,
        isRollUp: false,
      );
}

class GoogleHealthOxygenSaturationAPIURL {
  static GoogleHealthAPIURL day({required DateTime date}) =>
      GoogleHealthAPIURL.day(
          dataType: HealthDataTypes.oxygenSaturation, date: date);
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.oxygenSaturation,
        startDate: startDate,
        endDate: endDate,
        isRollUp: false,
      );
}

class GoogleHealthBreathingRateAPIURL {
  static GoogleHealthAPIURL day({required DateTime date}) =>
      GoogleHealthAPIURL.day(
          dataType: HealthDataTypes.breathingRate, date: date);
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.breathingRate,
        startDate: startDate,
        endDate: endDate,
        isRollUp: false,
      );
}

class GoogleHealthSkinTemperatureAPIURL {
  static GoogleHealthAPIURL day({required DateTime date}) =>
      GoogleHealthAPIURL.day(
          dataType: HealthDataTypes.skinTemperature, date: date);
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.skinTemperature,
        startDate: startDate,
        endDate: endDate,
        isRollUp: false,
      );
}

class GoogleHealthElectrocardiogramAPIURL {
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.electrocardiogram,
        startDate: startDate,
        endDate: endDate,
        isRollUp: false,
      );
}

class GoogleHealthIrregularRhythmNotificationAPIURL {
  static GoogleHealthAPIURL dateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      GoogleHealthAPIURL.dateRange(
        dataType: HealthDataTypes.irregularRhythmNotification,
        startDate: startDate,
        endDate: endDate,
        isRollUp: false,
      );
}

class GoogleHealthProfileAPIURL {
  static GoogleHealthAPIURL profile() => const GoogleHealthAPIURL(
        url: '${GoogleHealthApiConstants.baseUrl}/profile',
        isRollUp: false,
      );
}

class GoogleHealthPairedDeviceAPIURL {
  static GoogleHealthAPIURL devices() => const GoogleHealthAPIURL(
        url: '${GoogleHealthApiConstants.baseUrl}/devices',
        isRollUp: false,
      );
}

// =============================================================================
// 4. TYPED DATA MODELS (<Name>Data)
// =============================================================================

int _extractInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? (double.tryParse(v)?.toInt() ?? 0);
  if (v is Map) {
    for (final key in [
      'count',
      'countSum',
      'steps',
      'stepCount',
      'intVal',
      'integer',
      'value',
      'val',
      'scalar',
      'activeMinutes',
      'activeMinutesSum',
      'minutes',
      'sedentaryMinutes',
      'sedentaryMinutesSum',
      'bpm',
      'beatsPerMinute',
      'beats_per_minute',
      'restingBpm',
      'restingBeatsPerMinute',
      'averageBpm',
      'heartRate',
      'kcal',
      'calories',
      'caloriesSum',
      'activeCalories',
      'activeCaloriesSum',
    ]) {
      if (v.containsKey(key)) {
        final res = _extractInt(v[key]);
        if (res != 0) return res;
      }
    }
  }
  if (v is List && v.isNotEmpty) {
    return _extractInt(v.first);
  }
  return 0;
}

double? _extractDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  if (v is Map) {
    for (final key in [
      'fpVal',
      'doubleVal',
      'value',
      'val',
      'scalar',
      'meters',
      'distanceMeters',
      'distanceMetersSum',
      'rmssd',
      'percentage',
      'deviationCelsius',
      'breathsPerMinute',
      'rate',
      'beatsPerMinute',
    ]) {
      if (v.containsKey(key)) {
        final res = _extractDouble(v[key]);
        if (res != null) return res;
      }
    }
  }
  if (v is List && v.isNotEmpty) {
    return _extractDouble(v.first);
  }
  return null;
}

String _extractDate(Map<String, dynamic> json) {
  if (json['date'] is String && (json['date'] as String).isNotEmpty) {
    return json['date'] as String;
  }

  // 1. Direct top-level civilStartTime / civilEndTime / civilTime
  for (final civilKey in [
    'civilStartTime',
    'civilEndTime',
    'civilTime',
    'startTime',
    'endTime',
  ]) {
    final civil = json[civilKey];
    if (civil is Map) {
      final dateObj = civil['date'] ?? civil['civilTime']?['date'];
      if (dateObj is Map &&
          dateObj['year'] != null &&
          dateObj['month'] != null &&
          dateObj['day'] != null) {
        final y = dateObj['year'];
        final m = dateObj['month'].toString().padLeft(2, '0');
        final d = dateObj['day'].toString().padLeft(2, '0');
        return '$y-$m-$d';
      }
      final phys = civil['physicalTime'] ?? civil['time'] ?? civil['timestamp'];
      if (phys is String) {
        final dt = DateTime.tryParse(phys);
        if (dt != null) return DateFormat('yyyy-MM-dd').format(dt.toLocal());
      }
    } else if (civil is String) {
      final dt = DateTime.tryParse(civil);
      if (dt != null) return DateFormat('yyyy-MM-dd').format(dt.toLocal());
    }
  }

  // 2. Direct top-level sampleTime
  final topSample = json['sampleTime'];
  if (topSample is Map) {
    final civilDate = topSample['civilTime']?['date'] ?? topSample['date'];
    if (civilDate is Map &&
        civilDate['year'] != null &&
        civilDate['month'] != null &&
        civilDate['day'] != null) {
      final y = civilDate['year'];
      final m = civilDate['month'].toString().padLeft(2, '0');
      final d = civilDate['day'].toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    final phys = topSample['physicalTime'] ??
        topSample['time'] ??
        topSample['timestamp'];
    if (phys is String) {
      final dt = DateTime.tryParse(phys);
      if (dt != null) return DateFormat('yyyy-MM-dd').format(dt.toLocal());
    }
  }

  // 3. Nested payload inspection
  Map<String, dynamic>? payload;
  for (final key in [
    'steps',
    'activeMinutes',
    'sedentaryPeriod',
    'restingHeartRate',
    'heartRate',
    'heartRateVariability',
    'oxygenSaturation',
    'breathingRate',
    'skinTemperature',
    'sleep',
    'sleepSession',
    'value',
    'val',
  ]) {
    if (json[key] is Map<String, dynamic>) {
      payload = json[key] as Map<String, dynamic>;
      break;
    }
  }

  final target = payload ?? json;

  dynamic interval = target['interval'] ?? json['interval'];
  if (interval is Map) {
    final civilDate = interval['civilStartTime']?['date'] ??
        interval['civilTime']?['date'] ??
        interval['civilEndTime']?['date'];
    if (civilDate is Map &&
        civilDate['year'] != null &&
        civilDate['month'] != null &&
        civilDate['day'] != null) {
      final y = civilDate['year'];
      final m = civilDate['month'].toString().padLeft(2, '0');
      final d = civilDate['day'].toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    final startStr = interval['startTime'] ?? interval['start_time'];
    if (startStr != null) {
      final dt = DateTime.tryParse(startStr.toString());
      if (dt != null) {
        return DateFormat('yyyy-MM-dd').format(dt.toLocal());
      }
    }
  }

  final sampleTime = target['sampleTime'] ?? json['sampleTime'];
  if (sampleTime is Map) {
    final civilDate = sampleTime['civilTime']?['date'] ?? sampleTime['date'];
    if (civilDate is Map &&
        civilDate['year'] != null &&
        civilDate['month'] != null &&
        civilDate['day'] != null) {
      final y = civilDate['year'];
      final m = civilDate['month'].toString().padLeft(2, '0');
      final d = civilDate['day'].toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    final phys = sampleTime['physicalTime'] ??
        sampleTime['time'] ??
        sampleTime['timestamp'];
    if (phys != null) {
      final dt = DateTime.tryParse(phys.toString());
      if (dt != null) {
        return DateFormat('yyyy-MM-dd').format(dt.toLocal());
      }
    }
  }

  final ts = target['startTime'] ??
      target['timestamp'] ??
      target['time'] ??
      json['startTime'] ??
      json['timestamp'];
  if (ts != null) {
    final dt = DateTime.tryParse(ts.toString());
    if (dt != null) {
      return DateFormat('yyyy-MM-dd').format(dt.toLocal());
    }
  }

  return '';
}

Map<String, dynamic> _extractPayload(Map<String, dynamic> json) {
  for (final key in [
    'steps',
    'activeMinutes',
    'sedentaryPeriod',
    'restingHeartRate',
    'heartRate',
    'heartRateVariability',
    'oxygenSaturation',
    'breathingRate',
    'skinTemperature',
    'sleep',
    'sleepSession',
    'value',
    'val',
  ]) {
    if (json[key] is Map<String, dynamic>) {
      return json[key] as Map<String, dynamic>;
    }
  }
  return json;
}

class GoogleHealthStepsData {
  const GoogleHealthStepsData({
    required this.date,
    required this.countSum,
    this.distanceMetersSum,
    this.caloriesSum,
    this.sourceFamily,
  });

  final String date;
  final int countSum;
  final double? distanceMetersSum;
  final int? caloriesSum;
  final String? sourceFamily;

  factory GoogleHealthStepsData.fromJson(Map<String, dynamic> json) {
    final date = _extractDate(json);
    final val = _extractPayload(json);

    return GoogleHealthStepsData(
      date: date,
      countSum: _extractInt(val['count'] ??
          val['countSum'] ??
          val['steps'] ??
          val['stepCount'] ??
          val['intVal'] ??
          val['value'] ??
          val),
      distanceMetersSum: _extractDouble(
          val['distanceMetersSum'] ?? val['meters'] ?? val['distanceMeters']),
      caloriesSum:
          _extractInt(val['caloriesSum'] ?? val['kcal'] ?? val['calories']),
      sourceFamily: json['dataSourceFamily'] as String? ??
          (json['dataSource'] is Map
              ? json['dataSource']['platform'] as String?
              : null),
    );
  }
}

class GoogleHealthActiveMinutesData {
  const GoogleHealthActiveMinutesData({
    required this.date,
    required this.activeMinutesSum,
    this.activeCaloriesSum,
  });

  final String date;
  final int activeMinutesSum;
  final int? activeCaloriesSum;

  factory GoogleHealthActiveMinutesData.fromJson(Map<String, dynamic> json) {
    final date = _extractDate(json);
    final val = _extractPayload(json);

    int minutes = _extractInt(
        val['activeMinutes'] ?? val['activeMinutesSum'] ?? val['minutes']);
    final levelList = val['activeMinutesRollupByActivityLevel'] ??
        val['activeMinutesByActivityLevel'] ??
        json['activeMinutesRollupByActivityLevel'] ??
        json['activeMinutesByActivityLevel'];
    if (minutes == 0 && levelList is List) {
      for (final lvl in levelList) {
        minutes += _extractInt(lvl);
      }
    }

    return GoogleHealthActiveMinutesData(
      date: date,
      activeMinutesSum: minutes,
      activeCaloriesSum: _extractInt(
          val['activeCaloriesSum'] ?? val['activeCalories'] ?? val['kcal']),
    );
  }
}

class GoogleHealthSedentaryPeriodData {
  const GoogleHealthSedentaryPeriodData({
    required this.date,
    required this.sedentaryMinutesSum,
  });

  final String date;
  final int sedentaryMinutesSum;

  factory GoogleHealthSedentaryPeriodData.fromJson(Map<String, dynamic> json) {
    final date = _extractDate(json);
    final val = _extractPayload(json);

    int minutes = _extractInt(val['sedentaryMinutesSum'] ??
        val['sedentaryMinutes'] ??
        val['minutes']);
    if (minutes == 0 && val['interval'] is Map) {
      final start =
          DateTime.tryParse(val['interval']['startTime']?.toString() ?? '');
      final end =
          DateTime.tryParse(val['interval']['endTime']?.toString() ?? '');
      if (start != null && end != null) {
        minutes = end.difference(start).inMinutes;
      }
    }

    return GoogleHealthSedentaryPeriodData(
      date: date,
      sedentaryMinutesSum: minutes,
    );
  }
}

class GoogleHealthRestingHeartRateData {
  const GoogleHealthRestingHeartRateData({
    required this.date,
    required this.bpm,
  });

  final String date;
  final int bpm;

  factory GoogleHealthRestingHeartRateData.fromJson(Map<String, dynamic> json) {
    final date = _extractDate(json);
    final val = _extractPayload(json);

    return GoogleHealthRestingHeartRateData(
      date: date,
      bpm: _extractInt(val['bpm'] ??
          val['restingBpm'] ??
          val['averageBpm'] ??
          val['heartRate'] ??
          val),
    );
  }
}

class GoogleHealthHrvData {
  const GoogleHealthHrvData({
    required this.date,
    required this.rmssd,
  });

  final String date;
  final double rmssd;

  factory GoogleHealthHrvData.fromJson(Map<String, dynamic> json) {
    final date = _extractDate(json);
    final val = _extractPayload(json);

    return GoogleHealthHrvData(
      date: date,
      rmssd: _extractDouble(val['rmssd'] ?? val['score'] ?? val) ?? 0.0,
    );
  }
}

class GoogleHealthSleepData {
  const GoogleHealthSleepData({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.awakeMinutes,
    this.lightMinutes,
    this.deepMinutes,
    this.remMinutes,
    this.sleepScore,
    this.source,
  });

  final String date;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final int? awakeMinutes;
  final int? lightMinutes;
  final int? deepMinutes;
  final int? remMinutes;
  final int? sleepScore;
  final String? source;

  factory GoogleHealthSleepData.fromJson(Map<String, dynamic> json) {
    final date = _extractDate(json);
    final val = _extractPayload(json);

    final interval = val['interval'] is Map ? val['interval'] as Map : null;
    final startStr = (interval?['startTime'] ?? json['startTime']) as String?;
    final endStr = (interval?['endTime'] ?? json['endTime']) as String?;

    final start = DateTime.tryParse(startStr ?? '') ?? DateTime.now();
    final end = DateTime.tryParse(endStr ?? '') ?? DateTime.now();
    final duration = (json['durationMinutes'] as num?)?.toInt() ??
        end.difference(start).inMinutes;

    return GoogleHealthSleepData(
      date: date.isNotEmpty ? date : DateFormat('yyyy-MM-dd').format(start),
      startTime: start,
      endTime: end,
      durationMinutes: duration,
      awakeMinutes: (val['awakeMinutes'] as num?)?.toInt(),
      lightMinutes: (val['lightMinutes'] as num?)?.toInt(),
      deepMinutes: (val['deepMinutes'] as num?)?.toInt(),
      remMinutes: (val['remMinutes'] as num?)?.toInt(),
      sleepScore: (val['sleepScore'] as num?)?.toInt() ??
          (val['score'] as num?)?.toInt(),
      source: json['dataSourceFamily'] as String?,
    );
  }
}

class GoogleHealthOxygenSaturationData {
  const GoogleHealthOxygenSaturationData({
    required this.date,
    required this.percentage,
  });

  final String date;
  final double percentage;

  factory GoogleHealthOxygenSaturationData.fromJson(Map<String, dynamic> json) {
    final date = _extractDate(json);
    final val = _extractPayload(json);

    return GoogleHealthOxygenSaturationData(
      date: date,
      percentage: (val['percentage'] as num?)?.toDouble() ??
          (val['spo2'] as num?)?.toDouble() ??
          (val['value'] as num?)?.toDouble() ??
          0.0,
    );
  }
}

class GoogleHealthBreathingRateData {
  const GoogleHealthBreathingRateData({
    required this.date,
    required this.breathsPerMinute,
  });

  final String date;
  final double breathsPerMinute;

  factory GoogleHealthBreathingRateData.fromJson(Map<String, dynamic> json) {
    final date = _extractDate(json);
    final val = _extractPayload(json);

    return GoogleHealthBreathingRateData(
      date: date,
      breathsPerMinute: (val['breathsPerMinute'] as num?)?.toDouble() ??
          (val['rate'] as num?)?.toDouble() ??
          0.0,
    );
  }
}

class GoogleHealthSkinTemperatureData {
  const GoogleHealthSkinTemperatureData({
    required this.date,
    required this.deviationCelsius,
  });

  final String date;
  final double deviationCelsius;

  factory GoogleHealthSkinTemperatureData.fromJson(Map<String, dynamic> json) {
    final date = _extractDate(json);
    final val = _extractPayload(json);

    return GoogleHealthSkinTemperatureData(
      date: date,
      deviationCelsius: (val['deviationCelsius'] as num?)?.toDouble() ??
          (val['deviation'] as num?)?.toDouble() ??
          0.0,
    );
  }
}

class GoogleHealthElectrocardiogramData {
  const GoogleHealthElectrocardiogramData({
    required this.timestamp,
    required this.classification,
    this.averageHeartRateBpm,
  });

  final DateTime timestamp;
  final String classification;
  final int? averageHeartRateBpm;

  factory GoogleHealthElectrocardiogramData.fromJson(
      Map<String, dynamic> json) {
    return GoogleHealthElectrocardiogramData(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      classification: json['classification'] as String? ?? 'NORMAL',
      averageHeartRateBpm: (json['averageHeartRateBpm'] as num?)?.toInt(),
    );
  }
}

class GoogleHealthIrregularRhythmNotificationData {
  const GoogleHealthIrregularRhythmNotificationData({
    required this.timestamp,
    required this.eventDescription,
  });

  final DateTime timestamp;
  final String eventDescription;

  factory GoogleHealthIrregularRhythmNotificationData.fromJson(
      Map<String, dynamic> json) {
    return GoogleHealthIrregularRhythmNotificationData(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      eventDescription:
          json['eventDescription'] as String? ?? 'Irregular rhythm detected',
    );
  }
}

class GoogleHealthProfileData {
  const GoogleHealthProfileData({
    this.id,
    this.displayName,
    this.email,
    this.locale,
    this.timeZone,
    this.unitPreferences,
  });

  final String? id;
  final String? displayName;
  final String? email;
  final String? locale;
  final String? timeZone;
  final Map<String, dynamic>? unitPreferences;

  factory GoogleHealthProfileData.fromJson(Map<String, dynamic> json) {
    return GoogleHealthProfileData(
      id: json['id'] as String? ?? json['userId'] as String?,
      displayName: json['displayName'] as String? ?? json['name'] as String?,
      email: json['email'] as String?,
      locale: json['locale'] as String?,
      timeZone: json['timeZone'] as String?,
      unitPreferences: json['unitPreferences'] as Map<String, dynamic>?,
    );
  }
}

class GoogleHealthPairedDeviceData {
  const GoogleHealthPairedDeviceData({
    required this.deviceId,
    required this.model,
    required this.manufacturer,
    this.lastSyncTime,
    this.batteryLevel,
  });

  final String deviceId;
  final String model;
  final String manufacturer;
  final DateTime? lastSyncTime;
  final String? batteryLevel;

  factory GoogleHealthPairedDeviceData.fromJson(Map<String, dynamic> json) {
    return GoogleHealthPairedDeviceData(
      deviceId: json['deviceId'] as String? ?? json['id'] as String? ?? '',
      model: json['model'] as String? ?? 'Fitbit Device',
      manufacturer: json['manufacturer'] as String? ?? 'Google / Fitbit',
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'] as String)
          : null,
      batteryLevel: json['batteryLevel'] as String?,
    );
  }
}

// =============================================================================
// 5. TYPED DATA MANAGERS (<Name>DataManager)
// =============================================================================

class GoogleHealthStepsDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthStepsData> {
  GoogleHealthStepsDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthStepsData>> fetch(
      GoogleHealthAPIURL url) async {
    final rawItems = await fetchAllPages(url);
    final items = rawItems
        .map(GoogleHealthStepsData.fromJson)
        .where((e) => e.date.isNotEmpty)
        .toList();

    return GoogleHealthResult(
      data: items,
    );
  }
}

class GoogleHealthActiveMinutesDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthActiveMinutesData> {
  GoogleHealthActiveMinutesDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthActiveMinutesData>> fetch(
      GoogleHealthAPIURL url) async {
    final rawItems = await fetchAllPages(url);
    final items = rawItems
        .map(GoogleHealthActiveMinutesData.fromJson)
        .where((e) => e.date.isNotEmpty)
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthSedentaryPeriodDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthSedentaryPeriodData> {
  GoogleHealthSedentaryPeriodDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthSedentaryPeriodData>> fetch(
      GoogleHealthAPIURL url) async {
    final rawItems = await fetchAllPages(url);
    final items = rawItems
        .map(GoogleHealthSedentaryPeriodData.fromJson)
        .where((e) => e.date.isNotEmpty)
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthRestingHeartRateDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthRestingHeartRateData> {
  GoogleHealthRestingHeartRateDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthRestingHeartRateData>> fetch(
      GoogleHealthAPIURL url) async {
    final rawItems = await fetchAllPages(url);
    final items = rawItems
        .map(GoogleHealthRestingHeartRateData.fromJson)
        .where((e) => e.date.isNotEmpty)
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthHrvDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthHrvData> {
  GoogleHealthHrvDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthHrvData>> fetch(
      GoogleHealthAPIURL url) async {
    final rawItems = await fetchAllPages(url);
    final items = rawItems
        .map(GoogleHealthHrvData.fromJson)
        .where((e) => e.date.isNotEmpty)
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthSleepDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthSleepData> {
  GoogleHealthSleepDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthSleepData>> fetch(
      GoogleHealthAPIURL url) async {
    final rawItems = await fetchAllPages(url);
    final items = rawItems
        .map(GoogleHealthSleepData.fromJson)
        .where((e) => e.date.isNotEmpty)
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthOxygenSaturationDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthOxygenSaturationData> {
  GoogleHealthOxygenSaturationDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthOxygenSaturationData>> fetch(
      GoogleHealthAPIURL url) async {
    final rawItems = await fetchAllPages(url);
    final items = rawItems
        .map(GoogleHealthOxygenSaturationData.fromJson)
        .where((e) => e.date.isNotEmpty)
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthBreathingRateDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthBreathingRateData> {
  GoogleHealthBreathingRateDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthBreathingRateData>> fetch(
      GoogleHealthAPIURL url) async {
    final rawItems = await fetchAllPages(url);
    final items = rawItems
        .map(GoogleHealthBreathingRateData.fromJson)
        .where((e) => e.date.isNotEmpty)
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthSkinTemperatureDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthSkinTemperatureData> {
  GoogleHealthSkinTemperatureDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthSkinTemperatureData>> fetch(
      GoogleHealthAPIURL url) async {
    final rawItems = await fetchAllPages(url);
    final items = rawItems
        .map(GoogleHealthSkinTemperatureData.fromJson)
        .where((e) => e.date.isNotEmpty)
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthElectrocardiogramDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthElectrocardiogramData> {
  GoogleHealthElectrocardiogramDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthElectrocardiogramData>> fetch(
      GoogleHealthAPIURL url) async {
    final json = await executeRequest(url);
    final items = (json['records'] as List<dynamic>? ??
            json['dataPoints'] as List<dynamic>? ??
            [json])
        .map((e) => GoogleHealthElectrocardiogramData.fromJson(
            e as Map<String, dynamic>))
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthIrregularRhythmNotificationDataManager
    extends BaseGoogleHealthDataManager<
        GoogleHealthIrregularRhythmNotificationData> {
  GoogleHealthIrregularRhythmNotificationDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthIrregularRhythmNotificationData>> fetch(
      GoogleHealthAPIURL url) async {
    final json = await executeRequest(url);
    final items = (json['notifications'] as List<dynamic>? ??
            json['dataPoints'] as List<dynamic>? ??
            [json])
        .map((e) => GoogleHealthIrregularRhythmNotificationData.fromJson(
            e as Map<String, dynamic>))
        .toList();

    return GoogleHealthResult(data: items);
  }
}

class GoogleHealthProfileDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthProfileData> {
  GoogleHealthProfileDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthProfileData>> fetch(
      GoogleHealthAPIURL url) async {
    final json = await executeRequest(url);
    return GoogleHealthResult(
      data: [GoogleHealthProfileData.fromJson(json)],
    );
  }
}

class GoogleHealthPairedDeviceDataManager
    extends BaseGoogleHealthDataManager<GoogleHealthPairedDeviceData> {
  GoogleHealthPairedDeviceDataManager({
    required super.credentials,
    super.client,
    super.clientId,
    super.clientSecret,
  });

  @override
  Future<GoogleHealthResult<GoogleHealthPairedDeviceData>> fetch(
      GoogleHealthAPIURL url) async {
    final json = await executeRequest(url);
    final items = (json['devices'] as List<dynamic>? ?? [json])
        .map((e) =>
            GoogleHealthPairedDeviceData.fromJson(e as Map<String, dynamic>))
        .toList();

    return GoogleHealthResult(data: items);
  }
}
