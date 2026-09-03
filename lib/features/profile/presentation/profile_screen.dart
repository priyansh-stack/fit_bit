// lib/features/profile/presentation/profile_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/models/health_connection.dart';
import '../../../core/models/user_goals.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../dashboard/cubit/dashboard_cubit.dart';
import '../../goals/cubit/goals_cubit.dart';
import '../../goals/cubit/goals_state.dart';
import '../../goals/presentation/edit_goals_sheet.dart';
import '../../health_connection/cubit/health_connection_cubit.dart';
import '../../../repositories/health_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _syncNow() async {
    await context.read<HealthConnectionCubit>().syncHealthData();
    if (mounted) {
      context.read<DashboardCubit>().refresh();
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Fitbit?'),
        content: const Text(
          'Your Fitbit data will no longer be synchronized. '
          'Previously synced data will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (mounted) {
      await context.read<HealthConnectionCubit>().disconnect();
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<AuthBloc>().add(const AuthSignOutRequested());
      context.go(AppRoute.login);
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Health Data?'),
        content: const Text(
          'This will purge all cached daily and sleep documents from Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Clear', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final healthRepo = HealthRepository();
    await healthRepo.clearAllHealthData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared from Firestore')),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated
        ? authState.user
        : FirebaseAuth.instance.currentUser;
    final connState = context.watch<HealthConnectionCubit>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // User info card
          _UserCard(user: user),
          const SizedBox(height: 20),

          // Connection status
          if (connState.isLoading)
            const _LoadingCard()
          else
            _ConnectionCard(
              connection: connState.connection,
              isSyncing: connState.isSyncing,
              isDisconnecting: connState.isDisconnecting,
              syncMessage: connState.syncMessage,
              syncSuccess: connState.syncSuccess,
              errorMessage: connState.errorMessage,
              onSyncNow: _syncNow,
              onClearData: _clearData,
              onDisconnect: _disconnect,
              onConnect: () => context.go(AppRoute.connect),
            ),

          const SizedBox(height: 20),

          // Daily Goals Configuration
          const _GoalsCard(),

          const SizedBox(height: 20),

          // Sign out
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.7),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalsState = context.watch<GoalsCubit>().state;
    final goals = goalsState is GoalsLoaded
        ? goalsState.goals
        : UserGoals.defaultGoals;

    return InkWell(
      onTap: () => EditGoalsSheet.show(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: Color(0xFF6C63FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Fitness Goals',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Targets powering your dashboard',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => EditGoalsSheet.show(context),
                icon: const Icon(Icons.edit_rounded, size: 18),
                tooltip: 'Edit Goals',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GoalSummaryItem(
                  label: 'Steps',
                  value:
                      '${(goals.stepGoal / 1000).toStringAsFixed(goals.stepGoal % 1000 == 0 ? 0 : 1)}k',
                  icon: Icons.directions_walk_rounded,
                  color: const Color(0xFF6C63FF),
                ),
              ),
              Expanded(
                child: _GoalSummaryItem(
                  label: 'Calories',
                  value: '${goals.calorieGoal}',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF6584),
                ),
              ),
              Expanded(
                child: _GoalSummaryItem(
                  label: 'Sleep',
                  value: '${goals.sleepHoursGoal.toStringAsFixed(1)}h',
                  icon: Icons.bedtime_rounded,
                  color: const Color(0xFF43BCCD),
                ),
              ),
              Expanded(
                child: _GoalSummaryItem(
                  label: 'Active',
                  value: '${goals.activeMinutesGoal}m',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF00C896),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

class _GoalSummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _GoalSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage:
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
            child: user?.photoURL == null
                ? Icon(Icons.person_rounded,
                    color: Colors.white.withValues(alpha: 0.7), size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'User',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connection,
    required this.isSyncing,
    required this.isDisconnecting,
    required this.syncMessage,
    required this.syncSuccess,
    required this.errorMessage,
    required this.onSyncNow,
    required this.onClearData,
    required this.onDisconnect,
    required this.onConnect,
  });

  final HealthConnection? connection;
  final bool isSyncing;
  final bool isDisconnecting;
  final String? syncMessage;
  final bool syncSuccess;
  final String? errorMessage;
  final VoidCallback onSyncNow;
  final VoidCallback onClearData;
  final VoidCallback onDisconnect;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final isConnected = connection?.isActive ?? false;
    final statusColor = isConnected
        ? const Color(0xFF10B981)
        : Colors.white.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isConnected
                ? const Color(0xFF10B981).withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.watch_rounded, color: statusColor, size: 22),
              const SizedBox(width: 10),
              const Text('Fitbit / Google Health',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (!isConnected) ...[
            Text(
              'Your Fitbit data is no longer being synchronized.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Reconnect Fitbit'),
              ),
            ),
          ] else ...[
            // Last sync
            if (connection?.lastSyncAt != null)
              Text(
                'Last synced: ${HealthDateUtils.relativeTime(connection!.lastSyncAt!)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
              ),

            const SizedBox(height: 14),

            // Status messages
            if (syncMessage != null)
              _StatusMessage(message: syncMessage!, isSuccess: syncSuccess),
            if (errorMessage != null)
              _StatusMessage(message: errorMessage!, isSuccess: false),

            const SizedBox(height: 8),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isSyncing ? null : onSyncNow,
                    icon: isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(isSyncing ? 'Syncing…' : 'Sync Now'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  onPressed: onClearData,
                  tooltip: 'Clear All Firestore Data',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.orange),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: isDisconnecting ? null : onDisconnect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                  ),
                  child: isDisconnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFEF4444)))
                      : const Icon(Icons.link_off_rounded, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.isSuccess});
  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
