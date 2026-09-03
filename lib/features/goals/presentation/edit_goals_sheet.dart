import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/user_goals.dart';
import '../cubit/goals_cubit.dart';
import '../cubit/goals_state.dart';

class EditGoalsSheet extends StatefulWidget {
  const EditGoalsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<GoalsCubit>(),
        child: const EditGoalsSheet(),
      ),
    );
  }

  @override
  State<EditGoalsSheet> createState() => _EditGoalsSheetState();
}

class _EditGoalsSheetState extends State<EditGoalsSheet> {
  late int _stepGoal;
  late int _calorieGoal;
  late double _sleepHoursGoal;
  late int _activeMinutesGoal;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final state = context.read<GoalsCubit>().state;
      if (state is GoalsLoaded) {
        _stepGoal = state.goals.stepGoal;
        _calorieGoal = state.goals.calorieGoal;
        _sleepHoursGoal = state.goals.sleepHoursGoal;
        _activeMinutesGoal = state.goals.activeMinutesGoal;
      } else {
        _stepGoal = UserGoals.defaultGoals.stepGoal;
        _calorieGoal = UserGoals.defaultGoals.calorieGoal;
        _sleepHoursGoal = UserGoals.defaultGoals.sleepHoursGoal;
        _activeMinutesGoal = UserGoals.defaultGoals.activeMinutesGoal;
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Goals',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Set your personal daily fitness targets',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _stepGoal = UserGoals.defaultGoals.stepGoal;
                      _calorieGoal = UserGoals.defaultGoals.calorieGoal;
                      _sleepHoursGoal = UserGoals.defaultGoals.sleepHoursGoal;
                      _activeMinutesGoal = UserGoals.defaultGoals.activeMinutesGoal;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Step Goal Slider
            _buildGoalSlider(
              icon: Icons.directions_walk_rounded,
              iconColor: const Color(0xFF6C63FF),
              title: 'Daily Steps',
              valueText: '$_stepGoal steps',
              value: _stepGoal.toDouble(),
              min: 2000,
              max: 30000,
              divisions: 56, // every 500 steps
              onChanged: (v) => setState(() => _stepGoal = v.toInt()),
            ),
            const SizedBox(height: 18),

            // Calorie Goal Slider
            _buildGoalSlider(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFFF6584),
              title: 'Calories Burned',
              valueText: '$_calorieGoal kcal',
              value: _calorieGoal.toDouble(),
              min: 1000,
              max: 4500,
              divisions: 70, // every 50 kcal
              onChanged: (v) => setState(() => _calorieGoal = v.toInt()),
            ),
            const SizedBox(height: 18),

            // Sleep Target Slider
            _buildGoalSlider(
              icon: Icons.bedtime_rounded,
              iconColor: const Color(0xFF43BCCD),
              title: 'Sleep Target',
              valueText: '${_sleepHoursGoal.toStringAsFixed(1)} hours',
              value: _sleepHoursGoal,
              min: 5.0,
              max: 11.0,
              divisions: 12, // every 30 mins (0.5 hrs)
              onChanged: (v) => setState(() => _sleepHoursGoal = v),
            ),
            const SizedBox(height: 18),

            // Active Minutes Slider
            _buildGoalSlider(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFF00C896),
              title: 'Active Zone Minutes',
              valueText: '$_activeMinutesGoal mins',
              value: _activeMinutesGoal.toDouble(),
              min: 10,
              max: 120,
              divisions: 22, // every 5 mins
              onChanged: (v) => setState(() => _activeMinutesGoal = v.toInt()),
            ),
            const SizedBox(height: 28),

            // Save Button
            ElevatedButton(
              onPressed: () {
                final newGoals = UserGoals(
                  stepGoal: _stepGoal,
                  calorieGoal: _calorieGoal,
                  sleepHoursGoal: _sleepHoursGoal,
                  activeMinutesGoal: _activeMinutesGoal,
                );
                context.read<GoalsCubit>().updateGoals(newGoals);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Daily goals updated!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save Goals',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSlider({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                valueText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: iconColor,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: iconColor,
              inactiveTrackColor: iconColor.withValues(alpha: 0.2),
              thumbColor: iconColor,
              overlayColor: iconColor.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
