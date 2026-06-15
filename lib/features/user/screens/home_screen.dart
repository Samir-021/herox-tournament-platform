import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/three_d_glow_card.dart';
import 'package:herox/services/auth_service.dart';
import 'package:herox/services/user_service.dart';

import 'package:herox/features/admin/screens/admin_gate.dart';
import 'package:herox/features/tournament/screens/my_requests_screen.dart';
import 'package:herox/features/tournament/screens/tournament_list_screen.dart';
import 'package:herox/features/wallet/screens/wallet_screen.dart';
import 'package:herox/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:herox/features/user/screens/profile_screen.dart';
import 'package:herox/features/tournament/screens/create_tournament_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
        return CyberTheme.primary;
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await AuthService.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged out successfully")),
      );
    }
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    String uid,
    Map<String, dynamic> data,
  ) async {
    final uidController = TextEditingController(text: data['freeFireUid'] ?? '');
    final gameController = TextEditingController(text: data['gameName'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CyberTheme.surface,
          title: Text(
            "EDIT PROFILE",
            style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uidController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "FREE FIRE UID",
                  prefixIcon: Icon(Icons.tag, color: CyberTheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "IN-GAME NAME",
                  prefixIcon: Icon(Icons.person_pin_outlined, color: CyberTheme.primary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: CyberTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final ffUid = uidController.text.trim();
                final gameName = gameController.text.trim();

                if (ffUid.isEmpty || gameName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill all fields")),
                  );
                  return;
                }

                try {
                  await UserService.updateProfile(
                    uid: uid,
                    freeFireUid: ffUid,
                    gameName: gameName,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profile updated successfully!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to update profile: ${e.toString().replaceAll("Exception: ", "")}")),
                    );
                  }
                }
              },
              child: const Text("SAVE"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = AuthService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Session Expired. Please log in again.",
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "HEROX ARENA",
          style: GoogleFonts.oxanium(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: CyberTheme.accent),
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: UserService.getUserStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: CyberTheme.primary));
          }

          if (!snapshot.hasData || snapshot.data!.data() == null) {
            return const Center(
              child: Text("User profile not found.", style: TextStyle(color: Colors.white54)),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final level = data['level'] ?? 1;
          final xp = data['xp'] ?? 0;
          final division = data['division'] ?? 'Bronze';
          final seasonPoints = data['seasonPoints'] ?? 0;
          final tierColor = _getTierColor(division);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header Card
                ThreeDGlowCard(
                  glowColor: tierColor,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: tierColor.withValues(alpha: 0.2),
                            backgroundImage: user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : null,
                            child: user.photoURL == null
                                ? Icon(Icons.person, size: 36, color: tierColor)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? user.displayName ?? "Esports Player",
                                  style: GoogleFonts.oxanium(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user.email ?? "",
                                  style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tierColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        division.toUpperCase(),
                                        style: GoogleFonts.oxanium(
                                          color: tierColor,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: CyberTheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: CyberTheme.primary.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        "LVL $level",
                                        style: GoogleFonts.oxanium(
                                          color: CyberTheme.primary,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),

                      // Level Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "LEVEL PROGRESS",
                            style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          Text(
                            "${xp % 500} / 500 XP",
                            style: GoogleFonts.oxanium(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (xp % 500) / 500.0,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                          minHeight: 4,
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text("FF UID", style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 9)),
                              const SizedBox(height: 2),
                              Text(
                                data['freeFireUid'] != null && data['freeFireUid'].toString().isNotEmpty
                                    ? data['freeFireUid']
                                    : "NOT SET",
                                style: GoogleFonts.oxanium(
                                  color: data['freeFireUid'] != null ? Colors.white : Colors.white24,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(color: Colors.white10, width: 1, height: 20),
                          Column(
                            children: [
                              Text("GAME NAME", style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 9)),
                              const SizedBox(height: 2),
                              Text(
                                data['gameName'] != null && data['gameName'].toString().isNotEmpty
                                    ? data['gameName']
                                    : "NOT SET",
                                style: GoogleFonts.oxanium(
                                  color: data['gameName'] != null ? Colors.white : Colors.white24,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(color: Colors.white10, width: 1, height: 20),
                          Column(
                            children: [
                              Text("SEASON PTS", style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 9)),
                              const SizedBox(height: 2),
                              Text(
                                "$seasonPoints SP",
                                style: GoogleFonts.oxanium(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: const Size(120, 32),
                        ),
                        onPressed: () => _showEditProfileDialog(context, user.uid, data),
                        icon: const Icon(Icons.edit_calendar_outlined, size: 14),
                        label: Text("EDIT PROFILE", style: GoogleFonts.oxanium(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ).animate().fade(duration: CyberMotion.medium).slideY(begin: 0.1, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve),

                const SizedBox(height: 24),

                // Quick Actions Section Label
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text(
                    "QUICK ACTIONS",
                    style: GoogleFonts.oxanium(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ).animate().fade(delay: CyberMotion.fast, duration: CyberMotion.medium),

                // Navigation Actions
                ThreeDGlowCard(
                  glowColor: CyberTheme.secondary,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.emoji_events_outlined, color: CyberTheme.primary),
                        title: Text("VIEW TOURNAMENTS", style: GoogleFonts.oxanium(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text("Join active tournaments and win rewards", style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: CyberTheme.primary),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TournamentListScreen()),
                          );
                        },
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: CyberTheme.primary),
                        title: Text("CREATE TOURNAMENT", style: GoogleFonts.oxanium(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text("Host your own tournament and manage matches", style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: CyberTheme.primary),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateTournamentScreen()),
                          );
                        },
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined, color: CyberTheme.primary),
                        title: Text("MY REQUESTS", style: GoogleFonts.oxanium(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text("Track status of pending approvals", style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: CyberTheme.primary),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
                          );
                        },
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      ListTile(
                        leading: const Icon(Icons.account_balance_wallet_outlined, color: CyberTheme.primary),
                        title: Text("MY WALLET", style: GoogleFonts.oxanium(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text("Manage deposits & winnings", style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: CyberTheme.primary),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WalletScreen()),
                          );
                        },
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      ListTile(
                        leading: const Icon(Icons.leaderboard_outlined, color: CyberTheme.primary),
                        title: Text("LEADERBOARDS", style: GoogleFonts.oxanium(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text("View rankings and seasonal divisions", style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: CyberTheme.primary),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                          );
                        },
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      ListTile(
                        leading: const Icon(Icons.person_outline, color: CyberTheme.primary),
                        title: Text("PROFILE & STATS", style: GoogleFonts.oxanium(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text("View your gaming profile and statistics", style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: CyberTheme.primary),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                      ),
                      if (data['role'] == 'admin') ...[
                        const Divider(color: Colors.white10, height: 1),
                        ListTile(
                          tileColor: CyberTheme.accent.withValues(alpha: 0.02),
                          leading: const Icon(Icons.admin_panel_settings_outlined, color: CyberTheme.accent),
                          title: Text(
                            "ADMIN CONTROL PANEL",
                            style: GoogleFonts.oxanium(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: CyberTheme.accent,
                            ),
                          ),
                          subtitle: const Text("Configure matches, resolve reports & logs", style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, color: CyberTheme.accent),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminGate()),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ).animate().fade(delay: CyberMotion.medium, duration: CyberMotion.medium).slideY(begin: 0.05, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve),
              ],
            ),
          );
        },
      ),
    );
  }
}