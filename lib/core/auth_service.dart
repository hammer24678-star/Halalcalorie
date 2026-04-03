// auth_service.dart — HalalCalorie v1.0
// Google Sign-In with local profile storage (no Firebase needed)

import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final _google = GoogleSignIn(scopes: ['email', 'profile']);

  static String? _userId;
  static String? _email;
  static String? _name;
  static String? _photoUrl;

  static Future<void> init() async {
    // Restore saved profile
    final prefs = await SharedPreferences.getInstance();
    _userId   = prefs.getString('auth_user_id');
    _email    = prefs.getString('auth_email');
    _name     = prefs.getString('auth_name');
    _photoUrl = prefs.getString('auth_photo');

    // Try silent sign-in
    try {
      final account = await _google.signInSilently();
      if (account != null) await _saveAccount(account);
    } catch (_) {}
  }

  static Future<bool> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) return false;
      await _saveAccount(account);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _saveAccount(GoogleSignInAccount account) async {
    _userId   = account.id;
    _email    = account.email;
    _name     = account.displayName;
    _photoUrl = account.photoUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_user_id', account.id);
    await prefs.setString('auth_email', account.email);
    await prefs.setString('auth_name', account.displayName ?? '');
    await prefs.setString('auth_photo', account.photoUrl ?? '');
  }

  static Future<void> signOut() async {
    await _google.signOut();
    _userId = _email = _name = _photoUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_user_id');
    await prefs.remove('auth_email');
    await prefs.remove('auth_name');
    await prefs.remove('auth_photo');
  }

  static bool get isSignedIn  => _userId != null;
  static String? get userId   => _userId;
  static String? get userEmail => _email;
  static String? get userName  => _name;
  static String? get photoUrl  => _photoUrl;

  // Stub — real cloud backup in v2 with Firebase
  static Future<void> backupData() async {}
  static Future<void> restoreData() async {}
}
