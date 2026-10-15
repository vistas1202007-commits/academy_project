import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String? _cachedUid;
String? _cachedRole;

/// The logged-in user's role ('admin', 'trainer', ...). Fetched once and
/// cached; fetched again when the user changes.
Future<String> currentUserRole() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '';
  if (_cachedUid == user.uid && _cachedRole != null) return _cachedRole!;
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = (doc.data()?['role'] ?? '').toString();
    _cachedUid = user.uid;
    _cachedRole = role;
    return role;
  } catch (_) {
    return '';
  }
}

/// For stamping createdBy + createdByRole on new records.
/// Usage: final stamp = await creatorStamp();  then ...stamp in the map
Future<Map<String, dynamic>> creatorStamp() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  final role = await currentUserRole();
  return {'createdBy': user.uid, 'createdByRole': role};
}
