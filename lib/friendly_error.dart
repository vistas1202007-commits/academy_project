import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// Kisi bhi error ko user ke dikhane layak chhota English message banata hai.
/// Raw error text user ko kabhi nahi dikhta; use debugPrint se console me daalein.
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
  // Firebase ke bahar ke errors (jaise SocketException) me code nahi hota
  if (code.isEmpty) {
    final text = e.toString().toLowerCase();
    if (text.contains('network') || text.contains('unavailable') || text.contains('timeout') ||
        text.contains('timed out') || text.contains('socketexception')) {
      return 'Network problem. Please check your connection and try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
