import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/legal/legal_copy.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:prescription_scanner/widgets/google_sign_in_button.dart';
import 'package:prescription_scanner/widgets/media_permission_gate.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!email.text.contains('@') || password.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }
    final service = ref.read(authServiceProvider);

    setState(() {
      loading = true;
      error = null;
    });
    try {
      await service.signIn(email: email.text, password: password.text);
      if (mounted) {
        await offerGuestHistoryMerge(context, service);
      }
      if (mounted) context.go('/home');
    } catch (exception) {
      if (mounted) setState(() => error = friendlyAuthError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const MediaPermissionGate(),
          AuroraBackdrop(
            child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.indigo.withValues(alpha: 0.12),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: AutofillGroup(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 32, 26, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Entrance(
                            delay: const Duration(milliseconds: 60),
                            child: Center(
                              child: Container(
                                width: 88,
                                height: 88,
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.brandGradient,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(7),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(40),
                                    child: Image.asset(
                                      'assets/brand/app_icon.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Entrance(
                            delay: const Duration(milliseconds: 140),
                            child: Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Entrance(
                            delay: const Duration(milliseconds: 200),
                            child: const Text(
                              'Scan smarter. Understand clearly.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Entrance(
                            delay: const Duration(milliseconds: 260),
                            child: const _FieldLabel('Email address'),
                          ),
                          Entrance(
                            delay: const Duration(milliseconds: 320),
                            child: TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                hintText: 'name@example.com',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Entrance(
                            delay: const Duration(milliseconds: 380),
                            child: const _FieldLabel('Password'),
                          ),
                          Entrance(
                            delay: const Duration(milliseconds: 440),
                            child: TextField(
                              controller: password,
                              obscureText: obscure,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => submit(),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => obscure = !obscure),
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: loading
                                  ? null
                                  : () => context.push('/forgot-password'),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          if (error != null)
                            Entrance(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEEEEF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          Entrance(
                            delay: const Duration(milliseconds: 480),
                            child: GoogleSignInButton(
                              onBusy: (busy) => setState(() => loading = busy),
                              onError: (message) =>
                                  setState(() => error = message),
                            ),
                          ),
                          const AuthDivider(),
                          Entrance(
                            delay: const Duration(milliseconds: 500),
                            child: ScaleTap(
                              onTap: loading ? null : submit,
                              pressedScale: 0.97,
                              child: Container(
                                height: 56,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(17),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x554F46E5),
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: loading
                                    ? const SizedBox.square(
                                        dimension: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Sign in securely',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Entrance(
                            delay: const Duration(milliseconds: 560),
                            child: TextButton(
                              onPressed: loading
                                  ? null
                                  : () => context.push('/register'),
                              child: const Text('New here? Create an account'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Entrance(
                            delay: const Duration(milliseconds: 590),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => context.push('/privacy'),
                                  child: const Text('Privacy'),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/terms'),
                                  child: const Text('Terms'),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/disclaimer'),
                                  child: const Text('Disclaimer'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Entrance(
                            delay: const Duration(milliseconds: 600),
                            child: TextButton.icon(
                              onPressed: loading
                                  ? null
                                  : () => context.go('/home'),
                              icon: const Icon(
                                Icons.document_scanner_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'Try a free scan without signing in',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Entrance(
                            delay: const Duration(milliseconds: 620),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.tealSoft.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    color: AppColors.teal,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${LegalCopy.medicalShort} ${LegalCopy.privacySummary}',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
