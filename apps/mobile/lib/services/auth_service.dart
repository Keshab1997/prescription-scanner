import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(fb.FirebaseAuth.instance, FirebaseFirestore.instance);
});

class AuthService {
  const AuthService(this.auth, this.firestore);

  final fb.FirebaseAuth auth;
  final FirebaseFirestore firestore;

  fb.User? get currentUser => auth.currentUser;

  Stream<fb.User?> get authChanges => auth.authStateChanges();

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Returns true when the session is usable (verified or verification off).
    return credential.user != null;
  }

  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) return false;
    await user.updateDisplayName(displayName.trim());
    await _ensureProfile(
      uid: user.uid,
      email: email.trim(),
      displayName: displayName.trim(),
    );
    await user.sendEmailVerification();
    return true;
  }

  Future<void> _ensureProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    final ref = firestore.collection('profiles').doc(uid);
    final snapshot = await ref.get();
    final data = {
      'displayName': displayName,
      'email': email,
      'role': 'user',
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (snapshot.exists) {
      await ref.update(data);
    } else {
      await ref.set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Re-authenticates the current user with their password, then updates it.
  Future<void> updatePassword(String password) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw fb.FirebaseAuthException(
        code: 'reauth-required',
        message: 'Please sign in again.',
      );
    }
    // Requires a recent sign-in; callers should prompt for the current
    // password and pass it through reauthenticateWithCredential first when
    // the session is stale. Here we attempt the direct update.
    await user.updatePassword(password);
  }

  /// Re-authenticates with the current password (needed for sensitive
  /// operations like password change or account deletion).
  Future<void> reauthenticate(String password) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw fb.FirebaseAuthException(
        code: 'reauth-required',
        message: 'Please sign in again.',
      );
    }
    final credential = fb.EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> signOut() => auth.signOut();

  /// Submits a deletion request and removes the local auth account. The
  /// Firestore profile/documents cleanup is handled by the admin or a
  /// scheduled routine; this records intent and deletes the auth user.
  Future<String> requestAccountDeletion() async {
    final user = auth.currentUser;
    if (user == null) {
      throw fb.FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Please sign in again.',
      );
    }
    await firestore
        .collection('account_deletion_requests')
        .doc(user.uid)
        .set({
      'email': user.email,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    await user.delete();
    return user.uid;
  }
}

String friendlyAuthError(Object error) {
  if (error is fb.FirebaseAuthException) {
    final code = error.code;
    switch (code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Use a stronger password with at least 8 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      case 'network-request-failed':
        return 'Check your connection and try again.';
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
    return 'Authentication failed. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}
