import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VTI ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6B4A)),
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatelessWidget {
  const AuthCheckScreen({super.key});

  static const Color primaryGreen = Color(0xFF1B6B4A);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Still checking whether a session exists
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7F5),
            body: Center(child: CircularProgressIndicator(color: primaryGreen)),
          );
        }

        // No logged-in user -> show Login screen
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // A user session exists -> fetch their profile (role + name) before showing Dashboard
        final uid = authSnapshot.data!.uid;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFFF5F7F5),
                body: Center(child: CircularProgressIndicator(color: primaryGreen)),
              );
            }

            // Profile missing or account deactivated -> force back to Login
            if (!profileSnapshot.hasData || !profileSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final data = profileSnapshot.data!.data() as Map<String, dynamic>;
            final isActive = data['isActive'] ?? true;
            if (isActive == false) {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final role = data['role'] ?? 'trainer';
            final name = data['name'] ?? authSnapshot.data!.email ?? 'User';

            return DashboardScreen(role: role, name: name);
          },
        );
      },
    );
  }
}