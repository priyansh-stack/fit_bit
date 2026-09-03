import 'package:equatable/equatable.dart';
import '../../../core/models/user_goals.dart';

abstract class GoalsState extends Equatable {
  const GoalsState();

  @override
  List<Object?> get props => [];
}

class GoalsInitial extends GoalsState {
  const GoalsInitial();
}

class GoalsLoading extends GoalsState {
  const GoalsLoading();
}

class GoalsLoaded extends GoalsState {
  final UserGoals goals;

  const GoalsLoaded(this.goals);

  @override
  List<Object?> get props => [goals];
}

class GoalsError extends GoalsState {
  final String message;

  const GoalsError(this.message);

  @override
  List<Object?> get props => [message];
}
