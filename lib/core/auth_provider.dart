// ============================================================
//  auth_provider.dart — Riverpod auth state
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

// Stream of auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges;
});

// Current user (null if not signed in)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// Sign-in notifier
final authNotifierProvider = StateNotifierProvider<AuthNotifier, bool>(
  (ref) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(false);

  Future<bool> signInWithGoogle() async {
    state = true;
    final user = await AuthService.signInWithGoogle();
    state = false;
    return user != null;
  }

  Future<void> signOut() async {
    await AuthService.signOut();
  }
}
