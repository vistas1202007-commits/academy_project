import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'firebase_options.dart';
import 'app_lock.dart';
import 'app_colors.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vistas',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      // Fingerprint lock poore app ke upar (Profile se on hota hai)
      builder: (context, child) => AppLock(child: child ?? const SizedBox.shrink()),
      theme: AppTheme.light,
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatelessWidget {
  const AuthCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Still checking whether a session exists
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // No logged-in user -> show Login screen
        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Keyed by uid so the profile is fetched once per user, not on every rebuild
        return _ProfileGate(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

/// Fetches the logged-in user's profile (role + name) and decides whether to
/// show the Dashboard, sign the user out, or show a retryable error.
class _ProfileGate extends StatefulWidget {
  final User user;
  const _ProfileGate({super.key, required this.user});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _profileFuture;
  bool _signOutScheduled = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchProfile() {
    return FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
  }

  void _retry() {
    setState(() => _profileFuture = _fetchProfile());
  }

  // Sign out after the current frame instead of inside build(); runs only once
  void _scheduleSignOut() {
    if (_signOutScheduled) return;
    _signOutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseAuth.instance.signOut();
    });
  }

  // Accepts bool or string values ("false", "0", "no") stored in Firestore
  static bool _parseIsActive(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    return !(text == 'false' || text == '0' || text == 'no');
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // Network / permission error -> keep the session, let the user retry
        if (profileSnapshot.hasError) {
          return _ErrorScreen(
            message: 'Profile load nahi ho payi. Internet check karke dobara try karein.',
            onRetry: _retry,
            onLogout: () => FirebaseAuth.instance.signOut(),
          );
        }

        // Profile missing -> force back to Login
        final data = profileSnapshot.data?.data();
        if (data == null) {
          _scheduleSignOut();
          return const LoginScreen();
        }

        // Account deactivated -> force back to Login
        if (!_parseIsActive(data['isActive'])) {
          _scheduleSignOut();
          return const LoginScreen();
        }

        final role = _parseString(data['role']) ?? 'trainer';
        final name = _parseString(data['name']) ?? widget.user.email ?? 'User';

        return DashboardScreen(role: role, name: name);
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Center(child: CircularProgressIndicator(color: AppColors.appPrimary)),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  const _ErrorScreen({required this.message, required this.onRetry, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: AppColors.appPrimary),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.appPrimary),
              ),
              TextButton(onPressed: onLogout, child: const Text('Logout')),
            ],
          ),
        ),
      ),
    );
  }
}