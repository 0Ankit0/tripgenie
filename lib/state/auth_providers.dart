import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Auth instance provider.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Emits auth state changes for UI and guards.
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// Ensures there is a signed-in user (anonymous if necessary) so per-user
/// Firestore data is always scoped. Safe to watch in app shell for side effect.
final ensureSignedInProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth.currentUser != null) return;
  await auth.signInAnonymously();
});

/// Convenience access to the current user id, or null if not yet available.
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});
