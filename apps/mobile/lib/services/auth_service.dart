import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/services/consent_store.dart';
import 'package:prescription_scanner/services/disposable_email.dart';
import 'package:prescription_scanner/services/result_store.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(fb.FirebaseAuth.instance, FirebaseFirestore.instance);
});

/// Reactive Firebase UID used to invalidate all user-scoped data providers
/// whenever somebody signs in, signs out or switches account on this device.
final authUidProvider = StreamProvider<String?>((ref) {
  return fb.FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
});

class AuthService {
  const AuthService(this.auth, this.firestore);

  final fb.FirebaseAuth auth;
  final FirebaseFirestore firestore;

  fb.User? get currentUser => auth.currentUser;

  Stream<fb.User?> get authChanges => auth.authStateChanges();

  Future<bool> signIn({required String email, required String password}) async {
    _rejectDisposableEmail(email);
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) return false;
    await user.reload();
    final refreshedUser = auth.currentUser;
    if (refreshedUser?.emailVerified != true) {
      try {
        await refreshedUser?.sendEmailVerification();
      } on fb.FirebaseAuthException {
        // A recent verification email may already exist or Firebase may be
        // rate-limiting resends. Sign-in remains blocked either way.
      }
      await auth.signOut();
      throw fb.FirebaseAuthException(
        code: 'email-not-verified',
        message:
            'Verify your email before signing in. A new verification link was requested.',
      );
    }

    final profile = await firestore
        .collection('profiles')
        .doc(refreshedUser!.uid)
        .get();
    if (profile.data()?['status'] == 'blocked') {
      await auth.signOut();
      throw fb.FirebaseAuthException(
        code: 'user-blocked',
        message: 'This account has been blocked by an administrator.',
      );
    }
    return true;
  }

  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    _rejectDisposableEmail(email);
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
    await auth.signOut();
    return false;
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
      await ref.set({...data, 'createdAt': FieldValue.serverTimestamp()});
    }
  }

  /// Loads the Firestore profile document for the signed-in user. Returns the
  /// raw data map, or null if the document does not exist yet.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final snapshot = await firestore.collection('profiles').doc(user.uid).get();
    return snapshot.data();
  }

  /// Updates the user's display name both in Firebase Auth and Firestore.
  ///
  /// Security-sensitive profile fields such as email, role, status and
  /// createdAt are intentionally left unchanged.
  Future<void> updateProfile({required String displayName}) async {
    final user = auth.currentUser;
    if (user == null) {
      throw fb.FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Please sign in again.',
      );
    }
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }
    await user.updateDisplayName(trimmed);
    await firestore.collection('profiles').doc(user.uid).update({
      'displayName': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendPasswordReset(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Re-sends the verification email for the currently signed-in user.
  Future<void> resendEmailVerification() async {
    final user = auth.currentUser;
    if (user == null) {
      throw fb.FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Please sign in again.',
      );
    }
    await user.sendEmailVerification();
  }

  /// Updates the password directly. Suitable for the reset-password flow where
  /// the user is already authenticated via a recent sign-in/reset link.
  Future<void> updatePassword(String password) async {
    final user = auth.currentUser;
    if (user == null) {
      throw fb.FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Please sign in again.',
      );
    }
    await user.updatePassword(password);
  }

  /// Re-authenticates with the current password and sets a new one. Firebase
  /// requires a recent sign-in for password changes, so the current password
  /// is needed to re-establish the credential.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw fb.FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Please sign in again.',
      );
    }
    final credential = fb.EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
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
  /// Permanently deletes the signed-in user's account and ALL associated
  /// data: Firestore profile, usage counters, feedback, consent records,
  /// error logs, plus local on-device results. An audit record is written
  /// first (admin-managed) so the deletion can be tracked.
  Future<String> requestAccountDeletion() async {
    final user = auth.currentUser;
    if (user == null) {
      throw fb.FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Please sign in again.',
      );
    }
    final uid = user.uid;

    // Audit record — kept after deletion for accountability (admin-only).
    await firestore.collection('account_deletion_requests').doc(uid).set({
      'email': user.email,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    await _deleteUserFirestoreData(uid);

    // Delete the auth account last — after this the UID no longer exists.
    await user.delete();
    await ResultStore.instance.clearUser(uid);
    await ConsentStore.clearUser(uid);
    return uid;
  }

  /// Best-effort removal of every Firestore document owned by [uid].
  ///
  /// Data collections are deleted first while the profile still exists
  /// (rules gate them on isActiveUser(), which requires the profile), and the
  /// profile document is deleted last.
  Future<void> _deleteUserFirestoreData(String uid) async {
    Future<void> deleteDocs(Query query) async {
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return;
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    final tasks = <Future<void>>[
      deleteDocs(
        firestore.collection('daily_usage').where('user_id', isEqualTo: uid),
      ),
      deleteDocs(
        firestore
            .collection('prescription_feedback')
            .where('user_id', isEqualTo: uid),
      ),
      deleteDocs(
        firestore
            .collection('consent_records')
            .where('user_id', isEqualTo: uid),
      ),
      deleteDocs(
        firestore.collection('api_error_logs').where('userId', isEqualTo: uid),
      ),
    ];

    // A failing collection must never block the account deletion.
    await Future.wait<void>(
      tasks.map((task) => task.catchError((Object _) {})),
    );

    try {
      await firestore.collection('profiles').doc(uid).delete();
    } catch (_) {
      // Profile deletion is best-effort too; the auth account still goes.
    }
  }
}

/// Throws a FirebaseAuthException when [email] belongs to a disposable /
/// temporary mail provider. Used by both sign-up and sign-in so temp-mail
/// accounts can neither be created nor used.
void _rejectDisposableEmail(String email) {
  final message = disposableEmailError(email);
  if (message != null) {
    throw fb.FirebaseAuthException(
      code: 'disposable-email-not-allowed',
      message: message,
    );
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
      case 'email-not-verified':
        return 'Verify your email first. If allowed, a new verification link was sent. Check your Spam/Junk folder if you do not see it in your inbox.';
      case 'user-blocked':
        return 'This account has been blocked. Contact support for help.';
      case 'disposable-email-not-allowed':
        return 'Temporary/disposable email addresses are not allowed. Please use a real email address.';
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
