import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/core/widgets/empty_state.dart';
import 'package:herox/services/tournament_service.dart';
import 'package:herox/services/report_service.dart';

import 'package:herox/features/admin/screens/admin_management_screen.dart';
import 'package:herox/features/admin/screens/admin_deposit_requests_screen.dart';
import 'package:herox/features/admin/screens/admin_payment_config_screen.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tournament Controllers
  final titleController = TextEditingController();
  final entryFeeController = TextEditingController();
  final slotsController = TextEditingController();
  final prizeController = TextEditingController();
  String tournamentStatus = "upcoming";

  // Toggle for Reports vs Appeals
  String _activeReportToggle = "reports"; // reports or appeals

  // Stats State
  bool _loadingStats = false;
  Map<String, dynamic> _stats = {
    'players': 0,
    'tournaments': 0,
    'requests': 0,
    'approved': 0,
    'rejected': 0,
    'revenue': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refreshStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    titleController.dispose();
    entryFeeController.dispose();
    slotsController.dispose();
    prizeController.dispose();
    super.dispose();
  }

  Future<void> _refreshStats() async {
    setState(() => _loadingStats = true);
    try {
      final usersCount = await FirebaseFirestore.instance.collection('users').count().get();
      final tournamentsCount = await FirebaseFirestore.instance.collection('tournaments').count().get();
      final requestsCount = await FirebaseFirestore.instance.collection('join_requests').count().get();

      final approvedQuery = await FirebaseFirestore.instance
          .collection('join_requests')
          .where('status', isEqualTo: 'approved')
          .get();

      final rejectedQuery = await FirebaseFirestore.instance
          .collection('join_requests')
          .where('status', isEqualTo: 'rejected')
          .get();

      double revenue = 0;
      for (var doc in approvedQuery.docs) {
        final fee = doc.data()['entryFee'] ?? 0;
        revenue += (fee is int) ? fee.toDouble() : (double.tryParse(fee.toString()) ?? 0.0);
      }

      setState(() {
        _stats = {
          'players': usersCount.count,
          'tournaments': tournamentsCount.count,
          'requests': requestsCount.count,
          'approved': approvedQuery.docs.length,
          'rejected': rejectedQuery.docs.length,
          'revenue': revenue,
        };
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load statistics: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _handleCreateTournament() async {
    final title = titleController.text.trim();
    final entryFee = int.tryParse(entryFeeController.text) ?? 0;
    final slots = int.tryParse(slotsController.text) ?? 0;
    final prize = prizeController.text.trim();

    if (title.isEmpty || prize.isEmpty || slots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all tournament details")),
      );
      return;
    }

    try {
      await TournamentService.createTournament(
        title: title,
        entryFee: entryFee,
        totalSlots: slots,
        prizePool: prize,
        status: tournamentStatus,
        createdBy: FirebaseAuth.instance.currentUser!.uid,
      );

      titleController.clear();
      entryFeeController.clear();
      slotsController.clear();
      prizeController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tournament Created Successfully!")),
        );
      }
      _refreshStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to create tournament: $e")),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tournament deleted cleanly")),
          );
        }
        _refreshStats();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete tournament: $e")),
          );
        }
      }
    }
  }

  Future<void> _handleUpdateStatus(String id, String newStatus) async {
    try {
      await TournamentService.updateTournamentStatus(id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Status updated to $newStatus")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update status: $e")),
        );
      }
    }
  }

  // Dialog to publish Room Credentials
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
                    await FirebaseFirestore.instance.collection('admin_audit_logs').add({
                      'adminUid': currentUser.uid,
                      'adminEmail': currentUser.email ?? 'Unknown',
                      'action': 'PUBLISH_ROOM',
                      'details': "Published room ID '$roomId' & password for tournament '$title'",
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Room credentials published successfully")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
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

  // Dialog to submit Match Results
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
                    Navigator.pop(context); // Pop loading
                    Navigator.pop(context); // Pop dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Match results processed successfully!")),
                    );
                  }
                  _refreshStats();
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Pop loading
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

  // Ban Dialog with Expiry Duration options
  Future<void> _showBanConfirmationDialog(
    String userId,
    String userName,
    String reportId,
  ) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String durationOption = "permanent";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "BAN REASON",
                        hintText: "e.g. Cheating, abusing, toxic UID",
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Reason is required to ban a player.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "DURATION: ",
                          style: GoogleFonts.oxanium(color: CyberTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        DropdownButton<String>(
                          value: durationOption,
                          dropdownColor: CyberTheme.surface,
                          style: GoogleFonts.oxanium(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: "1h", child: Text("1 HOUR")),
                            DropdownMenuItem(value: "1d", child: Text("1 DAY")),
                            DropdownMenuItem(value: "7d", child: Text("7 DAYS")),
                            DropdownMenuItem(value: "30d", child: Text("30 DAYS")),
                            DropdownMenuItem(value: "permanent", child: Text("PERMANENT")),
                          ],
                          onChanged: (v) => setDialogState(() => durationOption = v!),
                        ),
                      ],
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
      },
    );

    if (confirm == true) {
      final reason = reasonController.text.trim();
      final admin = FirebaseAuth.instance.currentUser;
      if (admin == null) return;

      DateTime? expiry;
      final now = DateTime.now();
      switch (durationOption) {
        case "1h":
          expiry = now.add(const Duration(hours: 1));
          break;
        case "1d":
          expiry = now.add(const Duration(days: 1));
          break;
        case "7d":
          expiry = now.add(const Duration(days: 7));
          break;
        case "30d":
          expiry = now.add(const Duration(days: 30));
          break;
        default:
          expiry = null;
      }

      try {
        await ReportService.banUser(
          userId: userId,
          reason: reason,
          adminUid: admin.uid,
          adminEmail: admin.email ?? admin.uid,
          expiryDate: expiry,
        );
        await ReportService.markReportHandled(reportId);
        _refreshStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Player banned successfully & action logged.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to ban: $e")),
          );
        }
      }
    }
  }

  // Handle Approve/Reject Appeals
  Future<void> _handleProcessAppeal(String userId, String playerName, bool approve) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      if (approve) {
        batch.update(FirebaseFirestore.instance.collection('bans').doc(userId), {
          'banned': false,
          'appealStatus': 'approved',
        });
      } else {
        batch.update(FirebaseFirestore.instance.collection('bans').doc(userId), {
          'appealStatus': 'rejected',
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final logRef = FirebaseFirestore.instance.collection('admin_audit_logs').doc();
        batch.set(logRef, {
          'adminUid': currentUser.uid,
          'adminEmail': currentUser.email ?? 'Unknown',
          'action': approve ? 'APPROVE_APPEAL' : 'REJECT_APPEAL',
          'details': "${approve ? 'Approved' : 'Rejected'} ban appeal for player '$playerName' ($userId)",
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Appeal ${approve ? 'approved' : 'rejected'} successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to process appeal: $e")),
        );
      }
    }
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
              ShimmerLoading(width: 120, height: 14),
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
          "ADMIN PANEL",
          style: GoogleFonts.oxanium(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CyberTheme.primary,
          labelColor: CyberTheme.primary,
          unselectedLabelColor: CyberTheme.textSecondary,
          labelStyle: GoogleFonts.oxanium(fontWeight: FontWeight.bold, fontSize: 11),
          tabs: const [
            Tab(text: "ANALYTICS", icon: Icon(Icons.analytics_outlined)),
            Tab(text: "TOURNAMENTS", icon: Icon(Icons.emoji_events_outlined)),
            Tab(text: "REPORTS & APPEALS", icon: Icon(Icons.gavel_outlined)),
            Tab(text: "AUDIT LOGS", icon: Icon(Icons.history_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnalyticsTab(),
          _buildTournamentsTab(),
          _buildReportsAndAppealsTab(),
          _buildAuditLogsTab(),
        ],
      ),
    );
  }

  // TAB 1: Analytics Dashboard
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SYSTEM METRICS",
                style: GoogleFonts.oxanium(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: _loadingStats
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: CyberTheme.primary))
                    : const Icon(Icons.refresh, color: CyberTheme.primary),
                onPressed: _refreshStats,
              ),
            ],
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard("PLAYERS", _stats['players'].toString(), CyberTheme.primary),
              _buildMetricCard("MATCHES", _stats['tournaments'].toString(), CyberTheme.secondary),
              _buildMetricCard("JOIN REQUESTS", _stats['requests'].toString(), Colors.orangeAccent),
              _buildMetricCard("TOTAL REVENUE", "₹${_stats['revenue'].toStringAsFixed(0)}", Colors.greenAccent),
              _buildMetricCard("APPROVED ENTR.", _stats['approved'].toString(), Colors.tealAccent),
              _buildMetricCard("REJECTED ENTR.", _stats['rejected'].toString(), Colors.redAccent),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          Text(
            "MANAGEMENT CHANNELS",
            style: GoogleFonts.oxanium(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          GlassCard(
            borderColor: CyberTheme.primary,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: CyberTheme.primary),
                  title: Text("CREDIT DEPOSIT QUEUE", style: GoogleFonts.oxanium(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Approve/reject credit deposits and review receipts", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: CyberTheme.primary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminDepositRequestsScreen()),
                    );
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner, color: CyberTheme.primary),
                  title: Text("PAYMENT CHANNEL CONFIG", style: GoogleFonts.oxanium(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Configure eSewa ID and upload QR code", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: CyberTheme.primary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminPaymentConfigScreen()),
                    );
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined, color: CyberTheme.primary),
                  title: Text("ADMIN STAFF ROLES", style: GoogleFonts.oxanium(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Grant or revoke helper panel permissions", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: CyberTheme.primary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminManagementScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CyberTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.02),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.oxanium(
              color: accentColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.oxanium(color: CyberTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // TAB 2: Tournaments manager
  Widget _buildTournamentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            borderColor: CyberTheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "CREATE TOURNAMENT",
                  style: GoogleFonts.oxanium(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "MATCH TITLE"),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entryFeeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "ENTRY FEE (₹)"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: slotsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "MAX SLOTS"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: prizeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "PRIZE POOL DESC"),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "INITIAL STATUS: ",
                      style: GoogleFonts.oxanium(color: CyberTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: tournamentStatus,
                      dropdownColor: CyberTheme.surface,
                      style: GoogleFonts.oxanium(color: CyberTheme.primary, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: "upcoming", child: Text("UPCOMING")),
                        DropdownMenuItem(value: "live", child: Text("LIVE")),
                        DropdownMenuItem(value: "full", child: Text("FULL")),
                        DropdownMenuItem(value: "ended", child: Text("ENDED")),
                      ],
                      onChanged: (v) => setState(() => tournamentStatus = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                    onPressed: _handleCreateTournament,
                    child: Text("CREATE MATCH", style: GoogleFonts.oxanium(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            "ACTIVE TOURNAMENT LIST",
            style: GoogleFonts.oxanium(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tournaments')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: CyberTheme.primary));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text("No tournaments created yet.", style: TextStyle(color: CyberTheme.textSecondary))),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final d = doc.data() as Map<String, dynamic>;
                  final isEnded = d['status'] == 'ended';

                  return GlassCard(
                    borderColor: d['status'] == 'live' ? Colors.greenAccent : CyberTheme.surfaceLight,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (d['title'] ?? '').toString().toUpperCase(),
                          style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Slots: ${d['filledSlots']}/${d['totalSlots']}",
                              style: const TextStyle(color: CyberTheme.textSecondary, fontSize: 12),
                            ),
                            Text(
                              "Status: ${d['status']?.toString().toUpperCase()}",
                              style: TextStyle(
                                color: d['status'] == 'live' ? Colors.greenAccent : (isEnded ? Colors.redAccent : CyberTheme.textMuted),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        
                        if (!isEnded) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  side: const BorderSide(color: CyberTheme.secondary),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () => _showPublishRoomDialog(doc.id, d['title'] ?? ''),
                                child: Text("PUBLISH ROOM", style: GoogleFonts.oxanium(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  side: const BorderSide(color: Colors.greenAccent),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () => _showSubmitResultsDialog(doc.id, d['title'] ?? ''),
                                child: Text("SUBMIT RESULTS", style: GoogleFonts.oxanium(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text("UPDATE: ", style: TextStyle(fontSize: 11, color: CyberTheme.textMuted)),
                                DropdownButton<String>(
                                  value: d['status'],
                                  dropdownColor: CyberTheme.surface,
                                  style: GoogleFonts.oxanium(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  underline: Container(),
                                  items: const [
                                    DropdownMenuItem(value: "upcoming", child: Text("UPCOMING")),
                                    DropdownMenuItem(value: "live", child: Text("LIVE")),
                                    DropdownMenuItem(value: "full", child: Text("FULL")),
                                    DropdownMenuItem(value: "ended", child: Text("ENDED")),
                                  ],
                                  onChanged: (newStatus) => _handleUpdateStatus(doc.id, newStatus!),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                              onPressed: () => _handleDeleteTournament(doc.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // TAB 3: Reports & Appeals Manager
  Widget _buildReportsAndAppealsTab() {
    return Column(
      children: [
        // Segmented selector
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeReportToggle = "reports"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _activeReportToggle == "reports" ? CyberTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                      border: Border.all(
                        color: _activeReportToggle == "reports" ? CyberTheme.primary : Colors.white24,
                      ),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                    ),
                    child: Center(
                      child: Text(
                        "USER REPORTS",
                        style: GoogleFonts.oxanium(
                          color: _activeReportToggle == "reports" ? CyberTheme.primary : CyberTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeReportToggle = "appeals"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _activeReportToggle == "appeals" ? Colors.orangeAccent.withValues(alpha: 0.15) : Colors.transparent,
                      border: Border.all(
                        color: _activeReportToggle == "appeals" ? Colors.orangeAccent : Colors.white24,
                      ),
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                    ),
                    child: Center(
                      child: Text(
                        "BAN APPEALS",
                        style: GoogleFonts.oxanium(
                          color: _activeReportToggle == "appeals" ? Colors.orangeAccent : CyberTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _activeReportToggle == "reports" 
              ? _buildUserReportsList() 
              : _buildBanAppealsList(),
        ),
      ],
    );
  }

  Widget _buildUserReportsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonList();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyState(
            icon: Icons.flag_outlined,
            title: "NO INCIDENT REPORTS",
            description: "The arena is secure. There are currently no reports filed by players.",
          );
        }

        final reports = snapshot.data!.docs;

        return ListView.builder(
          itemCount: reports.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final r = reports[index].data() as Map<String, dynamic>;
            final reportId = reports[index].id;
            final isPending = r['status'] == 'pending';

            return GlassCard(
              borderColor: isPending ? CyberTheme.accent : CyberTheme.surfaceLight,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "FROM: ${r['fromName'] ?? 'Unknown'}",
                        style: GoogleFonts.oxanium(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPending ? CyberTheme.accent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (r['status'] ?? 'pending').toString().toUpperCase(),
                          style: GoogleFonts.oxanium(
                            color: isPending ? CyberTheme.accent : CyberTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "AGAINST: ${r['toName'] ?? 'Unknown'} (${r['toUserId'] ?? ''})",
                    style: const TextStyle(color: CyberTheme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    "REASON: ${r['reason'] ?? ''}",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),

                  if (isPending) ...[
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () {
                            final userId = r['toUserId'];
                            final userName = r['toName'] ?? 'Unknown';
                            if (userId != null) {
                              _showBanConfirmationDialog(userId, userName, reportId);
                            }
                          },
                          child: Text("BAN USER", style: GoogleFonts.oxanium(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            side: const BorderSide(color: CyberTheme.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () async {
                            await ReportService.markReportHandled(reportId);
                            _refreshStats();
                          },
                          child: Text("DISMISS", style: GoogleFonts.oxanium(fontSize: 10, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildBanAppealsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bans')
          .where('appealStatus', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonList();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyState(
            icon: Icons.mark_email_read_outlined,
            title: "NO BAN APPEALS",
            description: "There are no pending ban appeals to review.",
          );
        }

        final appeals = snapshot.data!.docs;

        return ListView.builder(
          itemCount: appeals.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final doc = appeals[index];
            final b = doc.data() as Map<String, dynamic>;
            final userId = doc.id;
            final reason = b['reason'] ?? 'N/A';
            final appealText = b['appealText'] ?? 'No message provided';
            
            return GlassCard(
              borderColor: Colors.orangeAccent,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "APPEAL FROM USER ID: $userId",
                    style: GoogleFonts.oxanium(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "BAN REASON: $reason",
                    style: const TextStyle(color: CyberTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "APPEAL MESSAGE:",
                          style: GoogleFonts.oxanium(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appealText,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Colors.greenAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _handleProcessAppeal(userId, userId, true),
                        child: Text("APPROVE (UNBAN)", style: GoogleFonts.oxanium(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _handleProcessAppeal(userId, userId, false),
                        child: Text("REJECT APPEAL", style: GoogleFonts.oxanium(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // TAB 4: Audit Logs Tab
  Widget _buildAuditLogsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_audit_logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonList();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: "NO AUDIT LOGS",
            description: "No admin activities have been recorded yet.",
          );
        }

        final logs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: logs.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            final timestamp = log['timestamp'] as Timestamp?;
            final timeStr = timestamp != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toDate())
                : 'N/A';

            return GlassCard(
              borderColor: CyberTheme.surfaceLight,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        log['action'] ?? 'UNKNOWN_ACTION',
                        style: GoogleFonts.oxanium(
                          color: CyberTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(color: CyberTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    log['details'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Admin: ${log['adminEmail'] ?? 'Unknown'}",
                    style: const TextStyle(color: CyberTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}