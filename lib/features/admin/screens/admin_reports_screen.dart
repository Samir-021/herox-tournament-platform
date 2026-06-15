import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:herox/services/report_service.dart';
import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/core/widgets/empty_state.dart';

class AdminReportScreen extends StatelessWidget {
  const AdminReportScreen({super.key});

  Future<void> _showBanConfirmationDialog(
    BuildContext context,
    String userId,
    String userName,
    String reportId,
  ) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CyberTheme.surface,
          title: Text(
            "CONFIRM BAN",
            style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Are you sure you want to ban player '$userName'? This will suspend their access immediately.",
                  style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "BAN REASON",
                    hintText: "e.g. Abusive behavior or fake screenshots",
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Reason is required to ban a player.";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: CyberTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text("BAN PLAYER", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final reason = reasonController.text.trim();
      final admin = FirebaseAuth.instance.currentUser;
      if (admin == null) return;

      try {
        await ReportService.banUser(
          userId: userId,
          reason: reason,
          adminUid: admin.uid,
          adminEmail: admin.email ?? admin.uid,
        );
        await ReportService.markReportHandled(reportId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Player banned successfully & action logged.")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to ban: $e")),
          );
        }
      }
    }
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CyberTheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLoading(width: 200, height: 18),
              SizedBox(height: 12),
              ShimmerLoading(width: 140, height: 14),
              SizedBox(height: 8),
              ShimmerLoading(width: 100, height: 14),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "REPORTS LOG",
          style: GoogleFonts.oxanium(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonList();
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: "NO INCIDENT REPORTS",
              description: "The arena is secure. There are currently no reports filed by players.",
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isPending = data['status'] == 'pending';

              return GlassCard(
                borderColor: isPending ? CyberTheme.accent : CyberTheme.surfaceLight,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reason: ${data['reason']}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Reported User: ${data['toName'] ?? 'Unknown'} (${data['toUserId'] ?? ''})",
                      style: const TextStyle(color: CyberTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Status: ${(data['status'] ?? 'pending').toString().toUpperCase()}",
                      style: TextStyle(
                        color: isPending ? CyberTheme.accent : Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (isPending) ...[
                      const Divider(color: Colors.white10, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () {
                              final userId = data['toUserId'];
                              final userName = data['toName'] ?? 'Unknown';
                              if (userId != null && userId.toString().isNotEmpty) {
                                _showBanConfirmationDialog(context, userId, userName, doc.id);
                              }
                            },
                            child: Text(
                              "BAN USER",
                              style: GoogleFonts.oxanium(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(color: CyberTheme.primary),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () async {
                              await ReportService.markReportHandled(doc.id);
                            },
                            child: Text(
                              "DISMISS",
                              style: GoogleFonts.oxanium(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}