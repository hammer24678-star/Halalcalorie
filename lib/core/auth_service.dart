// auth_service.dart — HalalCalorie v1.0
// Local profile storage — Google Sign-In restored in v2 with google-services.json

import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String? _userId;
  static String? _email;
  static String? _name;
  static String? _photoUrl;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId   = prefs.getString('auth_user_id');
      _email    = prefs.getString('auth_email');
      _name     = prefs.getString('auth_name');
      _photoUrl = prefs.getString('auth_photo');
    } catch (_) {}
  }

  static Future<bool> signInWithGoogle() async {
    // Real Google Sign-In restored in v2
    // Requires: google-services.json + SHA fingerprint + google_sign_in package
    return false;
  }

  static Future<void> setProfile({
    required String name,
    required String email,
  }) async {
    _name  = name;
    _email = email;
    _userId = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_user_id', email);
    await prefs.setString('auth_email', email);
    await prefs.setString('auth_name', name);
  }

  static Future<void> signOut() async {
    _userId = _email = _name = _photoUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_user_id');
    await prefs.remove('auth_email');
    await prefs.remove('auth_name');
    await prefs.remove('auth_photo');
  }

  static bool get isSignedIn   => _userId != null && _userId!.isNotEmpty;
  static String? get userId    => _userId;
  static String? get userEmail => _email;
  static String? get userName  => _name;
  static String? get photoUrl  => _photoUrl;

  static Future<void> backupData() async {}
  static Future<void> restoreData() async {}
}
