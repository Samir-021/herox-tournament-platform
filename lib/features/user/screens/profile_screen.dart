import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController uidController = TextEditingController();
  bool loading = true;

  final List<Map<String, dynamic>> allAchievements = [
    {
      'id': 'First Tournament',
      'title': 'First Arena',
      'desc': 'Enter your first esports arena match.',
      'icon': Icons.military_tech,
    },
    {
      'id': '5 Tournaments Played',
      'title': 'Vanguard V',
      'desc': 'Participate in 5 tournaments.',
      'icon': Icons.sports_esports,
    },
    {
      'id': '25 Tournaments Played',
      'title': 'Gladiator XXV',
      'desc': 'Participate in 25 tournaments.',
      'icon': Icons.workspace_premium,
    },
    {
      'id': 'First Victory',
      'title': 'First Booyah!',
      'desc': 'Secure 1st place in a tournament match.',
      'icon': Icons.emoji_events,
    },
    {
      'id': '5 Wins',
      'title': 'Champion V',
      'desc': 'Win 5 tournaments.',
      'icon': Icons.stars,
    },
    {
      'id': '10 Wins',
      'title': 'Champion X',
      'desc': 'Win 10 tournaments.',
      'icon': Icons.military_tech_outlined,
    },
    {
      'id': 'Top 10 Finish',
      'title': 'Top 10 Player',
      'desc': 'Place in the top 10 in a match.',
      'icon': Icons.looks_one,
    },
    {
      'id': 'Top 3 Finish',
      'title': 'Podium Runner',
      'desc': 'Place in the top 3 in a match.',
      'icon': Icons.looks_two,
    },
    {
      'id': 'Season Competitor',
      'title': 'Season Contender',
      'desc': 'Join a tournament in the active season.',
      'icon': Icons.badge,
    },
    {
      'id': 'Season Champion',
      'title': 'Season Legend',
      'desc': 'Win 20 matches or reach Master/Legend tier.',
      'icon': Icons.workspace_premium_outlined,
    },
    {
      'id': '1000 XP Earned',
      'title': 'Max Overdrive',
      'desc': 'Accumulate 1000 experience points.',
      'icon': Icons.bolt,
    },
    {
      'id': 'Diamond Division',
      'title': 'Diamond Core',
      'desc': 'Reach the Diamond division tier.',
      'icon': Icons.diamond_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    uidController.text = data?['freeFireUid'] ?? '';

    setState(() {
      loading = false;
    });
  }

  Future<void> saveUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'freeFireUid': uidController.text.trim(),
        'email': user.email,
        'name': user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.update({
        'freeFireUid': uidController.text.trim(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Free Fire UID Saved')),
      );
    }
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
        return const Color(0xFFFF5E00);
      default:
        return Colors.white70;
    }
  }

  void _showAchievementDetail(BuildContext context, Map<String, dynamic> ach, bool isUnlocked) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CyberTheme.surface,
          title: Row(
            children: [
              Icon(
                ach['icon'] as IconData,
                color: isUnlocked ? Colors.amber : Colors.white24,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (ach['title'] as String).toUpperCase(),
                  style: GoogleFonts.oxanium(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ach['desc'] as String,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isUnlocked ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.amberAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnlocked ? Icons.check_circle_outline : Icons.lock_outline,
                      color: isUnlocked ? Colors.greenAccent : Colors.amberAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUnlocked ? "UNLOCKED" : "LOCKED",
                      style: GoogleFonts.oxanium(
                        color: isUnlocked ? Colors.greenAccent : Colors.amberAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE", style: TextStyle(color: CyberTheme.primary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAccountDeletion(BuildContext context, User? user) async {
    if (user == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CyberTheme.surface,
          title: Text(
            "DELETE ACCOUNT?",
            style: GoogleFonts.oxanium(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Are you sure you want to permanently delete your HeroX account?\n\n"
            "This action is IRREVERSIBLE. Your profile, matches played, total wins, achievements, and entire wallet balance will be permanently erased. All cash balances will be forfeited.",
            style: GoogleFonts.outfit(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: CyberTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("DELETE PERMANENTLY"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: CyberTheme.primary)),
      );

      try {
        final uid = user.uid;

        // 1. Delete Firestore documents
        final batch = FirebaseFirestore.instance.batch();
        batch.delete(FirebaseFirestore.instance.collection('users').doc(uid));
        batch.delete(FirebaseFirestore.instance.collection('wallets').doc(uid));
        batch.delete(FirebaseFirestore.instance.collection('player_stats').doc(uid));
        batch.delete(FirebaseFirestore.instance.collection('leaderboards').doc(uid));

        await batch.commit();

        // 2. Delete the Auth User
        await user.delete();

        if (context.mounted) {
          Navigator.pop(context); // Pop loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account successfully deleted")),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Pop loading indicator
        }
        if (e.code == 'requires-recent-login') {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: CyberTheme.surface,
                  title: Text(
                    "RE-AUTHENTICATION REQUIRED",
                    style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    "For your security, you must sign out and log back in to verify your identity before deleting your account.",
                    style: GoogleFonts.outfit(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK", style: TextStyle(color: CyberTheme.primary)),
                    ),
                  ],
                );
              },
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to delete account: ${e.message}")),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Pop loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("An error occurred: $e")),
          );
        }
      }
    }
  }

  Widget _buildProgressionCard(int level, int xp, int seasonPoints, String division) {
    final tierColor = _getTierColor(division);
    final levelXp = xp % 500;
    final progress = levelXp / 500.0;

    return GlassCard(
      borderColor: tierColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: tierColor, width: 1.5),
                ),
                child: Icon(Icons.shield_outlined, color: tierColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      division.toUpperCase(),
                      style: GoogleFonts.oxanium(
                        color: tierColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      "$seasonPoints SEASON POINTS (SP)",
                      style: GoogleFonts.outfit(
                        color: CyberTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: CyberTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CyberTheme.primary.withValues(alpha: 0.5)),
                ),
                child: Text(
                  "LVL $level",
                  style: GoogleFonts.oxanium(
                    color: CyberTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "LEVEL PROGRESS",
                style: GoogleFonts.oxanium(
                  color: CyberTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "$levelXp / 500 XP",
                style: GoogleFonts.oxanium(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(List<String> unlocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white10, height: 40),
        Text(
          "ARENA ACHIEVEMENTS",
          style: GoogleFonts.oxanium(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allAchievements.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final ach = allAchievements[index];
            final id = ach['id'] as String;
            final isUnlocked = unlocked.contains(id);

            return InkWell(
              onTap: () => _showAchievementDetail(context, ach, isUnlocked),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? CyberTheme.primary.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.01),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isUnlocked
                        ? CyberTheme.primary.withValues(alpha: 0.3)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          ach['icon'] as IconData,
                          color: isUnlocked ? Colors.amber : Colors.white24,
                          size: 28,
                        ),
                        if (!isUnlocked)
                          const Positioned(
                            bottom: 0,
                            right: 0,
                            child: Icon(Icons.lock, color: Colors.white38, size: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ach['title'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.oxanium(
                        color: isUnlocked ? Colors.white : Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountDeletionSection(BuildContext context, User? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white10, height: 40),
        GlassCard(
          borderColor: Colors.redAccent.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "ACCOUNT SECURITY & DATA",
                    style: GoogleFonts.oxanium(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Permanently delete your HeroX account and all related data. This operation is compliance-required under Google Play Console guidelines.",
                style: GoogleFonts.outfit(
                  color: CyberTheme.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: () => _confirmAccountDeletion(context, user),
                  child: const Text("DELETE ACCOUNT"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PROFILE',
          style: GoogleFonts.oxanium(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberTheme.backgroundGradient),
        child: loading || user == null
            ? const Center(child: CircularProgressIndicator(color: CyberTheme.primary))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: CyberTheme.primary));
                  }

                  final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final int xp = userData['xp'] ?? 0;
                  final int level = userData['level'] ?? 1;
                  final int seasonPoints = userData['seasonPoints'] ?? 0;
                  final String division = userData['division'] ?? 'Bronze';
                  final List<dynamic> unlockedAchDynamic = userData['achievements'] as List<dynamic>? ?? [];
                  final List<String> unlockedAchievements = unlockedAchDynamic.map((e) => e.toString()).toList();

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: SingleChildScrollView(
                        child: GlassCard(
                          borderColor: _getTierColor(division),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (user.photoURL != null)
                                CircleAvatar(
                                  radius: 44,
                                  backgroundImage: NetworkImage(user.photoURL!),
                                )
                              else
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor: CyberTheme.primary.withValues(alpha: 0.2),
                                  child: const Icon(Icons.person, size: 44, color: CyberTheme.primary),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                user.displayName ?? 'Esports Player',
                                style: GoogleFonts.oxanium(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                user.email ?? '',
                                style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 24),
                              
                              // Progression Card
                              _buildProgressionCard(level, xp, seasonPoints, division)
                                  .animate()
                                  .fade(duration: CyberMotion.medium)
                                  .slideY(begin: 0.05, curve: CyberMotion.snappyCurve),
                              
                              const SizedBox(height: 16),
                              TextField(
                                controller: uidController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'FREE FIRE UID',
                                  prefixIcon: Icon(Icons.tag, color: CyberTheme.primary),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: saveUid,
                                  child: const Text('SAVE UID'),
                                ),
                              ),
                              
                              const Divider(color: Colors.white10, height: 40),
                              Text(
                                "PLAYER METRICS",
                                style: GoogleFonts.oxanium(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('player_stats')
                                    .doc(user.uid)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final data = snapshot.hasData && snapshot.data!.exists
                                      ? snapshot.data!.data() as Map<String, dynamic>
                                      : {};

                                  final int matches = data['totalMatches'] ?? 0;
                                  final int wins = data['totalWins'] ?? 0;
                                  final int kills = data['totalKills'] ?? 0;
                                  final double prize = (data['totalPrizeWon'] ?? 0.0) is int
                                      ? (data['totalPrizeWon'] ?? 0.0).toDouble()
                                      : (data['totalPrizeWon'] ?? 0.0);

                                  final winRate = matches > 0 ? (wins / matches * 100).toStringAsFixed(1) : "0.0";
                                  final kd = matches > 0 ? (kills / matches).toStringAsFixed(2) : "0.00";

                                  return GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 2.2,
                                    children: [
                                      _buildStatTile("MATCHES", "$matches", CyberTheme.primary),
                                      _buildStatTile("WINS", "$wins", Colors.greenAccent),
                                      _buildStatTile("KILLS", "$kills", Colors.amber),
                                      _buildStatTile("WIN RATE", "$winRate%", Colors.tealAccent),
                                      _buildStatTile("K/D RATIO", kd, Colors.cyan),
                                      _buildStatTile("EARNINGS", "₹${prize.toStringAsFixed(0)}", Colors.purpleAccent),
                                    ],
                                  );
                                },
                              ),

                              // Achievements Section
                              _buildAchievementsSection(unlockedAchievements),

                              // Account Deletion Section
                              _buildAccountDeletionSection(context, user),
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

  Widget _buildStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.oxanium(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}