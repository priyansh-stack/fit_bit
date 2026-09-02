// lib/features/activity/cubit/activity_state.dart

import 'package:equatable/equatable.dart';
import '../../../core/models/exercise_record.dart';
import '../../../core/models/health_daily.dart';

class ActivityState extends Equatable {
  const ActivityState({
    this.history = const [],
    this.exercises = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  final List<HealthDaily> history;
  final List<ExerciseRecord> exercises;
  final bool isLoading;
  final String? errorMessage;

  ActivityState copyWith({
    List<HealthDaily>? history,
    List<ExerciseRecord>? exercises,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return ActivityState(
      history: history ?? this.history,
      exercises: exercises ?? this.exercises,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [history, exercises, isLoading, errorMessage];
}
