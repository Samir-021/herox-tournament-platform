import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:herox/core/theme/cyber_theme.dart';

class ErrorBoundaryScreen extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const ErrorBoundaryScreen({super.key, required this.errorDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  color: CyberTheme.accent,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  "ARENA SYSTEM GLITCH",
                  style: GoogleFonts.oxanium(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "An unexpected error occurred inside the battle networks. The admin logs have been notified.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: CyberTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CyberTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CyberTheme.accent.withValues(alpha: 0.3)),
                  ),
                  height: 150,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: Text(
                      errorDetails.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text("RESET SESSION"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
