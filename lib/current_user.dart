import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String? _cachedUid;
String? _cachedRole;

/// Logged-in user ka role ('admin', 'trainer', ...). Ek baar fetch hoke
/// cache ho jata hai; user badalne par dobara fetch hota hai.
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

/// Naye record pe createdBy + createdByRole lagane ke liye.
/// Use: final stamp = await creatorStamp();  phir map me ...stamp
Future<Map<String, dynamic>> creatorStamp() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  final role = await currentUserRole();
  return {'createdBy': user.uid, 'createdByRole': role};
}
