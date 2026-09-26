import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final account = await googleSignIn.signIn();
    if (account == null) return; // user cancelled the popup
    final googleAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(firebaseAuthProvider));
});
