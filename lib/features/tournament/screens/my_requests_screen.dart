import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/core/widgets/empty_state.dart';
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.greenAccent;
      case "rejected":
        return Colors.redAccent;
      case "verification_pending":
        return Colors.orangeAccent;
      case "waiting_payment":
        return Colors.amberAccent;
      default:
        return CyberTheme.primary;
    }
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 3,
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
              ShimmerLoading(width: 150, height: 18),
              SizedBox(height: 12),
              ShimmerLoading(width: 90, height: 14),
              SizedBox(height: 8),
              ShimmerLoading(width: 120, height: 14),
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
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "MY ENTRY REQUESTS",
          style: GoogleFonts.oxanium(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('join_requests')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonList();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: "NO REQUESTS SUBMITTED",
              description: "You haven't requested entry for any tournaments yet. Join a match to get started!",
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final Color statusColor = _getStatusColor(status);

              return GlassCard(
                borderColor: statusColor,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            (data['tournamentTitle'] ?? '').toString().toUpperCase(),
                            style: GoogleFonts.oxanium(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.oxanium(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(color: Colors.white10, height: 20),

                    Text(
                      "In-Game Name: ${data['gameName'] ?? ''}",
                      style: const TextStyle(color: CyberTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "FF UID: ${data['ffUid'] ?? ''}",
                      style: const TextStyle(color: CyberTheme.textSecondary, fontSize: 13),
                    ),

                    if (data['paymentDetails'] != null && data['paymentDetails'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PAYMENT INSTRUCTIONS",
                              style: GoogleFonts.oxanium(
                                color: Colors.amberAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data['paymentDetails'],
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),


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