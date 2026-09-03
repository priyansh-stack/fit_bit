// lib/features/health_connection/presentation/connect_screen.dart

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/constants/oauth_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../data/health_connection_repository.dart';

/// The "Connect Fitbit" screen shown once authenticated.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _isConnecting = false;
  String? _errorMessage;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _listenForOAuthCallback();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Listens for the OAuth redirect deep link.
  void _listenForOAuthCallback() {
    // 1. Listen for background/foreground deep links
    _linkSubscription = _appLinks.uriLinkStream.listen(_processOAuthUri);

    // 2. Check for initial link if activity was created by redirect
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _processOAuthUri(uri);
      }
    });
  }

  Future<void> _processOAuthUri(Uri uri) async {
    debugPrint('Received OAuth callback URI: $uri');
    if (uri.scheme.startsWith('com.googleusercontent.apps') ||
        uri.scheme == 'com.example.fitbithealth' ||
        uri.scheme == 'com.healthdash.fitbitdash') {
      if (!mounted) return;
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
      });

      try {
        final repo = context.read<HealthConnectionRepository>();
        await repo.handleOAuthRedirect(uri);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected to Google Health & Fitbit!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.go(AppRoute.home);
        }
      } on AppException catch (e) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _errorMessage = e.message;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _errorMessage = 'Failed to complete authorization: $e';
          });
        }
      }
    }
  }

  Future<void> _connect() async {
    final secret = await OAuthConstants.resolveClientSecret();
    if (secret.isEmpty) {
      if (!mounted) return;
      final entered = await _showClientSecretDialog(context);
      if (entered == null || entered.trim().isEmpty) {
        setState(() {
          _isConnecting = false;
          _errorMessage =
              'Google OAuth Client Secret is required to exchange tokens with Google Cloud.';
        });
        return;
      }
      await OAuthConstants.saveClientSecret(entered.trim());
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    if (!mounted) return;
    try {
      final repo = context.read<HealthConnectionRepository>();
      await repo.startOAuthFlow();
    } on OAuthCancelledException {
      setState(() {
        _isConnecting = false;
        _errorMessage = null;
      });
    } on AppException catch (e) {
      setState(() {
        _isConnecting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _errorMessage = 'Connection failed: $e';
      });
    }
  }

  Future<void> _openSecretConfig() async {
    final entered = await _showClientSecretDialog(context);
    if (entered != null && entered.trim().isNotEmpty) {
      await OAuthConstants.saveClientSecret(entered.trim());
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client secret saved securely! Tap Connect to proceed.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  Future<String?> _showClientSecretDialog(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ClientSecretSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row (Testing Warning & Skip)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.calorieColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  AppTheme.calorieColor.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 14, color: AppTheme.calorieColor),
                            SizedBox(width: 4),
                            Text(
                              'TESTING ONLY',
                              style: TextStyle(
                                color: AppTheme.calorieColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.key_rounded,
                                size: 18, color: Colors.white70),
                            tooltip: 'Configure Client Secret',
                            onPressed: _openSecretConfig,
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoute.home),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Fitbit / Google Health Icon
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366F1),
                            cs.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.4),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.watch_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Connect Fitbit &\nGoogle Health',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: Colors.white, height: 1.2),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Direct Google Health API v4 integration replacing the legacy Fitbit API. '
                    'All token management and syncing happen directly on your device.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Permission cards
                  const _PermissionCard(
                    icon: Icons.directions_walk_rounded,
                    color: AppTheme.stepsColor,
                    title: 'Activity & Fitness',
                    description:
                        'Steps, Active Minutes, Sedentary Periods, Distance & Calories',
                  ),
                  const SizedBox(height: 10),
                  const _PermissionCard(
                    icon: Icons.favorite_rounded,
                    color: AppTheme.heartColor,
                    title: 'Cardiovascular & Metrics',
                    description:
                        'Resting Heart Rate, HRV, SpO2, Respiratory Rate, ECG',
                  ),
                  const SizedBox(height: 10),
                  const _PermissionCard(
                    icon: Icons.bedtime_rounded,
                    color: AppTheme.sleepColor,
                    title: 'Sleep Sessions',
                    description:
                        'Sleep duration, stages (Deep, Light, REM, Awake) & sleep score',
                  ),

                  const Spacer(),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: cs.error.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: cs.error, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          if (_errorMessage!
                                  .toLowerCase()
                                  .contains('client_secret') ||
                              _errorMessage!
                                  .toLowerCase()
                                  .contains('secret')) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _openSecretConfig,
                              icon: const Icon(Icons.key_rounded, size: 16),
                              label: const Text('Configure Client Secret'),
                              style: TextButton.styleFrom(
                                foregroundColor: cs.primary,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Connect button
                  ElevatedButton(
                    onPressed: _isConnecting ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: _isConnecting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Authorizing Google Health…'),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.link_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Connect Fitbit via Google Health'),
                            ],
                          ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    OAuthConstants.testingWarningBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                          height: 1.4,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientSecretSheet extends StatefulWidget {
  const _ClientSecretSheet();

  @override
  State<_ClientSecretSheet> createState() => _ClientSecretSheetState();
}

class _ClientSecretSheetState extends State<_ClientSecretSheet> {
  late final TextEditingController _controller;
  bool _obscureText = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadInitialSecret();
  }

  Future<void> _loadInitialSecret() async {
    final secret = await OAuthConstants.resolveClientSecret();
    if (mounted) {
      setState(() {
        _controller.text = secret;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.key_rounded,
                      color: Color(0xFF818CF8), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OAuth Client Secret',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Saved securely on device keychain',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Google Health API v4 requires your OAuth client secret for token exchange. Paste your GOOGLE_CLIENT_SECRET from your .env file or Google Cloud Console:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              TextField(
                controller: _controller,
                obscureText: _obscureText,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. GOCSPX-xxxxxxxxxxxxxxxx',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white60,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_controller.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Secret & Continue',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
