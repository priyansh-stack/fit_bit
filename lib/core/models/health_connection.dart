// lib/core/models/health_connection.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ConnectionStatus { active, disconnected, error, pending }

ConnectionStatus connectionStatusFromString(String? s) {
  switch (s) {
    case 'active':
      return ConnectionStatus.active;
    case 'disconnected':
      return ConnectionStatus.disconnected;
    case 'error':
      return ConnectionStatus.error;
    case 'pending':
      return ConnectionStatus.pending;
    default:
      return ConnectionStatus.disconnected;
  }
}

/// Stored in users/{uid}/connections/{connectionId}.
class HealthConnection {
  const HealthConnection({
    required this.id,
    required this.status,
    required this.provider,
    this.healthUserId,
    this.displayName,
    this.connectedAt,
    this.lastSyncAt,
    this.errorMessage,
  });

  final String id;
  final ConnectionStatus status;
  final String provider; // 'google_health'
  final String? healthUserId; // Google Health user ID
  final String? displayName;
  final DateTime? connectedAt;
  final DateTime? lastSyncAt;
  final String? errorMessage;

  bool get isActive => status == ConnectionStatus.active;
  bool get isDisconnected => status == ConnectionStatus.disconnected;

  factory HealthConnection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthConnection(
      id: doc.id,
      status: connectionStatusFromString(data['status'] as String?),
      provider: data['provider'] as String? ?? 'google_health',
      healthUserId: data['healthUserId'] as String?,
      displayName: data['displayName'] as String?,
      connectedAt: (data['connectedAt'] as Timestamp?)?.toDate(),
      lastSyncAt: (data['lastSyncAt'] as Timestamp?)?.toDate(),
      errorMessage: data['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'provider': provider,
        if (healthUserId != null) 'healthUserId': healthUserId,
        if (displayName != null) 'displayName': displayName,
        if (connectedAt != null)
          'connectedAt': Timestamp.fromDate(connectedAt!),
        if (lastSyncAt != null) 'lastSyncAt': Timestamp.fromDate(lastSyncAt!),
        if (errorMessage != null) 'errorMessage': errorMessage,
      };
}
