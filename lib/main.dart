import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/error_boundary.dart';
import 'package:herox/features/auth/widgets/auth_gate.dart';
import 'package:herox/features/auth/screens/onboarding_screen.dart';
import 'package:herox/features/auth/screens/splash_screen.dart';

import 'firebase_options.dart';
import 'package:herox/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return ErrorBoundaryScreen(errorDetails: details);
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load onboarding state
  final prefs = await SharedPreferences.getInstance();
  final bool completedOnboarding =
      prefs.getBool('completed_onboarding') ?? false;

  // 🔥 IMPORTANT: restore user session + role on app start
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    await AuthService.fetchUserRole(user.uid);
  }

  runApp(HeroXApp(completedOnboarding: completedOnboarding));
}

class HeroXApp extends StatelessWidget {
  final bool completedOnboarding;

  const HeroXApp({super.key, required this.completedOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HeroX',
      theme: CyberTheme.themeData,

      // 🔥 AuthGate ensures persistent login + role-based UI
      home: SplashScreen(
        completedOnboarding: completedOnboarding,
      ),
    );
  }
}