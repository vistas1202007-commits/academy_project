import 'dart:async';
import 'package:flutter/material.dart';
import 'friendly_error.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_colors.dart';

/// Login screen pe dikhane wala message. Mobile/Google login fail hone par
/// LoginScreen dobara banti hai, isliye message yahan rakhte hain.
final ValueNotifier<String?> loginNotice = ValueNotifier<String?>(null);

/// Login screen pe Mobile/Google fail hone par (provider band, account link
/// nahi, setup ki dikkat) yahi ek message dikhta hai
const String kAltLoginUnavailableMessage =
    'Mobile OTP and Google sign-in work for accounts linked from My Profile. '
    'For the demo, please use Email and Password.';

/// Login screen ke Mobile/Google errors. Jo galti user khud sudhar sake
/// (galat number/OTP, internet) uska apna message; baaki sab ke liye
/// [kAltLoginUnavailableMessage], taaki Firebase ka raw text na dikhe.
String altLoginErrorMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-phone-number':
      case 'invalid-verification-code':
      case 'session-expired':
      case 'code-expired':
      case 'too-many-requests':
      case 'quota-exceeded':
      case 'network-request-failed':
        return authErrorMessage(e);
    }
  }
  return kAltLoginUnavailableMessage;
}

bool _googleInitialized = false;

Future<void> _ensureGoogleInit() async {
  if (_googleInitialized) return;
  // Android pe serverClientId google-services.json (default_web_client_id) se aata hai
  await GoogleSignIn.instance.initialize();
  _googleInitialized = true;
}

/// Google account chunwa ke Firebase credential deta hai.
/// User ne cancel kiya to null.
Future<AuthCredential?> googleCredential() async {
  await _ensureGoogleInit();
  try {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'No ID token returned',
      );
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return null;
    rethrow;
  }
}

/// Google sign-in ke errors ko seedhe message me badalta hai
String googleErrorMessage(Object e) {
  if (e is GoogleSignInException) {
    if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
        e.code == GoogleSignInExceptionCode.providerConfigurationError) {
      return 'Google login is not set up yet for this app. Please contact the admin.';
    }
    return 'Google sign-in failed. Please try again.';
  }
  if (e is FirebaseAuthException) return authErrorMessage(e);
  return 'Google sign-in failed. Please try again.';
}

String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-phone-number':
      return 'Please enter a valid 10-digit mobile number.';
    case 'invalid-verification-code':
      return 'Incorrect OTP. Please check and try again.';
    case 'session-expired':
    case 'code-expired':
      return 'OTP expired. Please request a new one.';
    case 'too-many-requests':
    case 'quota-exceeded':
      return 'Too many attempts. Please try again after some time.';
    case 'operation-not-allowed':
      return 'This login method is not enabled yet. Please contact the admin.';
    case 'app-not-authorized':
    case 'missing-client-identifier':
    case 'invalid-app-credential':
      return 'This app is not yet authorised for mobile login. Please contact the admin.';
    case 'credential-already-in-use':
      return 'This is already linked to another account.';
    case 'provider-already-linked':
      return 'Your account already has one of these linked. Remove it first to link a new one.';
    case 'account-exists-with-different-credential':
      return 'An account already exists with this email. Log in with email and link Google from My Profile.';
    case 'requires-recent-login':
      return 'For security, please log out, log in again, and then retry.';
    case 'network-request-failed':
      return 'No internet connection. Please try again.';
    case 'user-disabled':
      return 'This account has been disabled. Please contact the admin.';
    default:
      return friendlyError(e);
  }
}

/// Mobile/Google credential se login. Agar ye credential kisi staff account
/// se juda nahi hai to Firebase ek naya khaali account bana deta hai — use
/// turant hata ke signOut karte hain. Error ho to message return karta hai.
Future<String?> signInStaffWithCredential(AuthCredential credential) async {
  try {
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    if (result.additionalUserInfo?.isNewUser == true) {
      loginNotice.value = kAltLoginUnavailableMessage;
      try {
        await result.user?.delete();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
      return kAltLoginUnavailableMessage;
    }
    return null;
  } catch (e) {
    return altLoginErrorMessage(e);
  }
}

/// Logged-in account se mobile/Google jodta hai. Error ho to message.
Future<String?> linkToCurrentUser(AuthCredential credential) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 'You are not logged in.';
  try {
    await user.linkWithCredential(credential);
    await user.reload();
    return null;
  } on FirebaseAuthException catch (e) {
    return authErrorMessage(e);
  } catch (_) {
    return 'Something went wrong. Please try again.';
  }
}

