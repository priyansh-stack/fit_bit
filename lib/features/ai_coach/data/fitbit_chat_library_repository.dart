// lib/features/ai_coach/data/fitbit_chat_library_repository.dart
//
// Per-user isolated Chat Library repository backed by Cloud Firestore with local cache.
// Allows users to view past AI consultations, resume conversations, and delete sessions.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'gemini_chat_service.dart';

class AiCoachSession {
  final String id;
  final String title;
  final String lastMessagePreview;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const AiCoachSession({
    required this.id,
    required this.title,
    required this.lastMessagePreview,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'lastMessagePreview': lastMessagePreview,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages
            .map((m) => {
                  'text': m.text,
                  'isUser': m.isUser,
                  'timestamp': m.timestamp.toIso8601String(),
                })
            .toList(),
      };

  factory AiCoachSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List? ?? [];
    return AiCoachSession(
      id: json['id'] as String? ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Health Coaching Session',
      lastMessagePreview: json['lastMessagePreview'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      messages: rawMessages
          .map((m) => ChatMessage(
                text: m['text'] as String? ?? '',
                isUser: m['isUser'] as bool? ?? false,
                timestamp: m['timestamp'] != null
                    ? DateTime.tryParse(m['timestamp'] as String) ?? DateTime.now()
                    : DateTime.now(),
              ))
          .toList(),
    );
  }
}

class FitbitChatLibraryRepository {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final FlutterSecureStorage _storage;

  FitbitChatLibraryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FlutterSecureStorage? storage,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _storage = storage ?? const FlutterSecureStorage();

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  String? get _currentUid => _auth?.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _sessionsCollection {
    final uid = _currentUid;
    final fs = _firestore;
    if (uid == null || uid.isEmpty || fs == null) return null;
    return fs.collection('users').doc(uid).collection('ai_chat_sessions');
  }

  /// Fetches all chat sessions for the current authenticated user.
  Future<List<AiCoachSession>> fetchSessions() async {
    final collection = _sessionsCollection;
    if (collection != null) {
      try {
        final snap = await collection.orderBy('updatedAt', descending: true).get();
        final sessions = snap.docs.map((d) => AiCoachSession.fromJson(d.data())).toList();
        await _cacheSessionsLocally(sessions);
        return sessions;
      } catch (e) {
        debugPrint('[FitbitChatLibrary] Firestore read failed, reading local cache: $e');
      }
    }
    return _readLocalCachedSessions();
  }

  /// Saves or updates a chat session in the user's private library.
  Future<void> saveSession(AiCoachSession session) async {
    final collection = _sessionsCollection;
    if (collection != null) {
      try {
        await collection.doc(session.id).set(session.toJson(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('[FitbitChatLibrary] Firestore save failed: $e');
      }
    }
    await _saveLocalSession(session);
  }

  /// Deletes a specific chat session from the user's private library.
  Future<void> deleteSession(String sessionId) async {
    final collection = _sessionsCollection;
    if (collection != null) {
      try {
        await collection.doc(sessionId).delete();
      } catch (e) {
        debugPrint('[FitbitChatLibrary] Firestore delete failed: $e');
      }
    }
    await _deleteLocalSession(sessionId);
  }

  // --- Local Cache Helpers ---

  String get _localCacheKey => 'fitbit_ai_sessions_${_currentUid ?? 'default'}';

  Future<void> _cacheSessionsLocally(List<AiCoachSession> sessions) async {
    try {
      final encoded = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await _storage.write(key: _localCacheKey, value: encoded);
    } catch (_) {}
  }

  Future<List<AiCoachSession>> _readLocalCachedSessions() async {
    try {
      final raw = await _storage.read(key: _localCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        return decoded
            .map((s) => AiCoachSession.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveLocalSession(AiCoachSession session) async {
    final sessions = await _readLocalCachedSessions();
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.insert(0, session);
    }
    await _cacheSessionsLocally(sessions);
  }

  Future<void> _deleteLocalSession(String sessionId) async {
    final sessions = await _readLocalCachedSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await _cacheSessionsLocally(sessions);
  }
}
