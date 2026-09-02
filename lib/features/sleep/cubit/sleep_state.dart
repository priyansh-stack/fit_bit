// lib/features/sleep/cubit/sleep_state.dart

import 'package:equatable/equatable.dart';
import '../../../core/models/sleep_record.dart';

class SleepState extends Equatable {
  const SleepState({
    this.sessions = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  final List<SleepRecord> sessions;
  final bool isLoading;
  final String? errorMessage;

  SleepState copyWith({
    List<SleepRecord>? sessions,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return SleepState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [sessions, isLoading, errorMessage];
}