/// Mobile ('phone') ya Google ('google.com') ko account se hatata hai.
/// Kam se kam ek aur login tareeka bacha ho tabhi.
Future<String?> unlinkFromCurrentUser(String providerId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 'You are not logged in.';
  if (user.providerData.length <= 1) {
    return 'You need at least one other login method before removing this one.';
  }
  try {
    await user.unlink(providerId);
    await user.reload();
    if (providerId == GoogleAuthProvider.PROVIDER_ID && _googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
    return null;
  } on FirebaseAuthException catch (e) {
    return authErrorMessage(e);
  }
}

/// Mobile number + OTP ka bottom sheet. OTP verify hone par [onVerified]
/// chalta hai; wo error message return kare to sheet khuli rehti hai.
/// Kaam ho jaye to true return hota hai. OTP bhejne me error aaye to
/// [errorMessage] se message banta hai.
Future<bool> showPhoneOtpSheet(
  BuildContext context, {
  required String title,
  required Future<String?> Function(PhoneAuthCredential credential) onVerified,
  String Function(Object error) errorMessage = _defaultOtpError,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) =>
        _PhoneOtpSheet(title: title, onVerified: onVerified, errorMessage: errorMessage),
  );
  return done == true;
}

String _defaultOtpError(Object e) =>
    e is FirebaseAuthException ? authErrorMessage(e) : 'Something went wrong. Please try again.';

class _PhoneOtpSheet extends StatefulWidget {
  final String title;
  final Future<String?> Function(PhoneAuthCredential credential) onVerified;
  final String Function(Object error) errorMessage;
  const _PhoneOtpSheet({required this.title, required this.onVerified, required this.errorMessage});

  @override
  State<_PhoneOtpSheet> createState() => _PhoneOtpSheetState();
}

class _PhoneOtpSheetState extends State<_PhoneOtpSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _busy = false;
  String _error = '';
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) t.cancel();
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        // Android kabhi kabhi OTP khud padh leta hai
        verificationCompleted: (credential) => _complete(credential),
        verificationFailed: _failed,
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      // Web/desktop pe ye seedha throw kar sakta hai
      _failed(e);
    }
  }

  void _failed(Object e) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = widget.errorMessage(e);
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6 || _verificationId == null) {
      setState(() => _error = 'Please enter the 6-digit OTP.');
      return;
    }
    await _complete(
      PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: code),
    );
  }

  Future<void> _complete(PhoneAuthCredential credential) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final error = await widget.onVerified(credential);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  InputDecoration _inputStyle(String label, IconData icon, {String? prefix}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefix,
      counterText: '',
      prefixIcon: Icon(icon, color: AppColors.appPrimary),
      filled: true,
      fillColor: AppColors.appBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.appPrimary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otpSent = _verificationId != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.appPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            otpSent
                ? 'Enter the 6-digit OTP sent to +91 ${_phoneController.text.trim()}'
                : 'We will send a 6-digit OTP to this number by SMS.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _phoneController,
            enabled: !otpSent && !_busy,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: _inputStyle('Mobile Number', Icons.phone_outlined, prefix: '+91 '),
          ),
          if (otpSent) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _otpController,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: _inputStyle('OTP', Icons.password_outlined),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _verificationId = null;
                            _otpController.clear();
                            _error = '';
                          }),
                  child: const Text('Change number', style: TextStyle(color: AppColors.appPrimary)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: (_busy || _resendSeconds > 0) ? null : _sendOtp,
                  child: Text(
                    _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend OTP',
                    style: TextStyle(color: _resendSeconds > 0 ? Colors.grey : AppColors.appAccent),
                  ),
                ),
              ],
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error, style: TextStyle(color: Colors.red[700], fontSize: 13)),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : (otpSent ? _verifyOtp : _sendOtp),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      otpSent ? 'Verify OTP' : 'Send OTP',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
