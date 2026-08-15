import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authServiceProvider = Provider<AuthService?>((ref) {
  if (!AppConfig.hasSupabaseConfig) return null;
  return AuthService(Supabase.instance.client);
});

class AuthService {
  const AuthService(this.client);

  final SupabaseClient client;

  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;

  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: AppConfig.authCallbackUrl,
      data: {'display_name': displayName.trim()},
    );
    return response.session != null;
  }

  Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.authCallbackUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> updateDisplayName(String displayName) async {
    await client.auth.updateUser(
      UserAttributes(data: {'display_name': displayName.trim()}),
    );
  }

  Future<void> signOut() => client.auth.signOut();

  Future<String> requestAccountDeletion() async {
    final result = await client.rpc('request_account_deletion');
    return result?.toString() ?? '';
  }
}

String friendlyAuthError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'The email or password is incorrect.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (message.contains('already registered')) {
      return 'An account already exists for this email.';
    }
    if (message.contains('password')) {
      return 'Use a stronger password with at least 8 characters.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Too many attempts. Please wait and try again.';
    }
    return 'Authentication failed. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}
