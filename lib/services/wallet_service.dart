import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream user's wallet info
  static Stream<DocumentSnapshot> getWalletStream(String userId) {
    return _db.collection('wallets').doc(userId).snapshots();
  }

  // Stream user's transactions
  static Stream<QuerySnapshot> getTransactionsStream(String userId) {
    return _db
        .collection('wallet_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Initialize wallet doc if missing
  static Future<void> createWalletIfMissing(String userId) async {
    final ref = _db.collection('wallets').doc(userId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'balance': 0.0,
        'winnings': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Mock deposit for testing (can be deprecated but let's keep it or replace it)
  static Future<void> depositCredits(String userId, double amount) async {
    await createWalletIfMissing(userId);

    await _db.runTransaction((transaction) async {
      final walletRef = _db.collection('wallets').doc(userId);
      final walletSnap = await transaction.get(walletRef);
      final walletData = walletSnap.data() ?? {};

      final double balance = (walletData['balance'] ?? 0.0) as double;
      transaction.update(walletRef, {
        'balance': balance + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log transaction
      final txRef = _db.collection('wallet_transactions').doc();
      transaction.set(txRef, {
        'userId': userId,
        'amount': amount,
        'type': 'deposit',
        'description': 'Simulated wallet credit deposit',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // Payout winnings to user wallet
  static Future<void> payOutWinnings(String userId, double amount, String tournamentTitle) async {
    await createWalletIfMissing(userId);

    await _db.runTransaction((transaction) async {
      final walletRef = _db.collection('wallets').doc(userId);
      final walletSnap = await transaction.get(walletRef);
      final walletData = walletSnap.data() ?? {};

      final double balance = (walletData['balance'] ?? 0.0) as double;
      final double winnings = (walletData['winnings'] ?? 0.0) as double;

      transaction.update(walletRef, {
        'balance': balance + amount,
        'winnings': winnings + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log transaction
      final txRef = _db.collection('wallet_transactions').doc();
      transaction.set(txRef, {
        'userId': userId,
        'amount': amount,
        'type': 'winnings',
        'description': "Winnings from: $tournamentTitle",
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // Deduct entry fee
  static Future<void> deductEntryFee(String userId, double amount, String tournamentTitle) async {
    await createWalletIfMissing(userId);

    await _db.runTransaction((transaction) async {
      final walletRef = _db.collection('wallets').doc(userId);
      final walletSnap = await transaction.get(walletRef);
      final walletData = walletSnap.data() ?? {};

      final double balance = (walletData['balance'] ?? 0.0) as double;

      if (balance < amount) {
        throw Exception("Insufficient balance for entry fee.");
      }

      transaction.update(walletRef, {
        'balance': balance - amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log transaction
      final txRef = _db.collection('wallet_transactions').doc();
      transaction.set(txRef, {
        'userId': userId,
        'amount': -amount,
        'type': 'entry_fee',
        'description': "Entry Fee: $tournamentTitle",
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // === NEW PAYMENT CONFIGURATION & DEPOSIT QUEUE SERVICES ===

  // Stream payment config (eSewa ID & QR url)
  static Stream<DocumentSnapshot> getPaymentConfigStream() {
    return _db.collection('metadata').doc('payment_config').snapshots();
  }

  // Get payment config once
  static Future<DocumentSnapshot> getPaymentConfig() {
    return _db.collection('metadata').doc('payment_config').get();
  }

  // Update payment config (Admin only)
  static Future<void> updatePaymentConfig(String esewaId, String esewaQrUrl) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Not logged in");

    final batch = _db.batch();
    final configRef = _db.collection('metadata').doc('payment_config');
    batch.set(configRef, {
      'esewaId': esewaId.trim(),
      'esewaQrUrl': esewaQrUrl.trim(),
      'updatedBy': currentUser.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final logRef = _db.collection('admin_audit_logs').doc();
    batch.set(logRef, {
      'adminUid': currentUser.uid,
      'adminEmail': currentUser.email ?? 'Unknown',
      'action': 'UPDATE_PAYMENT_CONFIG',
      'details': "Updated eSewa ID: $esewaId and QR Code image URL",
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Submit Deposit Request (Player)
  static Future<void> submitDepositRequest({
    required String userId,
    required String userName,
    required double amount,
    required String screenshotUrl,
    String? transactionRef,
  }) async {
    await createWalletIfMissing(userId);

    // Validate that if a transaction reference is provided, it has not been used before.
    if (transactionRef != null && transactionRef.trim().isNotEmpty) {
      final dupQuery = await _db
          .collection('deposit_requests')
          .where('transactionRef', isEqualTo: transactionRef.trim())
          .get();
      if (dupQuery.docs.isNotEmpty) {
        throw Exception("This transaction reference has already been submitted.");
      }
    }

    await _db.collection('deposit_requests').add({
      'userId': userId,
      'userName': userName,
      'amount': amount,
      'screenshotUrl': screenshotUrl,
      'transactionRef': transactionRef?.trim() ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream player's own deposit requests
  static Stream<QuerySnapshot> getPlayerDepositRequestsStream(String userId) {
    return _db
        .collection('deposit_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Stream pending deposit requests (Admin queue)
  static Stream<QuerySnapshot> getPendingDepositRequestsStream() {
    return _db
        .collection('deposit_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Stream processed (approved or rejected) deposit requests (Admin history)
  static Stream<QuerySnapshot> getProcessedDepositRequestsStream() {
    return _db
        .collection('deposit_requests')
        .where('status', whereIn: ['approved', 'rejected'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Approve Deposit Request (Admin)
  static Future<void> approveDepositRequest({
    required String requestId,
    required String userId,
    required double amount,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Not logged in");

    final requestRef = _db.collection('deposit_requests').doc(requestId);
    final walletRef = _db.collection('wallets').doc(userId);

    await _db.runTransaction((transaction) async {
      // 1. Fetch deposit request and verify status is pending
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) throw Exception("Deposit request not found");
      final requestData = requestSnap.data() ?? {};
      if (requestData['status'] != 'pending') {
        throw Exception("This deposit request has already been processed.");
      }

      // 2. Fetch player wallet balance
      final walletSnap = await transaction.get(walletRef);
      double balance = 0.0;
      if (walletSnap.exists) {
        balance = (walletSnap.data()?['balance'] ?? 0.0) as double;
      } else {
        transaction.set(walletRef, {
          'balance': 0.0,
          'winnings': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Update request status
      transaction.update(requestRef, {
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': currentUser.uid,
      });

      // 4. Increment wallet balance
      transaction.update(walletRef, {
        'balance': balance + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Write wallet transaction log
      final txRef = _db.collection('wallet_transactions').doc();
      transaction.set(txRef, {
        'userId': userId,
        'amount': amount,
        'type': 'deposit',
        'description': "Deposit approved (Ref: ${requestData['transactionRef'] != '' ? requestData['transactionRef'] : 'P2P QR'})",
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 6. Write admin action log
      final logRef = _db.collection('admin_audit_logs').doc();
      transaction.set(logRef, {
        'adminUid': currentUser.uid,
        'adminEmail': currentUser.email ?? 'Unknown',
        'action': 'APPROVE_DEPOSIT',
        'details': "Approved credit deposit of ₹$amount for player $userId (Request: $requestId)",
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // Reject Deposit Request (Admin)
  static Future<void> rejectDepositRequest({
    required String requestId,
    required String reason,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Not logged in");

    final requestRef = _db.collection('deposit_requests').doc(requestId);

    await _db.runTransaction((transaction) async {
      // 1. Fetch deposit request and verify status is pending
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) throw Exception("Deposit request not found");
      final requestData = requestSnap.data() ?? {};
      if (requestData['status'] != 'pending') {
        throw Exception("This deposit request has already been processed.");
      }

      // 2. Update request status
      transaction.update(requestRef, {
        'status': 'rejected',
        'rejectionReason': reason.trim(),
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': currentUser.uid,
      });

      // 3. Write admin action log
      final logRef = _db.collection('admin_audit_logs').doc();
      transaction.set(logRef, {
        'adminUid': currentUser.uid,
        'adminEmail': currentUser.email ?? 'Unknown',
        'action': 'REJECT_DEPOSIT',
        'details': "Rejected credit deposit for player ${requestData['userId']} (Request: $requestId). Reason: $reason",
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}
