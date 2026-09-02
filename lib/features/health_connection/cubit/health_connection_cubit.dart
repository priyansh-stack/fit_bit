// lib/features/health_connection/cubit/health_connection_cubit.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/app_exception.dart';
import '../data/health_connection_repository.dart';
import 'health_connection_state.dart';

export 'health_connection_state.dart';

class HealthConnectionCubit extends Cubit<HealthConnectionState> {
  HealthConnectionCubit({
    required HealthConnectionRepository repository,
  })  : _repository = repository,
        super(const HealthConnectionState()) {
    _connectionSub = _repository.watchConnection().listen(
      (connection) {
        emit(state.copyWith(
          connection: () => connection,
          isLoading: false,
        ));
      },
      onError: (e) {
        emit(state.copyWith(
          errorMessage: () => e.toString(),
          isLoading: false,
        ));
      },
    );
  }

  final HealthConnectionRepository _repository;
  StreamSubscription? _connectionSub;

  Future<void> connectToGoogleHealth() async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    try {
      await _repository.startOAuthFlow();
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.toString()));
    }
  }

  Future<void> handleOAuthCallback(Uri uri) async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    try {
      await _repository.handleOAuthRedirect(uri);
      emit(state.copyWith(isLoading: false));
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.toString()));
    }
  }

  Future<void> syncHealthData({bool fullHistory = false}) async {
    emit(state.copyWith(
      isSyncing: true,
      syncMessage: () => 'Syncing…',
      syncSuccess: false,
      errorMessage: () => null,
    ));

    try {
      final result = await _repository.syncHealthData(fullHistory: fullHistory);
      final count = result['recordsWritten'] ?? 0;
      emit(state.copyWith(
        isSyncing: false,
        syncSuccess: true,
        syncMessage: () => 'Sync complete · $count records updated',
      ));
    } on TokenRevokedException {
      emit(state.copyWith(
        isSyncing: false,
        syncSuccess: false,
        syncMessage: () => null,
        errorMessage: () =>
            'Your Google Health access was revoked. Please reconnect.',
      ));
    } on AppException catch (e) {
      emit(state.copyWith(
        isSyncing: false,
        syncSuccess: false,
        syncMessage: () => null,
        errorMessage: () => e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSyncing: false,
        syncSuccess: false,
        syncMessage: () => null,
        errorMessage: () => e.toString(),
      ));
    }
  }

  Future<void> disconnect() async {
    emit(state.copyWith(isDisconnecting: true, errorMessage: () => null));
    try {
      await _repository.disconnectGoogleHealth();
      emit(state.copyWith(
        connection: () => null,
        isDisconnecting: false,
        syncMessage: () => 'Disconnected successfully',
      ));
    } on AppException catch (e) {
      emit(state.copyWith(
          isDisconnecting: false, errorMessage: () => e.message));
    } catch (e) {
      emit(state.copyWith(
          isDisconnecting: false, errorMessage: () => e.toString()));
    }
  }

  Future<void> clearAllData() async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    try {
      await _repository.clearAllHealthData();
      emit(state.copyWith(
        isLoading: false,
        syncMessage: () => 'All Firestore data cleared',
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.toString()));
    }
  }

  void clearMessage() {
    emit(state.copyWith(
      syncMessage: () => null,
      errorMessage: () => null,
    ));
  }

  @override
  Future<void> close() {
    _connectionSub?.cancel();
    return super.close();
  }
}
