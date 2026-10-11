import 'package:flutter/material.dart';
import 'friendly_error.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import 'auth_service.dart';
import 'app_colors.dart';
import 'aurora_background.dart';
import 'brand.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Mobile OTP and Google login; setting this to false hides both buttons
  final bool _showAltLogins = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // When Mobile/Google login fails, the app rebuilds LoginScreen;
    // the previous message is shown here
    _showNotice();
    loginNotice.addListener(_showNotice);
  }

  void _showNotice() {
    final notice = loginNotice.value;
    if (notice == null || !mounted) return;
    loginNotice.value = null;
    setState(() => _errorMessage = notice);
  }

  Future<void> _loginWithPhone() async {
    setState(() => _errorMessage = '');
    await showPhoneOtpSheet(
      context,
      title: 'Login with Mobile',
      onVerified: signInStaffWithCredential,
      errorMessage: altLoginErrorMessage,
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = '';
    });
    String? error;
    try {
      final credential = await googleCredential();
      if (credential != null) error = await signInStaffWithCredential(credential);
    } catch (e) {
      error = altLoginErrorMessage(e);
    }
    if (!mounted) return;
    setState(() {
      _isGoogleLoading = false;
      if (error != null) _errorMessage = error;
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _errorMessage = 'No profile found for this account. Contact admin.';
          _isLoading = false;
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      final data = userDoc.data()!;
      final isActive = data['isActive'] ?? true;

      if (isActive == false) {
        setState(() {
          _errorMessage = 'Your account has been deactivated. Please contact the admin.';
          _isLoading = false;
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      final role = data['role'] ?? 'trainer';
      final name = data['name'] ?? credential.user!.email ?? 'User';

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(role: role, name: name),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Email login failed: $e');
      setState(() => _errorMessage = _signInErrorMessage(e.code));
    } catch (e) {
      debugPrint('Email login failed: $e');
      setState(() => _errorMessage = friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Email login errors. User-not-found and wrong-password share one
  /// message, so nobody can guess emails.
  String _signInErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been deactivated. Contact your Admin.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network problem. Please check your connection.';
      default:
        return 'Could not sign in. Please try again.';
    }
  }

  static const String _resetSentMessage = 'If an account exists for this email, a reset link has been sent.';
  static const String _networkMessage = 'Network problem. Please check your connection and try again.';

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isSending = false;
    String dialogMessage = '';
    bool isError = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reset Password',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.appPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your email address. We will send you a link to reset your password.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.appPrimary),
                        filled: true,
                        fillColor: AppColors.appBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (dialogMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isError ? Colors.red[50] : AppColors.appPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dialogMessage,
                          style: TextStyle(
                            color: isError ? Colors.red[700] : AppColors.appPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSending
                                ? null
                                : () async {
                              final email = resetEmailController.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                setDialogState(() {
                                  dialogMessage = 'Please enter a valid email address.';
                                  isError = true;
                                });
                                return;
                              }
                              setDialogState(() {
                                isSending = true;
                                dialogMessage = '';
                              });
                              try {
                                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                                setDialogState(() {
                                  isSending = false;
                                  isError = false;
                                  dialogMessage = _resetSentMessage;
                                });
                              } on FirebaseAuthException catch (e) {
                                debugPrint('Password reset failed: $e');
                                // Same reply whether or not the account exists, so nobody can guess emails
                                final message = switch (e.code) {
                                  'invalid-email' => 'Please enter a valid email address.',
                                  'network-request-failed' => _networkMessage,
                                  _ => null,
                                };
                                setDialogState(() {
                                  isSending = false;
                                  isError = message != null;
                                  dialogMessage = message ?? _resetSentMessage;
                                });
                              } catch (e) {
                                debugPrint('Password reset failed: $e');
                                final isNetwork = friendlyError(e) == _networkMessage;
                                setDialogState(() {
                                  isSending = false;
                                  isError = isNetwork;
                                  dialogMessage = isNetwork ? _networkMessage : _resetSentMessage;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.appPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: isSending
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                                : const Text('Send Link', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    loginNotice.removeListener(_showNotice);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || _isGoogleLoading;
    return FullBleed(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // Behind the Scaffold so the aurora doesn't shrink when the keyboard opens
            const Positioned.fill(child: AuroraBackground()),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(BrandAssets.mountainGlyph, height: 52, filterQuality: FilterQuality.medium),
                          const SizedBox(height: 10),
                          Semantics(
                            label: BrandAssets.appName,
                            child: Image.asset(
                              BrandAssets.wordmarkLight,
                              height: 34,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            BrandAssets.tagline,
                            style: TextStyle(fontSize: 13, color: _LoginColors.muted, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 22),
                          _buildCard(busy),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(bool busy) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      decoration: BoxDecoration(
        color: _LoginColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.aurora,
            decoration: _fieldDecoration('Email', Icons.email_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) {
              if (!busy) _login();
            },
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.aurora,
            decoration: _fieldDecoration('Password', Icons.lock_outline),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
              ),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: _LoginColors.errorText, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: busy ? null : _login,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.aurora,
                foregroundColor: AppColors.night,
                disabledBackgroundColor: AppColors.aurora.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: AppColors.night, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Login',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _showForgotPasswordDialog,
            style: TextButton.styleFrom(foregroundColor: _LoginColors.muted),
            child: const Text('Forgot password?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          if (_showAltLogins) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('OR', style: TextStyle(color: _LoginColors.muted, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
              ],
            ),
            const SizedBox(height: 12),
            _altButton(
              onPressed: busy ? null : _loginWithPhone,
              icon: const Icon(Icons.phone_android_outlined, size: 20),
              label: 'Login with Mobile OTP',
            ),
            const SizedBox(height: 10),
            _altButton(
              onPressed: busy ? null : _loginWithGoogle,
              icon: _isGoogleLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.aurora),
                    )
                  : const Icon(Icons.account_circle_outlined, size: 20),
              label: 'Continue with Google',
            ),
            const SizedBox(height: 10),
            const Text(
              'Mobile and Google login work after you link them from My Profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: _LoginColors.faint),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _LoginColors.muted),
      prefixIcon: Icon(icon, color: _LoginColors.muted, size: 20),
      filled: true,
      fillColor: _LoginColors.field,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: border(Colors.white.withValues(alpha: 0.08)),
      enabledBorder: border(Colors.white.withValues(alpha: 0.08)),
      focusedBorder: border(AppColors.aurora, 1.5),
    );
  }

  Widget _altButton({required VoidCallback? onPressed, required Widget icon, required String label}) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDDF2EE),
          disabledForegroundColor: _LoginColors.faint,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Colors for the dark login card only
class _LoginColors {
  _LoginColors._();

  static const Color card = Color(0xD90B2228);
  static const Color field = Color(0x14FFFFFF);
  static const Color muted = Color(0xFF9DBFBB);
  static const Color faint = Color(0xFF6E8E8B);
  static const Color errorText = Color(0xFFF2B8B0);
}
