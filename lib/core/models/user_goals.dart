import 'package:equatable/equatable.dart';

/// Represents user-configured daily health targets.
class UserGoals extends Equatable {
  final int stepGoal;
  final int calorieGoal;
  final double sleepHoursGoal;
  final int activeMinutesGoal;

  const UserGoals({
    this.stepGoal = 10000,
    this.calorieGoal = 2000,
    this.sleepHoursGoal = 8.0,
    this.activeMinutesGoal = 30,
  });

  /// Default standard recommended goals.
  static const UserGoals defaultGoals = UserGoals();

  UserGoals copyWith({
    int? stepGoal,
    int? calorieGoal,
    double? sleepHoursGoal,
    int? activeMinutesGoal,
  }) {
    return UserGoals(
      stepGoal: stepGoal ?? this.stepGoal,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      sleepHoursGoal: sleepHoursGoal ?? this.sleepHoursGoal,
      activeMinutesGoal: activeMinutesGoal ?? this.activeMinutesGoal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepGoal': stepGoal,
      'calorieGoal': calorieGoal,
      'sleepHoursGoal': sleepHoursGoal,
      'activeMinutesGoal': activeMinutesGoal,
    };
  }

  factory UserGoals.fromJson(Map<String, dynamic> json) {
    return UserGoals(
      stepGoal: (json['stepGoal'] as num?)?.toInt() ?? 10000,
      calorieGoal: (json['calorieGoal'] as num?)?.toInt() ?? 2000,
      sleepHoursGoal: (json['sleepHoursGoal'] as num?)?.toDouble() ?? 8.0,
      activeMinutesGoal: (json['activeMinutesGoal'] as num?)?.toInt() ?? 30,
    );
  }

  @override
  List<Object?> get props => [
        stepGoal,
        calorieGoal,
        sleepHoursGoal,
        activeMinutesGoal,
      ];
}
