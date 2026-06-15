import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // =========================
  // ROLE CACHE (IMPORTANT)
  // =========================
  static String? _role;

  static bool isAdmin() => _role == 'admin';

  static Future<String?> fetchUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();

    _role = data?['role'];
    return _role;
  }

  static Future<void> _ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName,
        'photoUrl': user.photoURL,
        'role': 'player',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> _loadRole(User user) async {
    await fetchUserRole(user.uid);
  }

  // =========================
  // GOOGLE SIGN IN
  // =========================
  static Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
    await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
    await _auth.signInWithCredential(credential);

    final user = userCredential.user;

    if (user != null) {
      await _ensureUserDoc(user);
      await _loadRole(user);
    }

    return user;
  }

  // =========================
  // EMAIL LOGIN
  // =========================
  static Future<UserCredential> signInWithEmail(
      String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = result.user;

    if (user != null) {
      await _loadRole(user);
    }

    return result;
  }

  // =========================
  // EMAIL SIGN UP
  // =========================
  static Future<User?> signUpWithEmail(
      String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      await user.updateDisplayName(name);

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': name,
        'role': 'player',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _loadRole(user);
    }

    return user;
  }

  // =========================
  // SIGN OUT
  // =========================
  static Future<void> signOut() async {
    _role = null;
    await _auth.signOut();

    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  // =========================
  // REFRESH ROLE (IMPORTANT FOR ADMIN UPDATES)
  // =========================
  static Future<void> refreshRole() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await fetchUserRole(user.uid);
  }
}