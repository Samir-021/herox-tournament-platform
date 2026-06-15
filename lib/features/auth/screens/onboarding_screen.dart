import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/features/auth/widgets/auth_gate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _slides = [
    OnboardingPageData(
      title: "WELCOME TO THE ARENA",
      description: "Compete with top players, join community tournaments, and showcase your gaming skills to win cash prizes.",
      icon: Icons.sports_esports,
      gradientColor: CyberTheme.primary,
    ),
    OnboardingPageData(
      title: "SECURE REGISTRATION",
      description: "Submit your Game name & Free Fire UID, register in a single click, and track your entries live.",
      icon: Icons.shield_outlined,
      gradientColor: CyberTheme.secondary,
    ),
    OnboardingPageData(
      title: "CLIMB THE LEADERBOARD",
      description: "Secure your slots, track your tournament standings, level up, and unlock epic profile achievements.",
      icon: Icons.emoji_events_outlined,
      gradientColor: CyberTheme.accent,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_onboarding', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: CyberTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    "SKIP",
                    style: GoogleFonts.oxanium(
                      color: CyberTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 180,
                            width: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  slide.gradientColor.withValues(alpha: 0.25),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Icon(
                              slide.icon,
                              size: 100,
                              color: slide.gradientColor,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.oxanium(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: slide.gradientColor.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            slide.description,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: CyberTheme.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        _slides.length,
                        (index) => _buildIndicator(index),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        side: BorderSide(
                          color: _slides[_currentPage].gradientColor,
                          width: 2,
                        ),
                      ),
                      onPressed: () {
                        if (_currentPage == _slides.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(
                        _currentPage == _slides.length - 1 ? "GET STARTED" : "NEXT",
                        style: GoogleFonts.oxanium(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? _slides[_currentPage].gradientColor : CyberTheme.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color gradientColor;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColor,
  });
}
