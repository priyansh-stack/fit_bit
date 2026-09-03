// lib/app/routes.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/health_connection/presentation/connect_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/activity/presentation/activity_screen.dart';
import '../features/sleep/presentation/sleep_screen.dart';
import '../features/heart/presentation/heart_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../shared/widgets/main_shell.dart';

// Route names
class AppRoute {
  static const String login = '/login';
  static const String connect = '/connect';
  static const String home = '/';
  static const String activity = '/activity';
  static const String sleep = '/sleep';
  static const String heart = '/heart';
  static const String profile = '/profile';
}

/// Helper to convert a Stream into a Listenable for GoRouter.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter(AuthBloc authBloc) {
  return GoRouter(
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final uriStr = state.uri.toString();
      if (uriStr.contains('oauth2redirect') ||
          state.uri.path.contains('oauth2redirect')) {
        return AppRoute.connect;
      }

      final authState = authBloc.state;
      // Do not prematurely redirect to login while checking persisted session
      if (authState is AuthInitial) {
        return null;
      }

      final isLoggedIn = authState is Authenticated;
      final isOnLogin = state.matchedLocation == AppRoute.login;

      if (!isLoggedIn && !isOnLogin) return AppRoute.login;
      if (isLoggedIn && isOnLogin) return AppRoute.home;
      return null;
    },
    onException: (context, state, router) {
      if (state.uri.toString().contains('oauth2redirect')) {
        router.go(AppRoute.connect);
      } else {
        router.go(AppRoute.home);
      }
    },
    routes: [
      GoRoute(
        path: AppRoute.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.connect,
        builder: (context, state) => const ConnectScreen(),
      ),
      GoRoute(
        path: '/oauth2redirect',
        builder: (context, state) => const ConnectScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoute.home,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoute.activity,
            builder: (context, state) => const ActivityScreen(),
          ),
          GoRoute(
            path: AppRoute.sleep,
            builder: (context, state) => const SleepScreen(),
          ),
          GoRoute(
            path: AppRoute.heart,
            builder: (context, state) => const HeartScreen(),
          ),
          GoRoute(
            path: AppRoute.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
