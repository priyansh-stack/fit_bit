// lib/features/heart/cubit/heart_state.dart

import 'package:equatable/equatable.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/models/heart_rate_record.dart';

class HeartState extends Equatable {
  const HeartState({
    this.daily = const [],
    this.recentHR = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  final List<HealthDaily> daily;
  final List<HeartRateRecord> recentHR;
  final bool isLoading;
  final String? errorMessage;

  HeartState copyWith({
    List<HealthDaily>? daily,
    List<HeartRateRecord>? recentHR,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return HeartState(
      daily: daily ?? this.daily,
      recentHR: recentHR ?? this.recentHR,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [daily, recentHR, isLoading, errorMessage];
}
