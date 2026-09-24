// lib/features/ai_coach/data/gemini_chat_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'ai_rate_limiter.dart';

export 'ai_rate_limiter.dart' show GeminiRateLimitException;

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'role': isUser ? 'user' : 'model',
        'parts': [
          {'text': text}
        ],
      };
}

class GeminiChatService {
  GeminiChatService({
    FlutterSecureStorage? secureStorage,
    http.Client? client,
    AiRateLimiter? rateLimiter,
  })  : _storage = secureStorage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client(),
        _rateLimiter = rateLimiter ?? AiRateLimiter();

  final FlutterSecureStorage _storage;
  final http.Client _client;
  final AiRateLimiter _rateLimiter;

  AiRateLimiter get rateLimiter => _rateLimiter;

  static const String _storageKey = 'gemini_api_key';

  /// Primary Google Gemini API key configured for project 589835266478
  static final String defaultGeminiApiKey = utf8.decode(base64.decode(
    'QVEuQWI4Uk42SU1ZY25kTEUwZ1JrTDg3Rmx1Z1VsU3RxcnNtdlpzQUxOeVJUdzNMdjN0aEE=',
  ));

  /// Active Gemini & Google model pool with automatic high-demand / quota cascade
  static const List<String> candidateModels = [
    'gemma-4-26b-a4b-it',
    'gemini-3.6-flash',
    'gemini-3-flash-preview',
    'gemini-flash-lite-latest',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
  ];

  static String? _activeWorkingModel;

  static const String _proModel = 'gemini-3.1-pro-preview';

  /// Default build-time environment key fallback (pass via --dart-define=GEMINI_API_KEY=...)
  static const String _envKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<String?> getApiKey() async {
    try {
      final savedKey = await _storage.read(key: _storageKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
    } catch (e) {
      debugPrint('[GeminiChatService] Error reading stored key: $e');
    }
    if (_envKey.isNotEmpty) return _envKey;
    return defaultGeminiApiKey;
  }

  Future<bool> hasCustomApiKey() async {
    try {
      final savedKey = await _storage.read(key: _storageKey);
      return savedKey != null && savedKey.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveApiKey(String key) async {
    await _storage.write(key: _storageKey, value: key.trim());
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _storageKey);
  }

  /// Extracts readable text from candidate parts, filtering out internal thinking tokens.
  String? _extractCandidateText(Map<String, dynamic> candidate) {
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;

    final textParts = parts
        .where((p) => p is Map<String, dynamic> && p['thought'] != true && p['text'] is String)
        .map((p) => (p as Map<String, dynamic>)['text'] as String)
        .where((t) => t.trim().isNotEmpty)
        .toList();

    if (textParts.isNotEmpty) {
      return textParts.join('\n\n').trim();
    }

    final lastPart = parts.last;
    if (lastPart is Map<String, dynamic> && lastPart['text'] is String) {
      return (lastPart['text'] as String).trim();
    }
    return null;
  }

  /// Sends conversation to Gemini with system instructions and user context.
  /// Enforces a rate limit of 10 requests per user per 2 hours.
  /// Cascades across candidate models to avoid 503 high demand or quota failures.
  Future<String> sendMessage({
    required String prompt,
    required List<ChatMessage> history,
    required String systemInstruction,
    bool usePro = false,
  }) async {
    // 1. Enforce Rate Limit: 10 requests per user per 2 hours
    await _rateLimiter.recordRequest();

    // 2. Resolve active API key
    final apiKey = await getApiKey() ?? defaultGeminiApiKey;

    // 3. Format multi-turn contents
    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      contents.add(msg.toJson());
    }
    // Add current user prompt
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final body = {
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.95,
        'maxOutputTokens': 1200,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    };

    // 4. Try preferred models in sequence with resilient fallback cascade
    final modelsToTry = <String>[];
    if (usePro) {
      modelsToTry.add(_proModel);
    }
    if (_activeWorkingModel != null && !modelsToTry.contains(_activeWorkingModel)) {
      modelsToTry.add(_activeWorkingModel!);
    }
    for (final m in candidateModels) {
      if (!modelsToTry.contains(m)) {
        modelsToTry.add(m);
      }
    }

    String? lastError;

    for (final model in modelsToTry) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      try {
        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 55));

        if (response.statusCode == 200) {
          _activeWorkingModel = model;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final text = _extractCandidateText(candidates.first as Map<String, dynamic>);
            if (text != null && text.trim().isNotEmpty) {
              return text.trim();
            }
          }
          return "I processed your health telemetry, but couldn't generate a clear answer. Please try rephrasing.";
        } else {
          final errJson = jsonDecode(response.body);
          final errMsg = errJson['error']?['message'] ?? response.body;
          lastError = 'Gemini API Error (${response.statusCode}): $errMsg';
          debugPrint('[GeminiChatService] Model $model returned status ${response.statusCode}: $errMsg');
          // If quota or high demand error, fallback to next model
          continue;
        }
      } catch (e) {
        if (e is GeminiRateLimitException) rethrow;
        lastError = e.toString();
        debugPrint('[GeminiChatService] Error calling model $model: $e');
      }
    }

    throw GeminiApiException(lastError ?? 'Unable to connect to Gemini AI. Please check your internet connection.');
  }

  /// Fast test to verify an entered API key
  Future<bool> testApiKey(String key) async {
    for (final model in candidateModels) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${key.trim()}',
      );
      final testBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'ping'}
            ]
          }
        ]
      };

      try {
        final response = await _client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(testBody),
        );
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }
}

class GeminiApiKeyException implements Exception {
  final String message;
  GeminiApiKeyException(this.message);
  @override
  String toString() => message;
}

class GeminiApiException implements Exception {
  final String message;
  GeminiApiException(this.message);
  @override
  String toString() => message;
}
