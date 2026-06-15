import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/three_d_glow_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/core/widgets/empty_state.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _userDivision = "Bronze";
  bool _loadingUserDivision = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserDivision();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDivision() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          setState(() {
            _userDivision = data['division'] ?? "Bronze";
          });
        }
      } catch (_) {}
    }
    setState(() {
      _loadingUserDivision = false;
    });
  }

  String _getSeasonalTier(int points) {
    if (points < 500) return "BRONZE";
    if (points < 1000) return "SILVER";
    if (points < 2000) return "GOLD";
    if (points < 3500) return "PLATINUM";
    if (points < 5000) return "DIAMOND";
    if (points < 7500) return "MASTER";
    return "HEROX LEGEND";
  }

  Color _getTierColor(String tier) {
    switch (tier.toUpperCase()) {
      case "BRONZE":
        return Colors.brown.shade400;
      case "SILVER":
        return Colors.grey.shade400;
      case "GOLD":
        return Colors.amber.shade600;
      case "PLATINUM":
        return Colors.tealAccent;
      case "DIAMOND":
        return Colors.blueAccent;
      case "MASTER":
        return Colors.purpleAccent;
      case "HEROX LEGEND":
        return const Color(0xFFFF5E00); // Orange Legend
      default:
        return Colors.white70;
    }
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CyberTheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(
            children: [
              ShimmerLoading(width: 30, height: 30, borderRadius: 15),
              SizedBox(width: 16),
              ShimmerLoading(width: 120, height: 16),
              Spacer(),
              ShimmerLoading(width: 60, height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardView({
    required Stream<QuerySnapshot> stream,
    required bool sortByWinnings,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonList();
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.emoji_events_outlined,
            title: "LEADERBOARD EMPTY",
            description: "Play matches, secure kills and wins to climb the regional leaderboards!",
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final name = data['playerName'] ?? 'Player';
            final points = (data['points'] ?? 0) as int;
            final wins = (data['wins'] ?? 0) as int;
            final kills = (data['kills'] ?? 0) as int;
            final winnings = (data['winnings'] ?? 0.0) as double;
            final String division = data['division'] ?? _getSeasonalTier(points);

            final tier = division.toUpperCase();
            final tierColor = _getTierColor(tier);
            final rank = index + 1;

            Color borderCol = CyberTheme.surfaceLight;
            if (rank == 1) borderCol = Colors.amber;
            if (rank == 2) borderCol = Colors.grey.shade300;
            if (rank == 3) borderCol = Colors.brown.shade300;

            final cardChild = Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: rank <= 3 ? borderCol.withValues(alpha: 0.2) : Colors.white10,
                  child: Text(
                    "$rank",
                    style: GoogleFonts.oxanium(
                      color: rank <= 3 ? borderCol : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toUpperCase(),
                        style: GoogleFonts.oxanium(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              tier,
                              style: GoogleFonts.oxanium(
                                color: tierColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "W: $wins | K: $kills",
                            style: GoogleFonts.outfit(color: CyberTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      sortByWinnings ? "₹${winnings.toStringAsFixed(0)}" : "$points PTS",
                      style: GoogleFonts.oxanium(
                        color: sortByWinnings ? Colors.greenAccent : CyberTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (!sortByWinnings)
                      Text(
                        "₹${winnings.toStringAsFixed(0)} Won",
                        style: GoogleFonts.outfit(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      Text(
                        "$points Points",
                        style: GoogleFonts.outfit(
                          color: CyberTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            );

            final entranceDelay = (index * 50).clamp(0, 500);

            if (rank <= 3) {
              return ThreeDGlowCard(
                glowColor: borderCol,
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                child: cardChild,
              ).animate().fade(delay: entranceDelay.ms, duration: CyberMotion.medium).slideY(begin: 0.05, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve);
            }

            return GlassCard(
              borderColor: borderCol,
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              child: cardChild,
            ).animate().fade(delay: entranceDelay.ms, duration: CyberMotion.medium).slideY(begin: 0.05, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Global: sorted by winnings
    final globalStream = FirebaseFirestore.instance
        .collection('leaderboards')
        .orderBy('winnings', descending: true)
        .snapshots();

    // 2. Season: sorted by points
    final seasonStream = FirebaseFirestore.instance
        .collection('leaderboards')
        .orderBy('points', descending: true)
        .snapshots();

    // 3. Division: filtered by player division and sorted by points
    final divisionStream = FirebaseFirestore.instance
        .collection('leaderboards')
        .where('division', isEqualTo: _userDivision)
        .orderBy('points', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "ARENA LEADERBOARDS",
          style: GoogleFonts.oxanium(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CyberTheme.primary,
          labelColor: CyberTheme.primary,
          unselectedLabelColor: CyberTheme.textSecondary,
          labelStyle: GoogleFonts.oxanium(fontWeight: FontWeight.bold, fontSize: 11),
          tabs: [
            const Tab(text: "GLOBAL CAREER", icon: Icon(Icons.public)),
            const Tab(text: "SEASON STANDINGS", icon: Icon(Icons.military_tech)),
            Tab(text: "MY DIVISION ($_userDivision)", icon: const Icon(Icons.shield_outlined)),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberTheme.backgroundGradient),
        child: _loadingUserDivision
            ? const Center(child: CircularProgressIndicator(color: CyberTheme.primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildLeaderboardView(stream: globalStream, sortByWinnings: true),
                  _buildLeaderboardView(stream: seasonStream, sortByWinnings: false),
                  _buildLeaderboardView(stream: divisionStream, sortByWinnings: false),
                ],
              ),
      ),
    );
  }
}
