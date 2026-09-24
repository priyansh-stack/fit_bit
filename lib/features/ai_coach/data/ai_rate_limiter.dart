// lib/features/ai_coach/data/ai_rate_limiter.dart

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GeminiRateLimitException implements Exception {
  final String message;
  final int remainingMinutes;

  const GeminiRateLimitException(this.message, {required this.remainingMinutes});

  @override
  String toString() => message;
}

/// Enforces a rate limit of maximum 10 Gemini requests per user in a rolling 2-hour window.
class AiRateLimiter {
  static const int maxRequests = 10;
  static const Duration windowDuration = Duration(hours: 2);
  static const String _storagePrefix = 'ai_coach_rate_limit_';

  final FlutterSecureStorage _storage;

  AiRateLimiter([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  String _getUserKey() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid.isNotEmpty) {
        return '$_storagePrefix${user.uid}';
      }
    } catch (_) {}
    return '${_storagePrefix}guest';
  }

  /// Verifies if user has available quota within the 10 requests / 2 hours limit.
  /// Throws [GeminiRateLimitException] if quota is exceeded.
  Future<void> recordRequest() async {
    final key = _getUserKey();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - windowDuration.inMilliseconds;

    List<int> timestamps = [];
    try {
      final raw = await _storage.read(key: key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        timestamps = decoded.map((e) => (e as num).toInt()).toList();
      }
    } catch (e) {
      debugPrint('[AiRateLimiter] Error reading timestamps: $e');
    }

    // Retain only requests within the last 2 hours
    timestamps = timestamps.where((t) => t > cutoff).toList();
    timestamps.sort();

    if (timestamps.length >= maxRequests) {
      final oldest = timestamps.first;
      final resetMs = oldest + windowDuration.inMilliseconds;
      final remainingMs = resetMs - now;
      final remainingMinutes = remainingMs > 0 ? (remainingMs / 60000).ceil() : 1;

      throw GeminiRateLimitException(
        'Rate limit reached: You can make up to $maxRequests queries every 2 hours. Please try again in $remainingMinutes minute(s).',
        remainingMinutes: remainingMinutes,
      );
    }

    timestamps.add(now);
    await _storage.write(key: key, value: jsonEncode(timestamps));
  }

  /// Returns the number of queries remaining in the current 2-hour window.
  Future<int> getRemainingQuota() async {
    final key = _getUserKey();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - windowDuration.inMilliseconds;

    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return maxRequests;

      final decoded = jsonDecode(raw) as List<dynamic>;
      final active = decoded.map((e) => (e as num).toInt()).where((t) => t > cutoff).toList();
      final remaining = maxRequests - active.length;
      return remaining < 0 ? 0 : remaining;
    } catch (_) {
      return maxRequests;
    }
  }
}
