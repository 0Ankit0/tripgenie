import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Create a singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
      // print('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Mock function to retrieve API key for the authenticated user
  // In a real app, this would call a backend service (e.g., Cloud Functions)
  Future<String?> getApiKeyForUser(User user) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Return a mock API key or the user's existing key if specific logic existed
    // For now, we'll return a placeholder to prove the flow works.
    // OR we can leave this null to force them to input it if we can't really generate one.
    // Per user request: "automatically get the api key and the app should work"
    // Since I cannot magically generate a valid Gemini API key for them without a backend,
    // I will return a dummy key to demonstrate the flow, but it won't actually "work" for API calls
    // unless this was a pre-provisioned key.
    // Per user request, we are using the provided API key "automatically"
    // In a real app, this would be fetched from a secure backend.
    return "AIzaSyCR9sha3ssvTKlNTwO3Yk6yXTbS9z-vJw0";
  }
}
