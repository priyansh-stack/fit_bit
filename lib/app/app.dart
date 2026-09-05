import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/cubit/activity_cubit.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/dashboard/cubit/dashboard_cubit.dart';
import '../features/goals/cubit/goals_cubit.dart';
import '../features/health_connection/cubit/health_connection_cubit.dart';
import '../features/health_connection/data/health_connection_repository.dart';
import '../features/heart/cubit/heart_cubit.dart';
import '../features/sleep/cubit/sleep_cubit.dart';
import '../repositories/health_repository.dart';
import 'routes.dart';
import 'theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (_) => AuthRepository(),
        ),
        RepositoryProvider<HealthRepository>(
          create: (_) => HealthRepository(),
        ),
        RepositoryProvider<HealthConnectionRepository>(
          create: (context) => HealthConnectionRepository(
            healthRepository: context.read<HealthRepository>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            )..add(const AuthCheckRequested()),
          ),
          BlocProvider<GoalsCubit>(
            create: (_) => GoalsCubit(
              firestore: FirebaseFirestore.instance,
            ),
          ),
          BlocProvider<HealthConnectionCubit>(
            create: (context) => HealthConnectionCubit(
              repository: context.read<HealthConnectionRepository>(),
            ),
          ),
          BlocProvider<DashboardCubit>(
            create: (context) => DashboardCubit(
              healthRepository: context.read<HealthRepository>(),
            ),
          ),
          BlocProvider<ActivityCubit>(
            create: (_) => ActivityCubit(),
          ),
          BlocProvider<SleepCubit>(
            create: (context) => SleepCubit(
              healthRepository: context.read<HealthRepository>(),
            ),
          ),
          BlocProvider<HeartCubit>(
            create: (context) => HeartCubit(
              healthRepository: context.read<HealthRepository>(),
            ),
          ),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthBloc>();
    _router = createAppRouter(authBloc);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Health Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}
