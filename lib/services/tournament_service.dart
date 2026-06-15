import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TournamentService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream all tournaments
  static Stream<QuerySnapshot> getTournamentsStream() {
    return _db.collection('tournaments').orderBy('createdAt', descending: true).snapshots();
  }

  // Create tournament
  static Future<void> createTournament({
    required String title,
    required int entryFee,
    required int totalSlots,
    required String prizePool,
    required String status,
    required String createdBy,
  }) async {
    final batch = _db.batch();
    final tourRef = _db.collection('tournaments').doc();
    
    batch.set(tourRef, {
      'title': title,
      'entryFee': entryFee,
      'totalSlots': totalSlots,
      'filledSlots': 0,
      'prizePool': prizePool,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await _db.collection('users').doc(currentUser.uid).get();
      final isAdminUser = userDoc.data()?['role'] == 'admin';
      
      if (isAdminUser) {
        final logRef = _db.collection('admin_audit_logs').doc();
        batch.set(logRef, {
          'adminUid': currentUser.uid,
          'adminEmail': currentUser.email ?? 'Unknown',
          'action': 'CREATE_TOURNAMENT',
          'details': "Created tournament: $title (Entry Fee: ₹$entryFee, Slots: $totalSlots)",
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  // Delete tournament and its orphaned data recursively
  static Future<void> deleteTournament(String tournamentId) async {
    final tourRef = _db.collection('tournaments').doc(tournamentId);
    final tourSnap = await tourRef.get();
    final tourData = tourSnap.data() ?? {};
    final title = tourData['title'] ?? 'Unknown Tournament';

    // Get participants subcollection
    final participantsQuery = await tourRef.collection('participants').get();
    final batch = _db.batch();
    for (var doc in participantsQuery.docs) {
      batch.delete(doc.reference);
    }

    // Get related join requests
    final requestsQuery = await _db
        .collection('join_requests')
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    for (var doc in requestsQuery.docs) {
      batch.delete(doc.reference);
    }

    // Delete tournament doc itself
    batch.delete(tourRef);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await _db.collection('users').doc(currentUser.uid).get();
      final isAdminUser = userDoc.data()?['role'] == 'admin';
      
      if (isAdminUser) {
        final logRef = _db.collection('admin_audit_logs').doc();
        batch.set(logRef, {
          'adminUid': currentUser.uid,
          'adminEmail': currentUser.email ?? 'Unknown',
          'action': 'DELETE_TOURNAMENT',
          'details': "Deleted tournament: $title ($tournamentId)",
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  // Update status
  static Future<void> updateTournamentStatus(String tournamentId, String newStatus) async {
    final tourRef = _db.collection('tournaments').doc(tournamentId);
    final tourSnap = await tourRef.get();
    final tourData = tourSnap.data() ?? {};
    final title = tourData['title'] ?? 'Unknown Tournament';

    final batch = _db.batch();
    batch.update(tourRef, {
      'status': newStatus,
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final logRef = _db.collection('admin_audit_logs').doc();
      batch.set(logRef, {
        'adminUid': currentUser.uid,
        'adminEmail': currentUser.email ?? 'Unknown',
        'action': 'UPDATE_TOURNAMENT_STATUS',
        'details': "Updated status of tournament '$title' to $newStatus",
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }



  // Join tournament directly (Auto-approved / Direct entry without admin approval)
  static Future<void> joinTournamentDirectly({
    required String tournamentId,
    required String tournamentTitle,
    required String userId,
    required String playerName,
    required String gameName,
    required String ffUid,
    required int entryFee,
  }) async {
    final tournamentRef = _db.collection('tournaments').doc(tournamentId);

    await _db.runTransaction((transaction) async {
      // 1. Fetch tournament
      final tournamentSnap = await transaction.get(tournamentRef);
      final tournament = tournamentSnap.data();
      if (tournament == null) throw Exception("Tournament not found");

      // Check if user is already a participant
      final participantRef = tournamentRef.collection('participants').doc(userId);
      final participantSnap = await transaction.get(participantRef);
      if (participantSnap.exists) {
        throw Exception("You are already registered in this tournament");
      }

      final int filled = (tournament['filledSlots'] ?? 0) as int;
      final int total = (tournament['totalSlots'] ?? 0) as int;
      final String status = (tournament['status'] ?? 'upcoming').toString().toLowerCase();

      if (status == 'ended') {
        throw Exception("Tournament has already ended");
      }
      if (status == 'full' || filled >= total) {
        throw Exception("Tournament is Full");
      }

      // 2. If entryFee > 0, check and deduct from wallet
      if (entryFee > 0) {
        final walletRef = _db.collection('wallets').doc(userId);
        final walletSnap = await transaction.get(walletRef);
        
        double balance = 0.0;
        if (walletSnap.exists) {
          final walletData = walletSnap.data() ?? {};
          balance = (walletData['balance'] ?? 0.0) as double;
        } else {
          // If wallet doesn't exist, create it with 0.0
          transaction.set(walletRef, {
            'balance': 0.0,
            'winnings': 0.0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (balance < entryFee) {
          throw Exception("Insufficient balance for entry fee. Required: ₹$entryFee, Available: ₹$balance");
        }

        // Deduct
        transaction.update(walletRef, {
          'balance': balance - entryFee,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Log transaction
        final txRef = _db.collection('wallet_transactions').doc();
        transaction.set(txRef, {
          'userId': userId,
          'amount': -entryFee.toDouble(),
          'type': 'entry_fee',
          'description': "Entry Fee: $tournamentTitle",
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // 3. Add to participants subcollection
      transaction.set(participantRef, {
        'uid': userId,
        'name': playerName,
        'gameName': gameName,
        'ffUid': ffUid,
        'slotNumber': filled + 1,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // 4. Increment filled slots
      transaction.update(tournamentRef, {
        'filledSlots': filled + 1,
      });

      // 5. Create an approved join request for reference
      final requestRef = _db.collection('join_requests').doc();
      transaction.set(requestRef, {
        'tournamentId': tournamentId,
        'tournamentTitle': tournamentTitle,
        'userId': userId,
        'playerName': playerName,
        'gameName': gameName,
        'ffUid': ffUid,
        'entryFee': entryFee,
        'status': 'approved',
        'paymentDetails': 'Auto-approved (Direct Entry)',
        'screenshotUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Submit match results atomically using a transaction
  static Future<void> submitMatchResults({
    required String tournamentId,
    required String tournamentTitle,
    required List<Map<String, dynamic>> results, // Keys: userId, userName, rank, kills, payout
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Not logged in");

    final tourRef = _db.collection('tournaments').doc(tournamentId);

    await _db.runTransaction((transaction) async {
      // 1. Check tournament status
      final tourSnap = await transaction.get(tourRef);
      if (!tourSnap.exists) throw Exception("Tournament not found");
      final tourData = tourSnap.data() ?? {};
      if (tourData['status'] == 'ended') {
        throw Exception("Results have already been processed for this tournament");
      }

      // 2. Fetch all user profile docs to read current XP, achievements, levels, etc.
      final Map<String, Map<String, dynamic>> userProfiles = {};
      final Map<String, Map<String, dynamic>> userStats = {};

      for (var res in results) {
        final userId = res['userId'] as String;
        final userRef = _db.collection('users').doc(userId);
        final statsRef = _db.collection('player_stats').doc(userId);

        final userSnap = await transaction.get(userRef);
        final statsSnap = await transaction.get(statsRef);

        userProfiles[userId] = userSnap.data() ?? {};
        userStats[userId] = statsSnap.data() ?? {};
      }

      // 3. Process each result
      for (var res in results) {
        final userId = res['userId'] as String;
        final userName = res['userName'] as String;
        final rank = res['rank'] as int;
        final kills = res['kills'] as int;
        final payout = (res['payout'] ?? 0.0) as double;

        // Current user stats
        final userProfile = userProfiles[userId]!;
        final currentXp = (userProfile['xp'] ?? 0) as int;
        final List<dynamic> currentAchDynamic = userProfile['achievements'] as List<dynamic>? ?? [];
        final List<String> currentAchievements = currentAchDynamic.map((e) => e.toString()).toList();

        // Current player stats
        final pStats = userStats[userId]!;
        final currentMatches = (pStats['totalMatches'] ?? 0) as int;
        final currentWins = (pStats['totalWins'] ?? 0) as int;
        final currentTop3 = (pStats['top3Finishes'] ?? 0) as int;
        final currentTop10 = (pStats['top10Finishes'] ?? 0) as int;
        final currentKills = (pStats['totalKills'] ?? 0) as int;
        final double currentWinnings = (pStats['totalPrizeWon'] ?? 0.0) is int 
            ? (pStats['totalPrizeWon'] ?? 0.0).toDouble() 
            : (pStats['totalPrizeWon'] ?? 0.0) as double;

        // Calculations
        final isWinner = rank == 1;
        final isTop3 = rank <= 3 && rank > 0;
        final isTop10 = rank <= 10 && rank > 0;

        // Formula: XP Gained = (kills * 15) + placementPoints
        int placementXp = 20; // default for participation
        if (isWinner) {
          placementXp = 150;
        } else if (rank == 2) {
          placementXp = 100;
        } else if (rank == 3) {
          placementXp = 75;
        } else if (isTop10) {
          placementXp = 50;
        }

        final int xpGained = (kills * 15) + placementXp;
        final int newXp = currentXp + xpGained;

        // Level Formula: Level = floor(XP / 500) + 1
        final int newLevel = (newXp / 500).floor() + 1;

        // SP Formula: SP Gained = (kills * 10) + placementPoints
        int placementSp = 20;
        if (isWinner) {
          placementSp = 150;
        } else if (rank == 2) {
          placementSp = 100;
        } else if (rank == 3) {
          placementSp = 75;
        } else if (isTop10) {
          placementSp = 50;
        }

        final int spGained = (kills * 10) + placementSp;
        final int currentSp = (userProfile['seasonPoints'] ?? 0) as int;
        final int newSp = currentSp + spGained;

        // Division calculation based on new Season Points (SP)
        String newDivision = "Bronze";
        if (newSp >= 7500) {
          newDivision = "HeroX Legend";
        } else if (newSp >= 5000) {
          newDivision = "Master";
        } else if (newSp >= 3500) {
          newDivision = "Diamond";
        } else if (newSp >= 2000) {
          newDivision = "Platinum";
        } else if (newSp >= 1000) {
          newDivision = "Gold";
        } else if (newSp >= 500) {
          newDivision = "Silver";
        }

        // Performance Increments
        final int updatedMatches = currentMatches + 1;
        final int updatedWins = currentWins + (isWinner ? 1 : 0);
        final int updatedTop3 = currentTop3 + (isTop3 ? 1 : 0);
        final int updatedTop10 = currentTop10 + (isTop10 ? 1 : 0);
        final int updatedKills = currentKills + kills;
        final double updatedWinnings = currentWinnings + payout;

        // Achievements check
        final List<String> updatedAchievements = checkAchievementsList(
          updatedMatches,
          updatedWins,
          updatedTop3,
          updatedTop10,
          newXp,
          newDivision,
          currentAchievements,
        );

        // 1. Update users profile
        final userRef = _db.collection('users').doc(userId);
        transaction.update(userRef, {
          'xp': newXp,
          'level': newLevel,
          'seasonPoints': newSp,
          'division': newDivision,
          'achievements': updatedAchievements,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update player stats
        final statsRef = _db.collection('player_stats').doc(userId);
        transaction.set(statsRef, {
          'totalMatches': updatedMatches,
          'totalWins': updatedWins,
          'top3Finishes': updatedTop3,
          'top10Finishes': updatedTop10,
          'totalKills': updatedKills,
          'totalPrizeWon': updatedWinnings,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 3. Update leaderboards doc
        final leaderboardRef = _db.collection('leaderboards').doc(userId);
        transaction.set(leaderboardRef, {
          'playerName': userName,
          'points': newSp,
          'wins': updatedWins,
          'kills': updatedKills,
          'winnings': updatedWinnings,
          'division': newDivision,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 4. Update wallet balance if payout > 0
        if (payout > 0) {
          final walletRef = _db.collection('wallets').doc(userId);
          // Get current wallet balance
          double walletBal = 0.0;
          double walletWin = 0.0;
          final walletRefSnap = await transaction.get(walletRef);
          if (walletRefSnap.exists) {
            final wData = walletRefSnap.data() ?? {};
            walletBal = (wData['balance'] ?? 0.0) as double;
            walletWin = (wData['winnings'] ?? 0.0) as double;
          } else {
            transaction.set(walletRef, {
              'balance': 0.0,
              'winnings': 0.0,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          transaction.update(walletRef, {
            'balance': walletBal + payout,
            'winnings': walletWin + payout,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Log transaction
          final txRef = _db.collection('wallet_transactions').doc();
          transaction.set(txRef, {
            'userId': userId,
            'amount': payout,
            'type': 'winnings',
            'description': "Winnings from: $tournamentTitle",
            'tournamentId': tournamentId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // 5. Write match result
        final resultRef = _db.collection('match_results').doc();
        transaction.set(resultRef, {
          'tournamentId': tournamentId,
          'tournamentTitle': tournamentTitle,
          'userId': userId,
          'playerName': userName,
          'rank': rank,
          'kills': kills,
          'payout': payout,
          'xpGained': xpGained,
          'spGained': spGained,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // 6. Update tournament status to ended
      transaction.update(tourRef, {
        'status': 'ended',
      });

      // 7. Write admin action log
      final logRef = _db.collection('admin_audit_logs').doc();
      transaction.set(logRef, {
        'adminUid': currentUser.uid,
        'adminEmail': currentUser.email ?? 'Unknown',
        'action': 'SUBMIT_MATCH_RESULTS',
        'details': "Processed match results and achievements for tournament '$tournamentTitle' ($tournamentId)",
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // Helper function to check achievement triggers
  static List<String> checkAchievementsList(
    int matchesPlayed,
    int winsCount,
    int top3Count,
    int top10Count,
    int xpValue,
    String divisionName,
    List<String> currentAchievements,
  ) {
    final achievements = List<String>.from(currentAchievements);

    void addIfMissing(String ach) {
      if (!achievements.contains(ach)) {
        achievements.add(ach);
      }
    }

    if (matchesPlayed >= 1) addIfMissing("First Tournament");
    if (matchesPlayed >= 5) addIfMissing("5 Tournaments Played");
    if (matchesPlayed >= 25) addIfMissing("25 Tournaments Played");

    if (winsCount >= 1) addIfMissing("First Victory");
    if (winsCount >= 5) addIfMissing("5 Wins");
    if (winsCount >= 10) addIfMissing("10 Wins");

    if (top10Count >= 1) addIfMissing("Top 10 Finish");
    if (top3Count >= 1) addIfMissing("Top 3 Finish");

    if (matchesPlayed >= 1) addIfMissing("Season Competitor");
    if (winsCount >= 20 || divisionName == "Master" || divisionName == "HeroX Legend") {
      addIfMissing("Season Champion");
    }

    if (xpValue >= 1000) addIfMissing("1000 XP Earned");
    if (divisionName == "Diamond" || divisionName == "Master" || divisionName == "HeroX Legend") {
      addIfMissing("Diamond Division");
    }

    return achievements;
  }
}
