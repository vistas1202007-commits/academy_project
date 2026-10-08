import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Naye record pe createdBy + createdByRole lagane ke liye.
/// Use: final stamp = await creatorStamp();  phir map me ...stamp
Future<Map<String, dynamic>> creatorStamp() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  String role = '';
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    role = (doc.data()?['role'] ?? '').toString();
  } catch (_) {}
  return {'createdBy': user.uid, 'createdByRole': role};
}