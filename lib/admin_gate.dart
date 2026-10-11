import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'current_user.dart';

/// Screen ke andar ka role check: Admin ho to [child], warna "Access denied".
/// Menu se button chhupana kaafi nahi, isliye screen khud bhi dekhti hai.
class AdminGate extends StatefulWidget {
  final String screenName;
  final Widget child;
  const AdminGate({super.key, required this.screenName, required this.child});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  late final Future<String> _role = currentUserRole();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _role,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
        }
        if (snap.data == 'admin') return widget.child;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text(
                  'Access denied',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.screenName} sirf Admin dekh sakte hain.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
