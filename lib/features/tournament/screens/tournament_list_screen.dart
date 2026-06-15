import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/core/widgets/empty_state.dart';
import 'package:herox/services/tournament_service.dart';
import 'tournament_detail_screen.dart';

class TournamentListScreen extends StatelessWidget {
  const TournamentListScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'live':
        return Colors.greenAccent;
      case 'upcoming':
        return CyberTheme.primary;
      case 'full':
        return CyberTheme.secondary;
      case 'ended':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CyberTheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLoading(width: 180, height: 20),
              SizedBox(height: 12),
              ShimmerLoading(width: 120, height: 14),
              SizedBox(height: 8),
              ShimmerLoading(width: 140, height: 14),
              SizedBox(height: 8),
              ShimmerLoading(width: 90, height: 14),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "TOURNAMENTS",
          style: GoogleFonts.oxanium(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: TournamentService.getTournamentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonList();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: "NO MATCHES SCHEDULED",
              description: "The arena is currently quiet. Check back later for upcoming matches!",
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String status = data['status'] ?? 'upcoming';
              final Color statusColor = _getStatusColor(status);

              return Hero(
                tag: 'tournament_hero_${doc.id}',
                child: GlassCard(
                  borderColor: statusColor,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TournamentDetailScreen(
                          tournamentId: doc.id,
                          data: data,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (data['title'] ?? '').toString().toUpperCase(),
                              style: GoogleFonts.oxanium(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: GoogleFonts.oxanium(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("PRIZE POOL", style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(
                                "₹${data['prizePool'] ?? '0'}",
                                style: GoogleFonts.oxanium(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("ENTRY FEE", style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(
                                data['entryFee'] == 0 ? "FREE" : "₹${data['entryFee']}",
                                style: GoogleFonts.oxanium(
                                  color: data['entryFee'] == 0 ? Colors.greenAccent : Colors.amber,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("SLOTS FILLED", style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(
                                "${data['filledSlots'] ?? 0}/${data['totalSlots'] ?? 0}",
                                style: GoogleFonts.oxanium(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}