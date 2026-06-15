import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream user document
  static Stream<DocumentSnapshot> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // Get user details once
  static Future<DocumentSnapshot> getUserDoc(String uid) async {
    return await _db.collection('users').doc(uid).get();
  }

  // Update user profile fields (with limit validation)
  static Future<void> updateProfile({
    required String uid,
    required String freeFireUid,
    required String gameName,
  }) async {
    final userRef = _db.collection('users').doc(uid);

    final snapshot = await userRef.get();
    final data = snapshot.data() ?? {};

    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";

    String lastDate = data['lastEditDate'] ?? "";
    int editCount = data['editCountToday'] ?? 0;

    if (lastDate != today) {
      editCount = 0;
    }

    if (editCount >= 2) {
      throw Exception("Daily limit reached (2 edits/day)");
    }

    await userRef.update({
      'freeFireUid': freeFireUid.trim(),
      'gameName': gameName.trim(),
      'editCountToday': editCount + 1,
      'lastEditDate': today,
      'lastUidChange': FieldValue.serverTimestamp(),
    });
  }
}
