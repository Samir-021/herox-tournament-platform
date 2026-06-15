import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/three_d_glow_card.dart';
import 'package:herox/services/auth_service.dart';

class SuspendedScreen extends StatefulWidget {
  final String reason;
  final Map<String, dynamic> banDetails;
  final String userId;

  const SuspendedScreen({
    super.key,
    required this.reason,
    required this.banDetails,
    required this.userId,
  });

  @override
  State<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends State<SuspendedScreen> {
  final _appealController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _appealController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await AuthService.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged out successfully")),
      );
    }
  }

  Future<void> _submitAppeal() async {
    final text = _appealController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your appeal message.")),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance.collection('bans').doc(widget.userId).update({
        'appealStatus': 'pending',
        'appealText': text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appeal submitted successfully. We will review it shortly.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit appeal: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showAppealDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: CyberTheme.surface,
              title: Text(
                "SUBMIT BAN APPEAL",
                style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Explain why your ban should be lifted. Provide any relevant details honestly.",
                    style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _appealController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: "Enter your appeal message here...",
                      alignLabelWithHint: true,
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
                  onPressed: _submitting
                      ? null
                      : () async {
                          setDialogState(() => _submitting = true);
                          await _submitAppeal();
                          setDialogState(() => _submitting = false);
                        },
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("SUBMIT"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    final banDate = widget.banDetails['bannedAt'];
    final expiryDate = widget.banDetails['expiryDate'];
    final appealStatus = widget.banDetails['appealStatus'] ?? 'none';
    final appealText = widget.banDetails['appealText'] ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: CyberTheme.backgroundGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ThreeDGlowCard(
              glowColor: Colors.redAccent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gavel, color: Colors.redAccent, size: 70),
                  const SizedBox(height: 16),
                  Text(
                    "ACCESS SUSPENDED",
                    style: GoogleFonts.oxanium(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  
                  // Detailed Ban Stats
                  _buildBanDetailRow("REASON", widget.reason.isNotEmpty ? widget.reason : "Violation of community guidelines"),
                  _buildBanDetailRow("BAN DATE", _formatTimestamp(banDate)),
                  _buildBanDetailRow("EXPIRY DATE", expiryDate != null ? _formatTimestamp(expiryDate) : "PERMANENT"),
                  _buildBanDetailRow(
                    "APPEAL STATUS", 
                    appealStatus.toString().toUpperCase(), 
                    color: appealStatus == 'pending' 
                        ? Colors.orangeAccent 
                        : (appealStatus == 'approved' ? Colors.greenAccent : (appealStatus == 'rejected' ? Colors.redAccent : CyberTheme.textSecondary))
                  ),

                  if (appealStatus == 'pending') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Your appeal is currently under review by admin staff. Please wait patiently.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 12),
                          ),
                          if (appealText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              "Your appeal message:\n\"$appealText\"",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.orangeAccent.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (appealStatus == 'rejected') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        "Your appeal was rejected. The ban remains active.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => _handleSignOut(context),
                          child: Text("SIGN OUT", style: GoogleFonts.oxanium(color: CyberTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      if (appealStatus == 'none') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _showAppealDialog,
                            child: Text(
                              "APPEAL BAN",
                              style: GoogleFonts.oxanium(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).scale(
              begin: const Offset(0.99, 0.99),
              end: const Offset(1.01, 1.01),
              duration: 1500.ms,
              curve: Curves.easeInOutSine,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanDetailRow(String label, String value, {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.oxanium(
                color: CyberTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
