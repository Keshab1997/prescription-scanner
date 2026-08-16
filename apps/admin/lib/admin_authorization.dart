import 'package:firebase_auth/firebase_auth.dart';

const String fallbackAdminEmail = 'Keshabsarkar2018@gmail.com';

/// Mirrors the Firestore `isAdmin()` rule: verified email plus either the
/// preferred custom claim or the temporary configured-email fallback.
Future<bool> isAuthorizedAdmin(User user) async {
  await user.reload();
  final refreshed = FirebaseAuth.instance.currentUser;
  if (refreshed == null || !refreshed.emailVerified) return false;

  final token = await refreshed.getIdTokenResult(true);
  final hasAdminClaim = token.claims?['admin'] == true;
  return hasAdminClaim || refreshed.email == fallbackAdminEmail;
}
