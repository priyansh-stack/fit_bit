// lib/core/models/sync_status.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Sync checkpoint stored in users/{uid}/sync/{syncType}.
/// Tracks last successful sync per data category.
class SyncStatus {
  const SyncStatus({
    required this.syncType,
    this.lastSyncAt,
    this.lastSuccessfulDate,
    this.status,
    this.errorMessage,
    this.recordsWritten,
  });

  final String syncType; // 'activity' | 'heartRate' | 'sleep' | 'metrics'
  final DateTime? lastSyncAt;
  final String? lastSuccessfulDate; // yyyy-MM-dd, the last date synced
  final String? status; // 'success' | 'error' | 'running'
  final String? errorMessage;
  final int? recordsWritten;

  bool get isRunning => status == 'running';
  bool get hasError => status == 'error';

  factory SyncStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SyncStatus(
      syncType: doc.id,
      lastSyncAt: (data['lastSyncAt'] as Timestamp?)?.toDate(),
      lastSuccessfulDate: data['lastSuccessfulDate'] as String?,
      status: data['status'] as String?,
      errorMessage: data['errorMessage'] as String?,
      recordsWritten: (data['recordsWritten'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'syncType': syncType,
        if (lastSyncAt != null) 'lastSyncAt': Timestamp.fromDate(lastSyncAt!),
        if (lastSuccessfulDate != null)
          'lastSuccessfulDate': lastSuccessfulDate,
        if (status != null) 'status': status,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (recordsWritten != null) 'recordsWritten': recordsWritten,
      };
}
