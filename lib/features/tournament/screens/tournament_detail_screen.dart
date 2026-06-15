import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/three_d_glow_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/services/tournament_service.dart';
import 'package:herox/services/report_service.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  final Map<String, dynamic> data;

  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    required this.data,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  Timer? _countdownTimer;
  Duration _timeLeft = const Duration(hours: 2, minutes: 30);

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    super.dispose();
  }

  void _startCountdown() {
    final Timestamp? created = widget.data['createdAt'] as Timestamp?;
    DateTime startTarget;
    if (created != null) {
      // Mock match start: 24 hours after creation
      startTarget = created.toDate().add(const Duration(hours: 24));
    } else {
      startTarget = DateTime.now().add(const Duration(hours: 2, minutes: 30));
    }

    final diff = startTarget.difference(DateTime.now());
    if (diff.isNegative) {
      _timeLeft = Duration.zero;
    } else {
      _timeLeft = diff;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        final currentDiff = startTarget.difference(DateTime.now());
        if (currentDiff.isNegative) {
          _timeLeft = Duration.zero;
          _countdownTimer?.cancel();
        } else {
          _timeLeft = currentDiff;
        }
      });
    });
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return "LIVE";
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied to Clipboard")),
    );
  }

  void showReportDialog(
    BuildContext context,
    String reportedUserId,
    String reportedUserName,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: CyberTheme.surface,
          title: Text(
            "REPORT PLAYER",
            style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Reason (cheating, toxicity, faking UID)",
              prefixIcon: Icon(Icons.warning_amber, color: CyberTheme.accent),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>  Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: CyberTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                side: const BorderSide(color: CyberTheme.accent, width: 1.5),
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();

                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a reason")),
                  );
                  return;
                }

                try {
                  await ReportService.reportUser(
                    reportedUserId: reportedUserId,
                    reason: reason,
                    tournamentId: widget.tournamentId,
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Report submitted successfully")),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to submit report: ${e.toString().replaceAll("Exception: ", "")}")),
                  );
                }
              },
              child: const Text("SUBMIT REPORT", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleJoinRequest(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final entryFee = int.tryParse(widget.data['entryFee']?.toString() ?? '0') ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CyberTheme.surface,
          title: Text(
            "REGISTER FOR MATCH?",
            style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to register for '${widget.data['title'] ?? 'this tournament'}'? The entry fee of ₹$entryFee will be deducted from your wallet balance.",
            style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: CyberTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("CONFIRM"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: CyberTheme.primary)),
    );

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final ffUid = (userData?['freeFireUid'] ?? '').toString().trim();
      final gameName = (userData?['gameName'] ?? '').toString().trim();

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
      }

      if (ffUid.isEmpty || gameName.isEmpty) {
        if (context.mounted) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please complete your profile first")),
          );
        }
        return;
      }

      await TournamentService.joinTournamentDirectly(
        tournamentId: widget.tournamentId,
        tournamentTitle: widget.data['title'] ?? '',
        userId: user.uid,
        playerName: user.displayName ?? 'Player',
        gameName: gameName,
        ffUid: ffUid,
        entryFee: entryFee,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully registered and joined the tournament!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        if (!context.mounted) return;
        Navigator.pop(context); // Pop loader if still showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration failed: ${e.toString().replaceAll("Exception: ", "")}")),
        );
      }
    }
  }

  Future<void> _handleDeleteTournament(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberTheme.surface,
        title: const Text("DELETE TOURNAMENT?"),
        content: const Text("This will delete all subcollections and requests associated with this tournament recursively."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: CyberTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(side: const BorderSide(color: CyberTheme.accent)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await TournamentService.deleteTournament(id);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tournament deleted cleanly")),
        );

        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete tournament: $e")),
        );
      }
    }
  }

  Future<void> _showPublishRoomDialog(String tournamentId, String title) async {
    final roomIdController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CyberTheme.surface,
          title: Text(
            "PUBLISH ROOM CREDENTIALS",
            style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Tournament: $title",
                style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roomIdController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "ROOM ID"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "ROOM PASSWORD"),
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
                final roomId = roomIdController.text.trim();
                final password = passwordController.text.trim();
                if (roomId.isEmpty || password.isEmpty) return;

                try {
                  await FirebaseFirestore.instance.collection('rooms').doc(tournamentId).set({
                    'tournamentId': tournamentId,
                    'roomId': roomId,
                    'roomPassword': password,
                    'publishedAt': FieldValue.serverTimestamp(),
                  });

                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                    final isAdminUser = userDoc.data()?['role'] == 'admin';
                    if (isAdminUser) {
                      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
                        'adminUid': currentUser.uid,
                        'adminEmail': currentUser.email ?? 'Unknown',
                        'action': 'PUBLISH_ROOM',
                        'details': "Published room ID '$roomId' & password for tournament '$title'",
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                    }
                  }

                  if (context.mounted) {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Room credentials published successfully")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to publish room: $e")),
                    );
                  }
                }
              },
              child: const Text("PUBLISH"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSubmitResultsDialog(String tournamentId, String title) async {
    final participantsSnap = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournamentId)
        .collection('participants')
        .get();

    if (participantsSnap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No participants registered for this tournament")),
        );
      }
      return;
    }

    final rankControllers = <String, TextEditingController>{};
    final killsControllers = <String, TextEditingController>{};
    final payoutControllers = <String, TextEditingController>{};

    for (var doc in participantsSnap.docs) {
      rankControllers[doc.id] = TextEditingController();
      killsControllers[doc.id] = TextEditingController();
      payoutControllers[doc.id] = TextEditingController();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CyberTheme.surface,
          title: Text(
            "SUBMIT MATCH RESULTS",
            style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: participantsSnap.docs.length,
              itemBuilder: (context, index) {
                final pDoc = participantsSnap.docs[index];
                final pData = pDoc.data();
                final pName = pData['name'] ?? 'Player';
                final pUid = pDoc.id;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pName.toUpperCase(),
                        style: GoogleFonts.oxanium(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: rankControllers[pUid],
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: "Rank",
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: killsControllers[pUid],
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: "Kills",
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: payoutControllers[pUid],
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: "Payout (₹)",
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: CyberTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator(color: CyberTheme.primary)),
                );

                try {
                  final List<Map<String, dynamic>> resultsList = [];

                  for (var doc in participantsSnap.docs) {
                    final pUid = doc.id;
                    final pData = doc.data();
                    final pName = pData['name'] ?? 'Player';

                    final rank = int.tryParse(rankControllers[pUid]!.text) ?? 0;
                    final kills = int.tryParse(killsControllers[pUid]!.text) ?? 0;
                    final payout = double.tryParse(payoutControllers[pUid]!.text) ?? 0.0;

                    resultsList.add({
                      'userId': pUid,
                      'userName': pName,
                      'rank': rank,
                      'kills': kills,
                      'payout': payout,
                    });
                  }

                  await TournamentService.submitMatchResults(
                    tournamentId: tournamentId,
                    tournamentTitle: title,
                    results: resultsList,
                  );

                  if (context.mounted) {
                    if (!context.mounted) return;
                    Navigator.pop(context); // Pop loading
                    Navigator.pop(context); // Pop dialog
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Match results processed successfully!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    if (!context.mounted) return;
                    Navigator.pop(context); // Pop loading
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Submission failed: $e")),
                    );
                  }
                }
              },
              child: const Text("SUBMIT RESULTS"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticipantsSkeleton() {
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
              ShimmerLoading(width: 30, height: 30, borderRadius: 15),
              SizedBox(width: 12),
              ShimmerLoading(width: 100, height: 16),
              Spacer(),
              ShimmerLoading(width: 110, height: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] ?? 'upcoming';
    final teamMode = widget.data['teamMode'] ?? 'Squad'; // Solo/Duo/Squad

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "TOURNAMENT DETAILS",
          style: GoogleFonts.oxanium(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Hero(
        tag: 'tournament_hero_${widget.tournamentId}',
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                ThreeDGlowCard(
                  glowColor: CyberTheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (widget.data['title'] ?? '').toString().toUpperCase(),
                              style: GoogleFonts.oxanium(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: CyberTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: CyberTheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              teamMode.toString().toUpperCase(),
                              style: GoogleFonts.oxanium(color: CyberTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailStat("ENTRY FEE", widget.data['entryFee'] == 0 ? "FREE" : "₹${widget.data['entryFee']}", widget.data['entryFee'] == 0 ? Colors.greenAccent : Colors.amber),
                          _buildDetailStat("PRIZE POOL", "₹${widget.data['prizePool'] ?? 0}", Colors.white),
                          _buildDetailStat("FILLED SLOTS", "${widget.data['filledSlots'] ?? 0}/${widget.data['totalSlots'] ?? 0}", CyberTheme.primary),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                "STATUS: ",
                                style: GoogleFonts.oxanium(color: CyberTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                status.toString().toUpperCase(),
                                style: GoogleFonts.oxanium(
                                  color: status == 'live' ? Colors.greenAccent : (status == 'upcoming' ? CyberTheme.primary : Colors.redAccent),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.timer, color: Colors.amberAccent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _timeLeft == Duration.zero ? "MATCH LIVE" : "STARTS IN: ${_formatDuration(_timeLeft)}",
                                style: GoogleFonts.oxanium(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade(duration: CyberMotion.medium).slideY(begin: 0.1, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve),

                const SizedBox(height: 20),

                // Creator Management Panel (visible to host/creator or admin)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, userSnap) {
                    if (userSnap.hasError || !userSnap.hasData || !userSnap.data!.exists) {
                      return const SizedBox.shrink();
                    }
                    final userData = userSnap.data!.data() as Map<String, dynamic>?;
                    final userRole = userData?['role'] ?? 'player';
                    final isCreator = widget.data['createdBy'] == FirebaseAuth.instance.currentUser?.uid;
                    final isAdmin = userRole == 'admin';

                    if (isCreator || isAdmin) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: ThreeDGlowCard(
                          glowColor: CyberTheme.primary,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.settings_suggest_outlined, color: CyberTheme.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "CREATOR MANAGEMENT CONTROLS",
                                    style: GoogleFonts.oxanium(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white10, height: 20),
                              Text(
                                "As the host or an administrator of this tournament, you can manage the room configurations, placements, and settings.",
                                style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        side: const BorderSide(color: CyberTheme.primary, width: 1.5),
                                      ),
                                      icon: const Icon(Icons.vpn_key_outlined, size: 16),
                                      label: Text("ROOM ID/PASS", style: GoogleFonts.oxanium(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => _showPublishRoomDialog(widget.tournamentId, widget.data['title'] ?? ''),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        side: const BorderSide(color: Colors.greenAccent, width: 1.5),
                                      ),
                                      icon: const Icon(Icons.emoji_events_outlined, size: 16, color: Colors.greenAccent),
                                      label: Text("SUBMIT RESULTS", style: GoogleFonts.oxanium(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                      onPressed: () => _showSubmitResultsDialog(widget.tournamentId, widget.data['title'] ?? ''),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                  ),
                                  icon: const Icon(Icons.delete_forever_outlined, size: 16, color: Colors.redAccent),
                                  label: Text("DELETE TOURNAMENT", style: GoogleFonts.oxanium(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                  onPressed: () => _handleDeleteTournament(widget.tournamentId),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(duration: CyberMotion.medium).slideY(begin: 0.1, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve);
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Secure Room Card (visible to approved players only)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tournaments')
                      .doc(widget.tournamentId)
                      .collection('participants')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, participantSnap) {
                    if (participantSnap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Text(
                          "Error: ${participantSnap.error}",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }
                    if (participantSnap.hasData && participantSnap.data!.exists) {
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(widget.tournamentId)
                            .snapshots(),
                        builder: (context, roomSnap) {
                          if (roomSnap.hasError) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Text(
                                "Error loading room credentials: ${roomSnap.error}",
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            );
                          }
                          final hasRoom = roomSnap.hasData && roomSnap.data!.exists;
                          final roomData = hasRoom ? roomSnap.data!.data() as Map<String, dynamic>? : null;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: ThreeDGlowCard(
                              glowColor: CyberTheme.secondary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.vpn_key_outlined, color: CyberTheme.secondary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "MATCH ROOM ID & PASSWORD",
                                        style: GoogleFonts.oxanium(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white10, height: 20),
                                  if (hasRoom && roomData != null) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("ROOM ID", style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 10)),
                                              Text(
                                                roomData['roomId'] ?? 'N/A',
                                                style: GoogleFonts.oxanium(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, color: CyberTheme.textSecondary, size: 16),
                                          onPressed: () => copyToClipboard(context, roomData['roomId'] ?? ''),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("PASSWORD", style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 10)),
                                              Text(
                                                roomData['roomPassword'] ?? 'N/A',
                                                style: GoogleFonts.oxanium(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, color: CyberTheme.textSecondary, size: 16),
                                          onPressed: () => copyToClipboard(context, roomData['roomPassword'] ?? ''),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Text(
                                      "ROOM IS NOT PUBLISHED YET",
                                      style: GoogleFonts.oxanium(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Credentials will be posted here by the host/admin 15-30 minutes before the tournament start time.",
                                      style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ).animate().fade(duration: CyberMotion.medium).slideY(begin: 0.1, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve);
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text(
                    "PARTICIPANTS LOG",
                    style: GoogleFonts.oxanium(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tournaments')
                      .doc(widget.tournamentId)
                      .collection('participants')
                      .orderBy('slotNumber')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "Error loading participants: ${snapshot.error}",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildParticipantsSkeleton();
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: CyberTheme.surface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: const Center(
                          child: Text(
                            "No players joined yet. Be the first!",
                            style: TextStyle(color: CyberTheme.textSecondary, fontSize: 13),
                          ),
                        ),
                      ).animate().fade(delay: 150.ms);
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final p = docs[index].data() as Map<String, dynamic>;
                        final ffUid = p['ffUid'] ?? 'Not Set';
                        final user = FirebaseAuth.instance.currentUser;

                        return GlassCard(
                          borderColor: CyberTheme.surfaceLight,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: CyberTheme.primary.withValues(alpha: 0.2),
                                child: Text(
                                  "${p['slotNumber']}",
                                  style: GoogleFonts.oxanium(
                                    color: CyberTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  p['name'] ?? "Player",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),

                              GestureDetector(
                                onTap: () => copyToClipboard(context, ffUid),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "UID: $ffUid",
                                        style: GoogleFonts.outfit(
                                          color: CyberTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy, color: CyberTheme.textMuted, size: 11),
                                    ],
                                  ),
                                ),
                              ),

                              if (p['uid'] != null && p['uid'] != user?.uid)
                                IconButton(
                                  icon: const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                                  tooltip: "Report Cheating/Abuse",
                                  onPressed: () {
                                    showReportDialog(
                                      context,
                                      p['uid'],
                                      p['name'] ?? 'Player',
                                    );
                                  },
                                ),
                            ],
                          ),
                        ).animate().fade(delay: (CyberMotion.medium.inMilliseconds + (index * 40)).ms, duration: CyberMotion.medium).slideY(begin: 0.05, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve);
                      },
                    );
                  },
                ),

                const SizedBox(height: 30),

                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tournaments')
                      .doc(widget.tournamentId)
                      .collection('participants')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, registeredSnap) {
                    final isRegistered = registeredSnap.hasData && registeredSnap.data!.exists;

                    if (isRegistered) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            "ALREADY REGISTERED",
                            style: GoogleFonts.oxanium(
                              color: Colors.greenAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ).animate().fade(delay: 300.ms);
                    }

                    if (status == 'upcoming' || status == 'live') {
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: Container(
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
                            onPressed: () => _handleJoinRequest(context),
                            child: Text(
                              "REQUEST ARENA ENTRY",
                              style: GoogleFonts.oxanium(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ).animate().fade(delay: 300.ms);
                    } else {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Center(
                          child: Text(
                            "REGISTRATION CLOSED",
                            style: GoogleFonts.oxanium(
                              color: CyberTheme.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ).animate().fade(delay: 300.ms);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.oxanium(
            color: CyberTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.oxanium(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}