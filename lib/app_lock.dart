import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MaterialApp ka navigator — lock screen se logout karte waqt khule
/// screens band karne ke liye.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Fingerprint/Face lock ki setting — har user ke liye is phone pe alag.
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

  /// Phone me fingerprint/face/PIN lock hai ya nahi
  static Future<bool> isDeviceSupported() async {
    try {
      return await LocalAuthentication().isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Fingerprint/face (ya phone ka PIN) maangta hai. Pass hua to true.
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

/// App khulne par, aur 30 second se zyada background me rehne ke baad,
/// fingerprint maangta hai (agar user ne Profile se ye on kiya ho).
class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  static const Color primaryGreen = Color(0xFF1B6B4A);
  static const Duration _relockAfter = Duration(seconds: 30);

  // App start pe pehla faisla hone tak screen dhak ke rakhte hain
  bool _checking = true;
  bool _locked = false;
  bool _authInProgress = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sirf pehla auth event = app ka cold start. Baad ke fresh login pe lock nahi.
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
    if (_authInProgress) return; // fingerprint dialog khud lifecycle badalta hai
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
    final ok = await AppLockSettings.authenticate('Unlock Vistas Academy');
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
          const Positioned.fill(child: ColoredBox(color: Color(0xFFF5F7F5))),
        if (_locked)
          Positioned.fill(
            child: Material(
              color: const Color(0xFFF5F7F5),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/logo.png', height: 80, width: 80),
                        const SizedBox(height: 20),
                        const Text(
                          'Vistas Academy',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
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
                              backgroundColor: primaryGreen,
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
