// ============================================================
//  auth_service.dart — HalalCalorie
//  Google Sign-In + Firestore cloud backup
// ============================================================
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final _auth     = FirebaseAuth.instance;
  static final _google   = GoogleSignIn();
  static final _firestore = FirebaseFirestore.instance;

  // ── Current user ──────────────────────────────────────────
  static User? get currentUser => _auth.currentUser;
  static bool  get isSignedIn  => currentUser != null;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Google Sign-In ─────────────────────────────────────────
  static Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      if (result.user != null) {
        await _ensureUserDoc(result.user!);
      }
      return result.user;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return null;
    }
  }

  // ── Sign out ───────────────────────────────────────────────
  static Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _google.signOut(),
    ]);
  }

  // ── Create user document on first sign-in ─────────────────
  static Future<void> _ensureUserDoc(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'uid':        user.uid,
        'email':      user.email,
        'displayName': user.displayName,
        'photoURL':   user.photoURL,
        'createdAt':  FieldValue.serverTimestamp(),
        'premium':    false,
        'referralCode': _genReferralCode(user.uid),
        'referredBy':  null,
        'referralCount': 0,
      });
    }
  }

  static String _genReferralCode(String uid) {
    return 'HC${uid.substring(0, 6).toUpperCase()}';
  }

  // ── Cloud backup: save daily summary ──────────────────────
  static Future<void> backupDailySummary({
    required String dateKey,
    required int    totalKcal,
    required int    goalKcal,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required int    waterCups,
    required int    steps,
  }) async {
    if (!isSignedIn) return;
    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('dailySummaries')
          .doc(dateKey)
          .set({
        'date':      dateKey,
        'totalKcal': totalKcal,
        'goalKcal':  goalKcal,
        'proteinG':  proteinG,
        'carbsG':    carbsG,
        'fatG':      fatG,
        'waterCups': waterCups,
        'steps':     steps,
        'syncedAt':  FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Backup error: $e');
    }
  }

  // ── Restore data from cloud ────────────────────────────────
  static Future<Map<String, dynamic>?> restoreLatestSummary() async {
    if (!isSignedIn) return null;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('dailySummaries')
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (e) {
      debugPrint('Restore error: $e');
      return null;
    }
  }

  // ── Backup user profile ────────────────────────────────────
  static Future<void> backupProfile(Map<String, dynamic> profile) async {
    if (!isSignedIn) return;
    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('profile')
          .doc('main')
          .set({...profile, 'syncedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
    } catch (e) {
      debugPrint('Profile backup error: $e');
    }
  }

  // ── Get weekly stats for report ────────────────────────────
  static Future<List<Map<String, dynamic>>> getWeeklyStats() async {
    if (!isSignedIn) return [];
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final dateKey = '${sevenDaysAgo.year}-'
          '${sevenDaysAgo.month.toString().padLeft(2,'0')}-'
          '${sevenDaysAgo.day.toString().padLeft(2,'0')}';

      final snap = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('dailySummaries')
          .where('date', isGreaterThanOrEqualTo: dateKey)
          .orderBy('date')
          .get();

      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Weekly stats error: $e');
      return [];
    }
  }
}
