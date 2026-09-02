// lib/features/health_connection/cubit/health_connection_state.dart

import 'package:equatable/equatable.dart';
import '../../../core/models/health_connection.dart';

class HealthConnectionState extends Equatable {
  const HealthConnectionState({
    this.connection,
    this.isLoading = false,
    this.isSyncing = false,
    this.isDisconnecting = false,
    this.syncMessage,
    this.syncSuccess = false,
    this.errorMessage,
  });

  final HealthConnection? connection;
  final bool isLoading;
  final bool isSyncing;
  final bool isDisconnecting;
  final String? syncMessage;
  final bool syncSuccess;
  final String? errorMessage;

  bool get isConnected => connection?.isActive ?? false;

  HealthConnectionState copyWith({
    HealthConnection? Function()? connection,
    bool? isLoading,
    bool? isSyncing,
    bool? isDisconnecting,
    String? Function()? syncMessage,
    bool? syncSuccess,
    String? Function()? errorMessage,
  }) {
    return HealthConnectionState(
      connection: connection != null ? connection() : this.connection,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isDisconnecting: isDisconnecting ?? this.isDisconnecting,
      syncMessage: syncMessage != null ? syncMessage() : this.syncMessage,
      syncSuccess: syncSuccess ?? this.syncSuccess,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        connection,
        isLoading,
        isSyncing,
        isDisconnecting,
        syncMessage,
        syncSuccess,
        errorMessage,
      ];
}
