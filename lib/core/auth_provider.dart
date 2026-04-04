// auth_provider.dart — HalalCalorie v1.0
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

// Whether user is signed in
final isSignedInProvider = Provider<bool>((ref) {
  return AuthService.isSignedIn;
});

// Current user name
final userNameProvider = Provider<String?>((ref) {
  return AuthService.userName;
});

// Sign-in notifier
final authNotifierProvider = StateNotifierProvider<AuthNotifier, bool>(
  (ref) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(false);

  Future<bool> signInWithGoogle() async {
    state = true;
    final success = await AuthService.signInWithGoogle();
    state = false;
    return success;
  }

  Future<void> signOut() async {
    await AuthService.signOut();
  }
}
