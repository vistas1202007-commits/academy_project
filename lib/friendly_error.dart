import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// Turns any error into a short English message fit to show the user.
/// Raw error text is never shown to the user; send it to the console with debugPrint.
String friendlyError(Object e) {
  final code = e is FirebaseException ? e.code : '';
  switch (code) {
    case 'permission-denied':
      return "You don't have permission to do this.";
    case 'unavailable':
    case 'network-request-failed':
    case 'deadline-exceeded':
      return 'Network problem. Please check your connection and try again.';
    case 'not-found':
      return 'This record no longer exists.';
    case 'already-exists':
    case 'email-already-in-use':
      return 'This record already exists.';
  }
  if (e is TimeoutException) return 'Network problem. Please check your connection and try again.';
  // Non-Firebase errors (like SocketException) have no code
  if (code.isEmpty) {
    final text = e.toString().toLowerCase();
    if (text.contains('network') || text.contains('unavailable') || text.contains('timeout') ||
        text.contains('timed out') || text.contains('socketexception')) {
      return 'Network problem. Please check your connection and try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
