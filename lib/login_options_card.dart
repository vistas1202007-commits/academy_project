import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'app_lock.dart';
import 'app_colors.dart';

/// The Profile screen's "LOGIN OPTIONS" card: link a mobile number, link a
/// Google account, and turn the fingerprint lock on/off.
class LoginOptionsCard extends StatefulWidget {
  const LoginOptionsCard({super.key});

  @override
  State<LoginOptionsCard> createState() => _LoginOptionsCardState();
}

class _LoginOptionsCardState extends State<LoginOptionsCard> {
  bool _busy = false;
  bool _lockEnabled = false;
  bool _lockSupported = false;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    final enabled = await AppLockSettings.isEnabled();
    final supported = await AppLockSettings.isDeviceSupported();
    if (mounted) {
      setState(() {
        _lockEnabled = enabled;
        _lockSupported = supported;
      });
    }
  }

  UserInfo? _provider(String providerId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    for (final p in user.providerData) {
      if (p.providerId == providerId) return p;
    }
    return null;
  }

  void _showResult(String? error, String successText) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? successText),
        backgroundColor: error == null ? AppColors.appPrimary : Colors.red[700],
      ),
    );
  }

  Future<void> _linkPhone() async {
    final done = await showPhoneOtpSheet(
      context,
      title: 'Link Mobile Number',
      onVerified: linkToCurrentUser,
    );
    if (done) _showResult(null, 'Mobile number linked. You can now log in with OTP.');
    if (mounted) setState(() {});
  }

  Future<void> _linkGoogle() async {
    setState(() => _busy = true);
    String? error;
    try {
      final credential = await googleCredential();
      if (credential == null) {
        if (mounted) setState(() => _busy = false);
        return; // user cancelled
      }
      error = await linkToCurrentUser(credential);
    } catch (e) {
      error = googleErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
    _showResult(error, 'Google account linked. You can now use "Continue with Google".');
  }

  Future<void> _unlink(String providerId, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Remove $label?'),
        content: Text('You will no longer be able to log in with this $label.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    final error = await unlinkFromCurrentUser(providerId);
    if (mounted) setState(() => _busy = false);
    _showResult(error, '$label removed.');
  }

  Future<void> _toggleLock(bool enable) async {
    if (enable) {
      // Check the fingerprint once before turning on, so the user doesn't get locked out later
      final ok = await AppLockSettings.authenticate('Confirm to turn on app lock');
      if (!ok) {
        _showResult('Could not verify. App lock was not turned on.', '');
        return;
      }
    }
    await AppLockSettings.setEnabled(enable);
    if (mounted) setState(() => _lockEnabled = enable);
    _showResult(null, enable ? 'App lock turned on.' : 'App lock turned off.');
  }

  Widget _optionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.appPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _linkButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: _busy ? null : onPressed,
      child: Text(label, style: const TextStyle(color: AppColors.appAccent, fontWeight: FontWeight.w600)),
    );
  }

  Widget _removeButton(VoidCallback onPressed) {
    return TextButton(
      onPressed: _busy ? null : onPressed,
      child: Text('Remove', style: TextStyle(color: Colors.grey[700])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = _provider(PhoneAuthProvider.PROVIDER_ID);
    final google = _provider(GoogleAuthProvider.PROVIDER_ID);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LOGIN OPTIONS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.appPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const Divider(height: 20),
          _optionRow(
            icon: Icons.phone_android_outlined,
            title: 'Mobile OTP Login',
            subtitle: phone != null ? 'Linked: ${phone.phoneNumber ?? ''}' : 'Not linked',
            trailing: phone != null
                ? _removeButton(() => _unlink(PhoneAuthProvider.PROVIDER_ID, 'mobile number'))
                : _linkButton('Link', _linkPhone),
          ),
          _optionRow(
            icon: Icons.account_circle_outlined,
            title: 'Google Login',
            subtitle: google != null ? 'Linked: ${google.email ?? ''}' : 'Not linked',
            trailing: google != null
                ? _removeButton(() => _unlink(GoogleAuthProvider.PROVIDER_ID, 'Google account'))
                : _linkButton('Link', _linkGoogle),
          ),
          _optionRow(
            icon: Icons.fingerprint,
            title: 'Fingerprint / Face Lock',
            subtitle: _lockSupported
                ? 'Ask for fingerprint when the app opens'
                : 'Set up a screen lock on this phone to use this',
            trailing: Switch(
              value: _lockEnabled,
              activeThumbColor: AppColors.appPrimary,
              onChanged: (_lockSupported && !_busy) ? _toggleLock : null,
            ),
          ),
        ],
      ),
    );
  }
}
