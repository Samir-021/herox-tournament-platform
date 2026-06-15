import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:herox/core/theme/cyber_theme.dart';
import 'package:herox/core/widgets/three_d_glow_card.dart';
import 'package:herox/services/tournament_service.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _slotsController = TextEditingController();
  final _prizePoolController = TextEditingController();
  
  String _selectedStatus = 'upcoming';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _entryFeeController.dispose();
    _slotsController.dispose();
    _prizePoolController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final entryFee = int.tryParse(_entryFeeController.text) ?? 0;
    final totalSlots = int.tryParse(_slotsController.text) ?? 0;
    final prizePool = _prizePoolController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: You must be logged in to create a tournament.")),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      await TournamentService.createTournament(
        title: title,
        entryFee: entryFee,
        totalSlots: totalSlots,
        prizePool: prizePool,
        status: _selectedStatus,
        createdBy: currentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tournament created successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to create tournament: ${e.toString().replaceAll("Exception: ", "")}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "HOST TOURNAMENT",
          style: GoogleFonts.oxanium(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: CyberTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ThreeDGlowCard(
                    glowColor: CyberTheme.primary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ARENA DETAILS",
                          style: GoogleFonts.oxanium(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Set up your custom esports room rules below. Users will be able to register instantly.",
                          style: GoogleFonts.outfit(
                            color: CyberTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 24),
                        
                        // Tournament Title
                        TextFormField(
                          controller: _titleController,
                          maxLength: 100,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "TOURNAMENT TITLE",
                            prefixIcon: Icon(Icons.emoji_events_outlined, color: CyberTheme.primary),
                            hintText: "e.g. Free Fire Duo Showdown",
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter a tournament title";
                            }
                            if (value.trim().length < 3) {
                              return "Title must be at least 3 characters";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Entry Fee
                        TextFormField(
                          controller: _entryFeeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "ENTRY FEE (INR)",
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: CyberTheme.primary),
                            suffixText: "₹",
                            suffixStyle: TextStyle(color: CyberTheme.primary, fontWeight: FontWeight.bold),
                            hintText: "0 for Free Entry",
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter an entry fee";
                            }
                            final fee = int.tryParse(value);
                            if (fee == null || fee < 0) {
                              return "Enter a valid positive number";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Total Slots
                        TextFormField(
                          controller: _slotsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "MAX PLAYERS / SLOTS",
                            prefixIcon: Icon(Icons.groups_outlined, color: CyberTheme.primary),
                            hintText: "e.g. 48",
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter max slots";
                            }
                            final slots = int.tryParse(value);
                            if (slots == null || slots <= 0) {
                              return "Enter a valid number greater than 0";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Prize Pool
                        TextFormField(
                          controller: _prizePoolController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "PRIZE POOL DESCRIPTION",
                            prefixIcon: Icon(Icons.wallet_giftcard_outlined, color: CyberTheme.primary),
                            hintText: "e.g. ₹500 Total Prize Pool (Rank 1: ₹300, Rank 2: ₹200)",
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter prize pool details";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Status Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          dropdownColor: CyberTheme.surface,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "INITIAL STATUS",
                            prefixIcon: Icon(Icons.info_outline, color: CyberTheme.primary),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'upcoming', child: Text("UPCOMING")),
                            DropdownMenuItem(value: 'live', child: Text("LIVE")),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedStatus = val;
                              });
                            }
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Submit Button
                        if (_isSubmitting)
                          const Center(
                            child: CircularProgressIndicator(color: CyberTheme.primary),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: CyberTheme.accentGradient,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: CyberTheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: _submitForm,
                                child: Text(
                                  "LAUNCH TOURNAMENT",
                                  style: GoogleFonts.oxanium(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ).animate().fade(duration: CyberMotion.medium).slideY(
                        begin: 0.1,
                        duration: CyberMotion.medium,
                        curve: CyberMotion.snappyCurve,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
