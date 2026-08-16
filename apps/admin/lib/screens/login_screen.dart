import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:prescription_scanner_admin/admin_authorization.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@') || _password.text.isEmpty) {
      setState(() => _error = 'Enter the admin email and password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        // Passwords may intentionally start/end with spaces; never trim them.
        password: _password.text,
      );
      final user = credential.user;
      if (user == null) throw StateError('Firebase returned no user.');
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified != true) {
        try {
          await refreshed?.sendEmailVerification();
        } on FirebaseAuthException {
          // A recent verification email may already exist or be rate-limited.
        }
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() {
            _error =
                'Verify the admin email first. A verification link was requested.';
          });
        }
        return;
      }
      if (!await isAuthorizedAdmin(refreshed!)) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() {
            _error = 'Access denied. Use the configured administrator account.';
          });
        }
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyAuthError(error));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not verify admin access.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter the admin email first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() => _error = 'Password reset email sent. Check your inbox.');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Prescription Scanner',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Admin sign in',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _sendPasswordReset,
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyAuthError(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'The admin email or password is incorrect.',
    'user-disabled' => 'This administrator account has been disabled.',
    'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'operation-not-allowed' =>
      'Email/password sign-in is not enabled in Firebase Authentication.',
    _ => error.message ?? 'Authentication failed.',
  };
}
