import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/three_d_glow_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/services/wallet_service.dart';

import 'package:herox/features/wallet/screens/add_credits_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      WalletService.createWalletIfMissing(user.uid);
    }
  }

  Widget _buildTransactionsSkeleton() {
    return ListView.builder(
      itemCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CyberTheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(
            children: [
              ShimmerLoading(width: 40, height: 40, borderRadius: 20),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(width: 120, height: 16),
                  SizedBox(height: 6),
                  ShimmerLoading(width: 80, height: 12),
                ],
              ),
              Spacer(),
              ShimmerLoading(width: 60, height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not authenticated.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "ARENA WALLET",
          style: GoogleFonts.oxanium(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberTheme.backgroundGradient),
        child: StreamBuilder<DocumentSnapshot>(
                stream: WalletService.getWalletStream(user.uid),
                builder: (context, walletSnap) {
                  if (walletSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: CyberTheme.primary));
                  }

                  final data = walletSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final double balance = (data['balance'] ?? 0.0) as double;
                  final double winnings = (data['winnings'] ?? 0.0) as double;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Glassmorphic Balance Cards
                        Row(
                          children: [
                            Expanded(
                              child: ThreeDGlowCard(
                                glowColor: CyberTheme.primary,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "CREDIT BALANCE",
                                      style: GoogleFonts.oxanium(color: CyberTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "₹${balance.toStringAsFixed(1)}",
                                      style: GoogleFonts.oxanium(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(color: CyberTheme.primary.withValues(alpha: 0.5), blurRadius: 10),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fade(duration: CyberMotion.medium).slideY(begin: 0.1, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ThreeDGlowCard(
                                glowColor: CyberTheme.secondary,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "TOURNAMENT WINNINGS",
                                      style: GoogleFonts.oxanium(color: CyberTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "₹${winnings.toStringAsFixed(1)}",
                                      style: GoogleFonts.oxanium(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(color: CyberTheme.secondary.withValues(alpha: 0.5), blurRadius: 10),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fade(delay: CyberMotion.fast, duration: CyberMotion.medium).slideY(begin: 0.1, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(color: CyberTheme.primary, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddCreditsScreen()),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: Text("ADD CREDITS (eSewa)", style: GoogleFonts.oxanium(fontWeight: FontWeight.bold)),
                          ),
                        ).animate().fade(delay: 200.ms),

                        const SizedBox(height: 30),

                        Text(
                          "TRANSACTION HISTORY",
                          style: GoogleFonts.oxanium(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ).animate().fade(delay: 300.ms),
                        const SizedBox(height: 12),

                        // Transaction Stream
                        StreamBuilder<QuerySnapshot>(
                          stream: WalletService.getTransactionsStream(user.uid),
                          builder: (context, txSnap) {
                            if (txSnap.connectionState == ConnectionState.waiting) {
                              return _buildTransactionsSkeleton();
                            }

                            final docs = txSnap.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: CyberTheme.surface.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: const Center(
                                  child: Text(
                                    "No transaction activities found.",
                                    style: TextStyle(color: CyberTheme.textSecondary, fontSize: 13),
                                  ),
                                ),
                              ).animate().fade(delay: 400.ms);
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final tx = docs[index].data() as Map<String, dynamic>;
                                final double amount = (tx['amount'] ?? 0.0) as double;
                                final String desc = tx['description'] ?? '';
                                final Timestamp? ts = tx['timestamp'] as Timestamp?;

                                final isNegative = amount < 0;
                                final color = isNegative ? CyberTheme.accent : Colors.greenAccent;

                                return GlassCard(
                                  borderColor: CyberTheme.surfaceLight,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: color.withValues(alpha: 0.12),
                                        radius: 18,
                                        child: Icon(
                                          isNegative ? Icons.remove : Icons.add,
                                          color: color,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              desc,
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              ts != null
                                                  ? "${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} - ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}"
                                                  : "",
                                              style: const TextStyle(color: CyberTheme.textMuted, fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        "${isNegative ? '-' : '+'}₹${amount.abs().toStringAsFixed(1)}",
                                        style: GoogleFonts.oxanium(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fade(delay: (CyberMotion.medium.inMilliseconds + (index * 50)).ms, duration: CyberMotion.medium);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
