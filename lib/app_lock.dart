import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'brand.dart';

/// MaterialApp's navigator — used to close open screens when logging out
/// from the lock screen.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Fingerprint/Face lock setting — separate per user on this phone.
class AppLockSettings {
  static String _key(String uid) => 'app_lock_enabled_$uid';

  static Future<bool> isEnabled() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(uid)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(uid), enabled);
  }

  /// Whether the phone has a fingerprint/face/PIN lock
  static Future<bool> isDeviceSupported() async {
    try {
      return await LocalAuthentication().isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Asks for fingerprint/face (or the phone PIN). True if it passes.
  static Future<bool> authenticate(String reason) async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Asks for a fingerprint when the app opens and after more than 30 seconds
/// in the background (if the user turned this on in Profile).
class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  static const Duration _relockAfter = Duration(seconds: 30);

  // Keep the screen covered until the first decision on app start
  bool _checking = true;
  bool _locked = false;
  bool _authInProgress = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Only the first auth event = cold start. No lock on later fresh logins.
    FirebaseAuth.instance.authStateChanges().first.then((user) async {
      if (user != null) await _lockIfEnabled();
      if (mounted) setState(() => _checking = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authInProgress) return; // the fingerprint dialog itself changes the lifecycle
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && DateTime.now().difference(since) >= _relockAfter) {
        _lockIfEnabled();
      }
    }
  }

  Future<void> _lockIfEnabled() async {
    if (FirebaseAuth.instance.currentUser == null || _locked) return;
    if (!await AppLockSettings.isEnabled()) return;
    if (!mounted) return;
    setState(() => _locked = true);
    await _unlock();
  }

  Future<void> _unlock() async {
    if (_authInProgress) return;
    _authInProgress = true;
    final ok = await AppLockSettings.authenticate('Unlock Vistas');
    _authInProgress = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_checking)
          const Positioned.fill(child: ColoredBox(color: AppColors.appBackground)),
        if (_locked)
          Positioned.fill(
            child: Material(
              color: AppColors.appBackground,
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(BrandAssets.logoCircle, height: 88, width: 88),
                        const SizedBox(height: 20),
                        Semantics(
                          label: BrandAssets.appName,
                          child: Image.asset(BrandAssets.wordmarkDark, height: 34),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'App is locked',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _unlock,
                            icon: const Icon(Icons.fingerprint, color: Colors.white),
                            label: const Text(
                              'Unlock',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.appPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _logout,
                          child: Text('Logout', style: TextStyle(color: Colors.grey[700])),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
