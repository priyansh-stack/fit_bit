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
      resetOnError: true,
    ),
  );

  /// Safely reads a value by [key].
  /// If the KeyStore is corrupted or threw BadPaddingException, it resets the store
  /// and returns null instead of crashing the UI with PlatformException.
  static Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[SafeSecureStorage] Corrupted storage on read ($e). Resetting secure storage...');
      await _wipeCorruptedStore();
      return null;
    }
  }

  /// Safely writes a [value] for [key].
  /// If an error occurs, it resets the store and retries writing once.
  static Future<void> write({required String key, required String? value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[SafeSecureStorage] Corrupted storage on write ($e). Resetting and retrying...');
      await _wipeCorruptedStore();
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
      debugPrint('[SafeSecureStorage] Error deleting key ($e). Resetting store...');
      await _wipeCorruptedStore();
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
