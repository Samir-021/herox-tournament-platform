import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/three_d_glow_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/services/wallet_service.dart';

class AddCreditsScreen extends StatefulWidget {
  const AddCreditsScreen({super.key});

  @override
  State<AddCreditsScreen> createState() => _AddCreditsScreenState();
}

class _AddCreditsScreenState extends State<AddCreditsScreen> {
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);
    });
  }

  Future<void> _submitRequest(String userId, String userName) async {
    final amountText = _amountController.text.trim();
    final refText = _refController.text.trim();

    final double amount = double.tryParse(amountText) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid deposit amount")),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload your payment proof screenshot")),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      // 1. Upload screenshot to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('payment_screenshots/${userId}_$timestamp.jpg');
      await ref.putFile(_selectedImage!);
      final url = await ref.getDownloadURL();

      // 2. Submit request doc to Firestore
      await WalletService.submitDepositRequest(
        userId: userId,
        userName: userName,
        amount: amount,
        screenshotUrl: url,
        transactionRef: refText,
      );

      setState(() {
        _selectedImage = null;
        _amountController.clear();
        _refController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Deposit request submitted successfully. Awaiting Admin review.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission failed: ${e.toString().replaceAll("Exception: ", "")}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("eSewa ID Copied")),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.greenAccent;
      case "rejected":
        return Colors.redAccent;
      default:
        return CyberTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not authenticated")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "ADD CREDITS",
          style: GoogleFonts.oxanium(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberTheme.backgroundGradient),
        child: _isUploading
            ? const Center(child: CircularProgressIndicator(color: CyberTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stream eSewa ID/QR configured by admin
                    StreamBuilder<DocumentSnapshot>(
                      stream: WalletService.getPaymentConfigStream(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const ShimmerLoading(width: double.infinity, height: 260);
                        }

                        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                        final esewaId = data['esewaId'] ?? 'Not Configured';
                        final qrUrl = data['esewaQrUrl'] ?? '';

                        return ThreeDGlowCard(
                          glowColor: CyberTheme.primary,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "STEP 1: TRANSFER VIA ESEWA",
                                style: GoogleFonts.oxanium(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "eSewa ID: ",
                                    style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 13),
                                  ),
                                  Text(
                                    esewaId,
                                    style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16, color: CyberTheme.primary),
                                    onPressed: () => _copyToClipboard(esewaId),
                                  ),
                                ],
                              ),
                              if (qrUrl.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(8),
                                    child: Image.network(
                                      qrUrl,
                                      height: 180,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return const ShimmerLoading(width: 180, height: 180);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ).animate().fade(duration: CyberMotion.medium).slideY(begin: 0.1, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve),

                    const SizedBox(height: 20),

                    // Submit deposit request form
                    GlassCard(
                      borderColor: CyberTheme.secondary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "STEP 2: SUBMIT DEPOSIT DETAILS",
                            style: GoogleFonts.oxanium(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Divider(color: Colors.white10, height: 20),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: "DEPOSIT AMOUNT (₹)",
                              prefixIcon: Icon(Icons.monetization_on, color: CyberTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _refController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: "TRANSACTION REFERENCE ID",
                              hintText: "Optional transaction code",
                              prefixIcon: Icon(Icons.tag, color: CyberTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_selectedImage != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_selectedImage!, height: 160, width: double.infinity, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 12),
                          ],
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(color: CyberTheme.secondary, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt_outlined, size: 18, color: CyberTheme.secondary),
                            label: Text(
                              _selectedImage == null ? "UPLOAD TRANSFER SCREENSHOT" : "REPLACE SCREENSHOT",
                              style: GoogleFonts.oxanium(fontWeight: FontWeight.bold, color: CyberTheme.secondary, fontSize: 11),
                            ),
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
                              onPressed: () => _submitRequest(user.uid, user.displayName ?? 'Player'),
                              child: Text(
                                "SUBMIT DEPOSIT REQUEST",
                                style: GoogleFonts.oxanium(fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 100.ms, duration: CyberMotion.medium).slideY(begin: 0.1, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve),

                    const SizedBox(height: 24),

                    // Deposit history tracking
                    Text(
                      "MY DEPOSIT HISTORY",
                      style: GoogleFonts.oxanium(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ).animate().fade(delay: 200.ms),
                    const SizedBox(height: 12),

                    StreamBuilder<QuerySnapshot>(
                      stream: WalletService.getPlayerDepositRequestsStream(user.uid),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const ShimmerLoading(width: double.infinity, height: 60);
                        }

                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: CyberTheme.surface.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Center(
                              child: Text(
                                "No deposit requests submitted yet.",
                                style: TextStyle(color: CyberTheme.textSecondary, fontSize: 12),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;

                            final double amount = (data['amount'] ?? 0.0) as double;
                            final String status = data['status'] ?? 'pending';
                            final Timestamp? ts = data['createdAt'] as Timestamp?;
                            final Color statusColor = _getStatusColor(status);

                            return GlassCard(
                              borderColor: statusColor,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: statusColor.withValues(alpha: 0.12),
                                    radius: 16,
                                    child: Icon(
                                      status == 'approved' ? Icons.check : (status == 'rejected' ? Icons.close : Icons.hourglass_empty),
                                      color: statusColor,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Request for ₹${amount.toStringAsFixed(1)}",
                                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        if (ts != null)
                                          Text(
                                            "${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} - ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}",
                                            style: const TextStyle(color: CyberTheme.textMuted, fontSize: 10),
                                          ),
                                        if (status == 'rejected' && data['rejectionReason'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              "Reason: ${data['rejectionReason']}",
                                              style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 11),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.oxanium(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ).animate().fade(delay: 300.ms),
                  ],
                ),
              ),
      ),
    );
  }
}
