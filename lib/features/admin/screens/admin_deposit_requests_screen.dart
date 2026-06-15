import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/core/widgets/empty_state.dart';
import 'package:herox/services/wallet_service.dart';

class AdminDepositRequestsScreen extends StatefulWidget {
  const AdminDepositRequestsScreen({super.key});

  @override
  State<AdminDepositRequestsScreen> createState() => _AdminDepositRequestsScreenState();
}

class _AdminDepositRequestsScreenState extends State<AdminDepositRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _approveRequest(String requestId, String userId, double amount, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberTheme.surface,
        title: const Text("APPROVE DEPOSIT?"),
        content: Text("Are you sure you want to approve ₹$amount credits for $userName? This will update their wallet balance atomically."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: CyberTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("APPROVE", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await WalletService.approveDepositRequest(
        requestId: requestId,
        userId: userId,
        amount: amount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Deposit request approved and wallet updated!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Approval failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectRequest(String requestId, String userName) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberTheme.surface,
        title: const Text("REJECT DEPOSIT?"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Provide a rejection reason for player '$userName'."),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "REJECTION REASON",
                  hintText: "e.g. Screenshot blurred, incorrect amount",
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Reason is required to reject.";
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
            style: ElevatedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text("REJECT", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final reason = reasonController.text.trim();
    setState(() => _isProcessing = true);
    try {
      await WalletService.rejectDepositRequest(
        requestId: requestId,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Deposit request rejected.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rejection failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 3,
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
          "CREDIT DEPOSITS QUEUE",
          style: GoogleFonts.oxanium(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CyberTheme.primary,
          labelColor: CyberTheme.primary,
          unselectedLabelColor: CyberTheme.textSecondary,
          labelStyle: GoogleFonts.oxanium(fontWeight: FontWeight.bold, fontSize: 11),
          tabs: const [
            Tab(text: "PENDING REQUESTS", icon: Icon(Icons.pending_actions_outlined)),
            Tab(text: "PROCESSED HISTORY", icon: Icon(Icons.history_toggle_off_outlined)),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberTheme.backgroundGradient),
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator(color: CyberTheme.primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildQueueTab(pending: true),
                  _buildQueueTab(pending: false),
                ],
              ),
      ),
    );
  }

  Widget _buildQueueTab({required bool pending}) {
    final Stream<QuerySnapshot> stream = pending
        ? WalletService.getPendingDepositRequestsStream()
        : WalletService.getProcessedDepositRequestsStream();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonList();
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return EmptyState(
            icon: pending ? Icons.done_all_outlined : Icons.history_outlined,
            title: pending ? "NO PENDING DEPOSITS" : "NO DEPOSIT HISTORY",
            description: pending
                ? "All player deposit requests have been approved or rejected."
                : "No deposits have been processed yet.",
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final String userName = data['userName'] ?? 'Player';
            final String userId = data['userId'] ?? '';
            final double amount = (data['amount'] ?? 0.0) as double;
            final String screenshot = data['screenshotUrl'] ?? '';
            final String ref = data['transactionRef'] ?? '';
            final String status = data['status'] ?? 'pending';
            final Timestamp? ts = data['createdAt'] as Timestamp?;

            Color statusColor = CyberTheme.primary;
            if (status == 'approved') statusColor = Colors.greenAccent;
            if (status == 'rejected') statusColor = Colors.redAccent;

            return GlassCard(
              borderColor: statusColor,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        userName.toUpperCase(),
                        style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
                          style: GoogleFonts.oxanium(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Deposit Amount:",
                        style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 13),
                      ),
                      Text(
                        "₹${amount.toStringAsFixed(1)}",
                        style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  if (ref.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "eSewa Transaction Ref:",
                          style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 13),
                        ),
                        Text(
                          ref,
                          style: GoogleFonts.oxanium(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  if (ts != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Submitted At:",
                          style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 12),
                        ),
                        Text(
                          "${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} - ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(color: CyberTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                  if (status == 'rejected' && data['rejectionReason'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        "Rejection Reason: ${data['rejectionReason']}",
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                  if (screenshot.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "PAYMENT RECEIPT SCREENSHOT:",
                      style: GoogleFonts.oxanium(color: CyberTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: GestureDetector(
                        onTap: () {
                          // Display full screen screenshot preview
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: InteractiveViewer(
                                child: Image.network(screenshot, fit: BoxFit.contain),
                              ),
                            ),
                          );
                        },
                        child: Image.network(
                          screenshot,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const ShimmerLoading(width: double.infinity, height: 180);
                          },
                        ),
                      ),
                    ),
                  ],
                  if (pending) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _rejectRequest(doc.id, userName),
                            icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                            label: Text(
                              "REJECT",
                              style: GoogleFonts.oxanium(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(color: Colors.greenAccent, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _approveRequest(doc.id, userId, amount, userName),
                            icon: const Icon(Icons.check, size: 16, color: Colors.greenAccent),
                            label: Text(
                              "APPROVE",
                              style: GoogleFonts.oxanium(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ).animate().fade(delay: (index * 40).ms, duration: CyberMotion.medium).slideY(begin: 0.05, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve);
          },
        );
      },
    );
  }
}
