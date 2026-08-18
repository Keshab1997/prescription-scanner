import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  static const _fieldPad = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

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
    final height = MediaQuery.sizeOf(context).height;
    final heroHeight = (height * 0.20).clamp(96.0, 148.0);

    return Scaffold(
      body: Stack(
        children: [
          const MediaPermissionGate(),
          AuroraBackdrop(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        _LoginHero(float: _float, height: heroHeight),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Scan smarter. Understand clearly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.indigo.withValues(alpha: 0.10),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: AutofillGroup(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GoogleSignInButton(
                                    onBusy: (busy) =>
                                        setState(() => loading = busy),
                                    onError: (message) =>
                                        setState(() => error = message),
                                  ),
                                  const AuthDivider(),
                                  TextField(
                                    controller: email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: const InputDecoration(
                                      hintText: 'Email address',
                                      prefixIcon: Icon(
                                        Icons.mail_outline_rounded,
                                      ),
                                      contentPadding: _fieldPad,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: password,
                                    obscureText: obscure,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    onSubmitted: (_) => submit(),
                                    decoration: InputDecoration(
                                      hintText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                      ),
                                      contentPadding: _fieldPad,
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
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: loading
                                          ? null
                                          : () => context.push(
                                              '/forgot-password',
                                            ),
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  if (error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Text(
                                        error!,
                                        style: const TextStyle(
                                          color: AppColors.danger,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ScaleTap(
                                    onTap: loading ? null : submit,
                                    pressedScale: 0.97,
                                    child: Container(
                                      height: 52,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.brandGradient,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(16),
                                        ),
                                      ),
                                      child: loading
                                          ? const SizedBox.square(
                                              dimension: 20,
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
                                  const SizedBox(height: 6),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 4,
                                    children: [
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: loading
                                            ? null
                                            : () => context.push('/register'),
                                        child: const Text('Create an account'),
                                      ),
                                      const Text(
                                        '·',
                                        style: TextStyle(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: loading
                                            ? null
                                            : () => context.go('/home'),
                                        child: const Text('Free scan'),
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 2,
                                    children: [
                                      _LegalLink(
                                        'Privacy',
                                        () => context.push('/privacy'),
                                      ),
                                      _LegalLink(
                                        'Terms',
                                        () => context.push('/terms'),
                                      ),
                                      _LegalLink(
                                        'Disclaimer',
                                        () => context.push('/disclaimer'),
                                      ),
                                    ],
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

class _LegalLink extends StatelessWidget {
  const _LegalLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.muted,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.float, required this.height});

  final Animation<double> float;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: float,
      builder: (context, child) {
        final t = float.value;
        final dy = math.sin(t * 2 * math.pi) * 5;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: SizedBox(
        height: height,
        child: Image.asset(
          'assets/onboarding/login_hero.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
