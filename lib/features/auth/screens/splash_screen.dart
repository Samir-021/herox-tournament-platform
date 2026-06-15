import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/features/auth/widgets/auth_gate.dart';
import 'package:herox/features/auth/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool completedOnboarding;

  const SplashScreen({
    super.key,
    required this.completedOnboarding,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _rotate;
  late final Animation<double> _glow;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    );

    _scale = Tween(begin: 0.5, end: 1.0).animate(curve);
    _fade = Tween(begin: 0.0, end: 1.0).animate(curve);
    _rotate = Tween(begin: -0.1, end: 0.0).animate(curve);

    // glowing pulse effect
    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 30), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 30, end: 15), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.completedOnboarding
              ? const AuthGate()
              : const OnboardingScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fade.value,
              child: Transform.rotate(
                angle: _rotate.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Container(
                    padding: const EdgeInsets.all(35),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: CyberTheme.primary.withValues(alpha: 0.6),
                          blurRadius: _glow.value,
                          spreadRadius: _glow.value / 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // logo glow container
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                CyberTheme.primary.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/herox_logo.png',
                            width: 140,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.sports_esports,
                              size: 100,
                              color: CyberTheme.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          "HEROX",
                          style: GoogleFonts.oxanium(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "Enter the Battle Arena",
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),

                        const SizedBox(height: 15),

                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CyberTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}