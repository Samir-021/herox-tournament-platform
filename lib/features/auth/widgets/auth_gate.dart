import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:herox/services/auth_service.dart';
import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/features/auth/screens/login_screen.dart';
import 'package:herox/features/user/screens/home_screen.dart';
import 'package:herox/features/user/screens/suspended_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: CyberTheme.primary),
            ),
          );
        }

        if (snapshot.hasData) {
          final User user = snapshot.data!;
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bans')
                .doc(user.uid)
                .snapshots(),
            builder: (context, banSnapshot) {
              if (banSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: CyberTheme.primary),
                  ),
                );
              }

              if (banSnapshot.hasData && banSnapshot.data!.exists) {
                final banData = banSnapshot.data!.data() as Map<String, dynamic>?;
                final isBanned = banData?['banned'] == true;
                if (isBanned) {
                  final expiry = banData?['expiryDate'] as Timestamp?;
                  final hasExpired = expiry != null && expiry.toDate().isBefore(DateTime.now());
                  if (!hasExpired) {
                    final reason = banData?['reason'] ?? "You are banned from HeroX due to violations of community rules.";
                    return SuspendedScreen(
                      reason: reason,
                      banDetails: banData ?? {},
                      userId: user.uid,
                    );
                  }
                }
              }

              return const HomeScreen();
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}