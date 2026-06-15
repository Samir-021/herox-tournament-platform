import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static Future<bool> isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return false;

    return data['role'] == 'admin';
  }

  // ✅ ADD ADMIN BY EMAIL
  static Future<String> addAdminByEmail(String email) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return "Not logged in";

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return "User not found";
    }

    final userDoc = query.docs.first;
    final uid = userDoc.id;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'role': 'admin',
    });

    await FirebaseFirestore.instance.collection('admins').doc(uid).set({
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'addedBy': currentUser.uid,
    });

    return "Admin added successfully";
  }

  // ✅ REMOVE ADMIN
  static Future<void> removeAdmin(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'role': 'player',
    });

    await FirebaseFirestore.instance.collection('admins').doc(uid).delete();
  }

  // ✅ GET ALL ADMINS
  static Stream<QuerySnapshot> getAdmins() {
    return FirebaseFirestore.instance.collection('admins').snapshots();
  }
}