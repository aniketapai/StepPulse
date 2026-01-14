import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // Current user
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in with Google
  bool get isGoogleUser {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Check provider data for google.com
    for (final provider in user.providerData) {
      if (provider.providerId == 'google.com') {
        return true;
      }
    }
    return false;
  }

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Use disconnect() instead of signOut() to clear cached account
      // This forces the account picker to show on next login
      await _googleSignIn.disconnect();
      await _auth.signOut();
    } catch (e) {
      // If disconnect fails, try signOut as fallback
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (_) {
        // Ignore errors
      }
    }
  }
}
