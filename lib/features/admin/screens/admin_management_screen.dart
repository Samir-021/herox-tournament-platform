import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/services/admin_service.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> addAdmin() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await AdminService.addAdminByEmail(email);
    emailController.clear();

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );
  }

  Future<void> removeAdmin(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberTheme.surface,
        title: const Text("REVOKE ROLE?"),
        content: const Text("Are you sure you want to remove this user from the admin team?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: CyberTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(side: const BorderSide(color: CyberTheme.accent)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("REVOKE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await AdminService.removeAdmin(uid);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin permissions revoked")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "STAFF MANAGEMENT",
          style: GoogleFonts.oxanium(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Add Section
            GlassCard(
              borderColor: CyberTheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "ADD TEAM ADMIN",
                    style: GoogleFonts.oxanium(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "REGISTERED USER EMAIL",
                      prefixIcon: Icon(Icons.email, color: CyberTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: CyberTheme.primary))
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: CyberTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          side: BorderSide.none,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        onPressed: addAdmin,
                        child: Text(
                          "PROSPECT ADMIN STAFF",
                          style: GoogleFonts.oxanium(fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              "ACTIVE PERMITTED ADMINS",
              style: GoogleFonts.oxanium(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: AdminService.getAdmins(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                      itemCount: 2,
                      itemBuilder: (context, index) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: ShimmerLoading(width: double.infinity, height: 50),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text("No admin members recorded.", style: TextStyle(color: CyberTheme.textSecondary)),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];

                      return GlassCard(
                        borderColor: CyberTheme.surfaceLight,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            doc['email'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            "UID: ${doc.id}",
                            style: const TextStyle(color: CyberTheme.textMuted, fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => removeAdmin(doc.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
