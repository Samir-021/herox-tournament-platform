import 'package:flutter/material.dart';
import 'package:herox/services/admin_service.dart';
import 'package:herox/features/admin/screens/admin_panel.dart';

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminService.isAdmin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isAdmin = snapshot.data!;

        if (!isAdmin) {
          return const Scaffold(
            body: Center(
              child: Text(
                "Access Denied 🚫",
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return const AdminPanel();
      },
    );
  }
}