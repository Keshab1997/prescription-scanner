import 'dart:math' as math;

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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? error;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (!bindingName.contains('TestWidgetsFlutterBinding')) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    _float.dispose();
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        Entrance(
                          delay: const Duration(milliseconds: 40),
                          child: _LoginHero(float: _float),
                        ),
                        const SizedBox(height: 6),
                        Entrance(
                          delay: const Duration(milliseconds: 120),
                          child: Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Entrance(
                          delay: const Duration(milliseconds: 180),
                          child: const Text(
                            'Scan smarter. Understand clearly.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Entrance(
                          delay: const Duration(milliseconds: 220),
                          child: const _TrustPills(),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
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
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                22,
                                22,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Entrance(
                                    delay: const Duration(milliseconds: 260),
                                    child: GoogleSignInButton(
                                      onBusy: (busy) =>
                                          setState(() => loading = busy),
                                      onError: (message) =>
                                          setState(() => error = message),
                                    ),
                                  ),
                                  const AuthDivider(label: 'or sign in with email'),
                                  const _FieldLabel('Email address'),
                                  TextField(
                                    controller: email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: const InputDecoration(
                                      hintText: 'name@example.com',
                                      prefixIcon: Icon(
                                        Icons.mail_outline_rounded,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const _FieldLabel('Password'),
                                  TextField(
                                    controller: password,
                                    obscureText: obscure,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    onSubmitted: (_) => submit(),
                                    decoration: InputDecoration(
                                      hintText: 'Enter your password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                      ),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(
                                          () => obscure = !obscure,
                                        ),
                                        icon: Icon(
                                          obscure
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: loading
                                          ? null
                                          : () =>
                                                context.push('/forgot-password'),
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  if (error != null)
                                    Container(
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
                                  ScaleTap(
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
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: loading
                                        ? null
                                        : () => context.push('/register'),
                                    child: const Text(
                                      'New here? Create an account',
                                    ),
                                  ),
                                  TextButton.icon(
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
                                  const SizedBox(height: 4),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 4,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            context.push('/privacy'),
                                        child: const Text('Privacy'),
                                      ),
                                      TextButton(
                                        onPressed: () => context.push('/terms'),
                                        child: const Text('Terms'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            context.push('/disclaimer'),
                                        child: const Text('Disclaimer'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.tealSoft.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.line),
                                    ),
                                    child: const Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                ],
                              ),
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
        ],
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.float});

  final Animation<double> float;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: float,
      builder: (context, child) {
        final t = float.value;
        final dy = math.sin(t * 2 * math.pi) * 8;
        final tilt = math.sin(t * 2 * math.pi + 0.6) * 0.018;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: tilt, child: child),
        );
      },
      child: SizedBox(
        height: 210,
        child: Image.asset(
          'assets/onboarding/login_hero.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _TrustPills extends StatelessWidget {
  const _TrustPills();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill(icon: Icons.document_scanner_outlined, label: 'Scan in seconds'),
        _Pill(icon: Icons.auto_awesome_outlined, label: 'AI reads it'),
        _Pill(icon: Icons.lock_outline_rounded, label: 'Private on device'),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.teal),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
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
