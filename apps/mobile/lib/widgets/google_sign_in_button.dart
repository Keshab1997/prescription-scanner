import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/theme.dart';

/// Shared Google button + optional guest-history merge prompt.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({
    super.key,
    this.label = 'Continue with Google',
    this.requireAcceptedTerms = false,
    this.acceptedTerms = true,
    this.onBusy,
    this.onError,
  });

  final String label;
  final bool requireAcceptedTerms;
  final bool acceptedTerms;
  final ValueChanged<bool>? onBusy;
  final ValueChanged<String>? onError;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (widget.requireAcceptedTerms && !widget.acceptedTerms) {
      widget.onError?.call('Accept the Privacy Policy and Terms to continue.');
      return;
    }
    final service = ref.read(authServiceProvider);
    setState(() => _busy = true);
    widget.onBusy?.call(true);
    try {
      final signedIn = await service.signInWithGoogle();
      if (!signedIn || !mounted) return;
      await offerGuestHistoryMerge(context, service);
      if (mounted) context.go('/home');
    } catch (error) {
      widget.onError?.call(friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBusy?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _busy ? null : _tap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: const BorderSide(color: AppColors.line),
        backgroundColor: Colors.white,
      ),
      child: _busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4285F4),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'or'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

Future<void> offerGuestHistoryMerge(
  BuildContext context,
  AuthService service,
) async {
  final count = service.guestHistoryCount();
  if (count == 0 || !context.mounted) return;
  final merge = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keep guest scans?'),
      content: Text(
        'This phone has $count guest scan${count == 1 ? '' : 's'} saved on the device. Move them into this Google account?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Leave them as guest'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Move to my account'),
        ),
      ],
    ),
  );
  if (merge == true) {
    await service.mergeGuestHistory();
  }
}
