import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/glass_card.dart';
import 'package:herox/core/widgets/shimmer_loading.dart';
import 'package:herox/services/wallet_service.dart';

class AdminPaymentConfigScreen extends StatefulWidget {
  const AdminPaymentConfigScreen({super.key});

  @override
  State<AdminPaymentConfigScreen> createState() => _AdminPaymentConfigScreenState();
}

class _AdminPaymentConfigScreenState extends State<AdminPaymentConfigScreen> {
  final _esewaIdController = TextEditingController();
  String? _qrUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _esewaIdController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final snap = await WalletService.getPaymentConfig();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>? ?? {};
        _esewaIdController.text = data['esewaId'] ?? '';
        setState(() {
          _qrUrl = data['esewaQrUrl'];
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadQR() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isSaving = true);
    try {
      final file = File(image.path);
      final ref = FirebaseStorage.instance.ref().child('payment_config/esewa_qr.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      setState(() {
        _qrUrl = url;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("eSewa QR Code image uploaded successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("QR Upload failed: $e")),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveConfig() async {
    final id = _esewaIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("eSewa ID cannot be empty")),
      );
      return;
    }
    if (_qrUrl == null || _qrUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload an eSewa QR Code image")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await WalletService.updatePaymentConfig(id, _qrUrl!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("eSewa payment configuration saved")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save config: $e")),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "PAYMENT CHANNEL CONFIG",
          style: GoogleFonts.oxanium(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberTheme.backgroundGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: CyberTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      borderColor: CyberTheme.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payment, color: CyberTheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "ESEWA CHANNEL CONFIG",
                                style: GoogleFonts.oxanium(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 24),
                          Text(
                            "Configure the eSewa details below. Players will copy this ID or scan the QR Code externally to pay and request credits.",
                            style: GoogleFonts.outfit(color: CyberTheme.textSecondary, fontSize: 12, height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _esewaIdController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: "ADMIN ESEWA ID / PHONE",
                              hintText: "Enter eSewa registration phone number",
                              prefixIcon: Icon(Icons.account_box, color: CyberTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "ADMIN ESEWA QR CODE GRAPHIC",
                            style: GoogleFonts.oxanium(
                              color: CyberTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_qrUrl != null && _qrUrl!.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(12),
                                alignment: Alignment.center,
                                child: Image.network(
                                  _qrUrl!,
                                  height: 220,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const ShimmerLoading(width: 220, height: 220);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(color: CyberTheme.secondary, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isSaving ? null : _pickAndUploadQR,
                            icon: const Icon(Icons.qr_code_scanner, size: 18, color: CyberTheme.secondary),
                            label: Text(
                              _qrUrl == null ? "UPLOAD QR CODE IMAGE" : "REPLACE QR CODE IMAGE",
                              style: GoogleFonts.oxanium(fontWeight: FontWeight.bold, color: CyberTheme.secondary),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: CyberMotion.medium).slideY(begin: 0.1, duration: CyberMotion.medium, curve: CyberMotion.snappyCurve),
                    const SizedBox(height: 24),
                    if (_isSaving)
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _saveConfig,
                          child: Text(
                            "SAVE CONFIGURATION",
                            style: GoogleFonts.oxanium(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ).animate().fade(delay: 200.ms),
                  ],
                ),
              ),
      ),
    );
  }
}
