// lib/features/ai_coach/data/gemini_chat_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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
  })  : _storage = secureStorage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  final FlutterSecureStorage _storage;
  final http.Client _client;

  static const String _storageKey = 'gemini_api_key';
  static const String _defaultModel = 'gemini-3.6-flash';
  static const String _proModel = 'gemini-3.1-pro-preview';
  static const String _fallbackModel = 'gemini-3.5-flash-lite';

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
    return null;
  }

  Future<void> saveApiKey(String key) async {
    await _storage.write(key: _storageKey, value: key.trim());
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _storageKey);
  }

  /// Sends conversation to Gemini with system instructions and user context
  Future<String> sendMessage({
    required String prompt,
    required List<ChatMessage> history,
    required String systemInstruction,
    bool usePro = false,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw GeminiApiKeyException(
        'Gemini API key is not configured. Tap the key icon at the top to paste your Google Gemini API key.',
      );
    }

    final model = usePro ? _proModel : _defaultModel;
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    // Format multi-turn contents
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
        'maxOutputTokens': 1024,
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

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final firstCandidate = candidates.first as Map<String, dynamic>;
          final content = firstCandidate['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts.first['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return text.trim();
            }
          }
        }
        return "I processed your health telemetry, but couldn't generate a clear answer. Please try rephrasing.";
      } else {
        final errJson = jsonDecode(response.body);
        final errMsg = errJson['error']?['message'] ?? response.body;
        if (response.statusCode == 400 || response.statusCode == 403) {
          throw GeminiApiException('Invalid Gemini API Key or permission: $errMsg');
        } else if (response.statusCode == 429) {
          throw GeminiApiException('Rate limit exceeded. Please wait a few seconds and try again.');
        } else {
          throw GeminiApiException('Gemini API Error (${response.statusCode}): $errMsg');
        }
      }
    } catch (e) {
      if (e is GeminiApiException || e is GeminiApiKeyException) rethrow;
      throw GeminiApiException('Connection error: Unable to reach Gemini service. $e');
    }
  }

  /// Fast test to verify an entered API key
  Future<bool> testApiKey(String key) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_defaultModel:generateContent?key=${key.trim()}',
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
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
