import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/services/auth_session_notifier.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool accepted = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final service = ref.read(authServiceProvider);
    if (name.text.trim().length < 2) {
      setState(() => error = 'Enter your full name.');
      return;
    }
    if (!email.text.contains('@')) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    if (password.text.length < 8) {
      setState(() => error = 'Use at least 8 characters for your password.');
      return;
    }
    if (password.text != confirmPassword.text) {
      setState(() => error = 'The passwords do not match.');
      return;
    }
    if (!accepted) {
      setState(
        () => error = 'Accept the Privacy Policy and Terms to continue.',
      );
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });
    try {
      final hasSession = await service.signUp(
        displayName: name.text,
        email: email.text,
        password: password.text,
      );
      if (!mounted) return;
      if (hasSession) {
        context.go('/home');
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.mark_email_read_outlined),
            title: const Text('Check your email'),
            content: const Text(
              'Open the verification link, then return to sign in securely. '
              'If you do not see the email in your inbox, check your Spam or '
              'Junk folder and mark it as "Not spam".',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
        if (mounted) context.go('/login');
      }
    } catch (exception) {
      if (mounted) setState(() => error = friendlyAuthError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Create your account',
      subtitle: 'Your prescription history stays private to you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: password,
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Password',
              helperText: 'At least 8 characters',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: confirmPassword,
            obscureText: true,
            onSubmitted: (_) => submit(),
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: accepted,
            onChanged: (value) => setState(() => accepted = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I accept the Privacy Policy, Terms and AI-processing disclosure.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          if (error != null) _AuthError(error!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading ? null : submit,
            child: loading
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
          TextButton(
            onPressed: loading ? null : () => context.go('/login'),
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final email = TextEditingController();
  bool loading = false;
  bool sent = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!email.text.contains('@')) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    final service = ref.read(authServiceProvider);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await service.sendPasswordReset(email.text);
      if (mounted) setState(() => sent = true);
    } catch (exception) {
      if (mounted) setState(() => error = friendlyAuthError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: sent ? 'Check your email' : 'Reset your password',
      subtitle: sent
          ? 'If an account exists, a secure reset link has been sent. Check '
                'your Spam/Junk folder if you cannot find it.'
          : 'We will send a secure password-reset link.',
      child: sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Entrance(
                  child: Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.softGradient,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.teal,
                        size: 42,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to sign in'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                if (error != null) _AuthError(error!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Send reset link'),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (password.text.length < 8) {
      setState(() => error = 'Use at least 8 characters.');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = 'The passwords do not match.');
      return;
    }
    final service = ref.read(authServiceProvider);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await service.updatePassword(password.text);
      ref.read(authSessionNotifierProvider).completePasswordRecovery();
      if (mounted) context.go('/home');
    } catch (exception) {
      if (mounted) setState(() => error = friendlyAuthError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Use a strong password you have not used before.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: confirm,
            obscureText: true,
            onSubmitted: (_) => submit(),
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
          if (error != null) _AuthError(error!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: loading ? null : submit,
            child: const Text('Update password'),
          ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AuroraBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.indigo.withValues(alpha: 0.10),
                        blurRadius: 36,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Entrance(
                        delay: const Duration(milliseconds: 80),
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Entrance(
                        delay: const Duration(milliseconds: 150),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Entrance(
                        delay: const Duration(milliseconds: 230),
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthError extends StatelessWidget {
  const _AuthError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEEEEF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
