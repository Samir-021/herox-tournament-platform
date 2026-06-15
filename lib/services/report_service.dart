import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Player reports another player in a tournament
  static Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    required String tournamentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated.");

    if (user.uid == reportedUserId) {
      throw Exception("You cannot report yourself.");
    }

    final now = DateTime.now();
    final tenMinsAgo = now.subtract(const Duration(minutes: 10));
    final oneDayAgo = now.subtract(const Duration(days: 1));

    // Get previous reports against this specific target
    final query = await _db
        .collection('reports')
        .where('fromUserId', isEqualTo: user.uid)
        .where('toUserId', isEqualTo: reportedUserId)
        .get();

    final tenMinsAgoMs = tenMinsAgo.millisecondsSinceEpoch;
    final oneDayAgoMs = oneDayAgo.millisecondsSinceEpoch;

    int reportsInLast24Hours = 0;
    bool hasCooldownViolation = false;

    for (var doc in query.docs) {
      final data = doc.data();
      final Timestamp? createdAt = data['createdAt'] as Timestamp?;
      if (createdAt != null) {
        final ms = createdAt.millisecondsSinceEpoch;
        if (ms > tenMinsAgoMs) {
          hasCooldownViolation = true;
        }
        if (ms > oneDayAgoMs) {
          reportsInLast24Hours++;
        }
      }
    }

    if (hasCooldownViolation) {
      throw Exception("Please wait 10 minutes between reporting the same user again.");
    }
    if (reportsInLast24Hours >= 3) {
      throw Exception("You have reached the maximum limit of 3 reports per user per day.");
    }

    String reportedUserName = 'Unknown';
    try {
      final doc = await _db
          .collection('users')
          .doc(reportedUserId)
          .get();
      if (doc.exists) {
        reportedUserName = doc.data()?['name'] ?? doc.data()?['gameName'] ?? 'Unknown';
      }
    } catch (_) {}

    await _db.collection('reports').add({
      'fromUserId': user.uid,
      'toUserId': reportedUserId,
      'toName': reportedUserName,
      'reason': reason,
      'tournamentId': tournamentId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'fromName': user.displayName ?? '',
    });
  }

  // Admin bans a user and writes to admin action logs
  static Future<void> banUser({
    required String userId,
    required String reason,
    required String adminUid,
    required String adminEmail,
    DateTime? expiryDate,
  }) async {
    final batch = _db.batch();

    // 1. Set ban status
    final banRef = _db.collection('bans').doc(userId);
    batch.set(banRef, {
      'banned': true,
      'bannedAt': FieldValue.serverTimestamp(),
      'reason': reason,
      'bannedBy': adminUid,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'appealStatus': 'none',
      'appealText': '',
    });

    // 2. Write admin action audit log
    final logRef = _db.collection('admin_audit_logs').doc();
    batch.set(logRef, {
      'adminUid': adminUid,
      'adminEmail': adminEmail,
      'action': 'BAN_USER',
      'details': "Banned user $userId. Reason: $reason. Expiry: ${expiryDate ?? 'Permanent'}",
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Admin marks report resolved
  static Future<void> markReportHandled(String reportId) async {
    await _db
        .collection('reports')
        .doc(reportId)
        .update({
      'status': 'action_taken',
    });
  }
}