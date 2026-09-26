import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// The signed-in user, or null. The CMS's own screen-level gate; the Worker
/// re-checks the email allowlist server-side on every request regardless.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// The current user's Firebase ID token, refreshed on every read — every
/// [CmsApiClient] call needs a fresh one, since tokens expire hourly.
Future<String> currentIdToken(FirebaseAuth auth) async {
  final user = auth.currentUser;
  if (user == null) {
    throw StateError('currentIdToken called with no signed-in user');
  }
  final token = await user.getIdToken();
  if (token == null) {
    throw StateError('Firebase returned no ID token for a signed-in user');
  }
  return token;
}

class AuthController {
  AuthController(this._auth);

  final FirebaseAuth _auth;

  /// Web-only app, so this goes straight through Firebase Auth's own popup
  /// flow rather than the `google_sign_in` plugin — no client-ID meta tag
  /// or extra web wiring needed beyond enabling Google sign-in in the
  /// Firebase console (already done).
  Future<void> signInWithGoogle() async {
    await _auth.signInWithPopup(GoogleAuthProvider());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(firebaseAuthProvider));
});
