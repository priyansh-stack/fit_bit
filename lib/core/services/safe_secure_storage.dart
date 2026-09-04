// lib/core/services/safe_secure_storage.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Resilient wrapper around [FlutterSecureStorage].
/// Handles Android KeyStore BadPaddingException (BAD_DECRYPT) when apps are reinstalled
/// or restored from Google Cloud Backup with mismatched hardware keys.
class SafeSecureStorage {
  const SafeSecureStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
  );

  /// Safely reads a value by [key].
  /// Returns null if key is missing or cannot be read, without wiping the store.
  static Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[SafeSecureStorage] Storage read warning for key $key ($e).');
      return null;
    }
  }

  /// Safely writes a [value] for [key].
  /// If an error occurs, retries once safely.
  static Future<void> write({required String key, required String? value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[SafeSecureStorage] Storage write error for key $key ($e). Retrying...');
      try {
        await _storage.write(key: key, value: value);
      } catch (retryError) {
        debugPrint('[SafeSecureStorage] Write retry failed: $retryError');
      }
    }
  }

  /// Safely deletes a specific key.
  static Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[SafeSecureStorage] Error deleting key $key ($e).');
    }
  }

  /// Wipes all secure storage keys safely.
  static Future<void> deleteAll() async {
    await _wipeCorruptedStore();
  }

  static Future<void> _wipeCorruptedStore() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[SafeSecureStorage] deleteAll failed non-fatally: $e');
    }
  }
}
