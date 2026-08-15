import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';
import 'package:prescription_scanner/services/result_store.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:url_launcher/url_launcher.dart';

const String supportEmail = 'keshabsarkar2018@gmail.com';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool busy = false;

  AuthService? get _service => ref.read(authServiceProvider);

  void _toast(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: danger ? AppColors.danger : null,
        ),
      );
  }

  Future<void> _editDisplayName(String current) async {
    final service = _service;
    if (service == null) {
      _toast('Sign in to update your profile.', danger: true);
      return;
    }

    final value = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initialValue: current),
    );
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == current) return;

    setState(() => busy = true);
    try {
      await service.updateDisplayName(trimmed);
      if (!mounted) return;
      setState(() {});
      _toast('Name updated.');
    } catch (exception) {
      _toast(friendlyAuthError(exception), danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _changePassword() async {
    final service = _service;
    if (service == null) {
      _toast('Sign in to change your password.', danger: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(service: service),
    );
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'Prescription Scanner support'},
    );
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (opened) return;
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    _toast('No email app found. Address copied to clipboard.');
  }

  Future<void> _clearLocalData() async {
    final confirmed = await _confirm(
      title: 'Clear saved prescriptions?',
      message:
          'Every prescription stored on this device will be removed. This '
          'only affects this device and cannot be undone.',
      confirmLabel: 'Clear data',
      danger: true,
    );
    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      await ResultStore.instance.clear();
      if (!mounted) return;
      setState(() {});
      _toast('Local prescriptions cleared.');
    } catch (_) {
      _toast('Could not clear local data.', danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _requestDeletion() async {
    final confirmed = await _confirm(
      title: 'Delete account and data?',
      message:
          'This submits a permanent deletion request for your account, '
          'history and associated data. Prescriptions saved on this device '
          'are removed immediately. This cannot be undone once completed.',
      confirmLabel: 'Request deletion',
      danger: true,
    );
    if (confirmed != true) return;

    final service = _service;
    if (service == null) {
      _toast('Sign in to request deletion.', danger: true);
      return;
    }

    setState(() => busy = true);
    try {
      await service.requestAccountDeletion();
      await ResultStore.instance.clear();
      if (!mounted) return;
      _toast('Account deletion request submitted.');
      setState(() {});
    } catch (_) {
      _toast('Could not submit the request. Try again.', danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _signOut() async {
    final wipe = await showDialog<bool>(
      context: context,
      builder: (_) => const _SignOutDialog(),
    );
    if (wipe == null) return;

    setState(() => busy = true);
    try {
      if (wipe) await ResultStore.instance.clear();
      await _service?.signOut();
      if (mounted) context.go('/login');
    } catch (_) {
      _toast('Could not sign out. Try again.', danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
          color: danger ? AppColors.danger : AppColors.teal,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet({
    required IconData icon,
    required String title,
    required List<String> paragraphs,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _InfoSheet(icon: icon, title: title, paragraphs: paragraphs),
    );
  }

  void _showScanLimits() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ScanLimitsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider)?.currentUser;
    final rawName = user?.userMetadata?['display_name']?.toString().trim();
    final displayName = (rawName == null || rawName.isEmpty)
        ? 'Prescription Scanner User'
        : rawName;
    final email = user?.email;
    final emailVerified = user?.emailConfirmedAt != null;
    final memberSince = DateTime.tryParse(user?.createdAt ?? '');

    final results = ResultStore.instance.getAll();
    final now = DateTime.now();
    final thisMonth = results
        .where(
          (r) => r.createdAt.year == now.year && r.createdAt.month == now.month,
        )
        .length;
    final needsReview = results.where((r) => r.needsManualReview).length;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _ProfileHeader(
                displayName: displayName,
                email: email,
                emailVerified: emailVerified,
                memberSince: memberSince,
                onEdit: busy ? null : () => _editDisplayName(displayName),
              ),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StatsRow(
                    total: results.length,
                    thisMonth: thisMonth,
                    needsReview: needsReview,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel('Account'),
                    _ProfileRow(
                      icon: Icons.badge_outlined,
                      title: 'Edit name',
                      subtitle: displayName,
                      onTap: busy ? null : () => _editDisplayName(displayName),
                    ),
                    _ProfileRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Change password',
                      subtitle: 'Update your sign-in password',
                      onTap: busy ? null : _changePassword,
                    ),
                    _ProfileRow(
                      icon: Icons.speed_rounded,
                      title: 'Scan limits & rewards',
                      subtitle: 'See today’s remaining scans',
                      onTap: _showScanLimits,
                    ),

                    const SizedBox(height: 18),
                    _SectionLabel('Privacy & legal'),
                    _ProfileRow(
                      icon: Icons.shield_outlined,
                      title: 'Privacy & consent',
                      subtitle: 'How your prescription data is handled',
                      onTap: () => _showInfoSheet(
                        icon: Icons.shield_outlined,
                        title: 'Privacy & consent',
                        paragraphs: const [
                          'Your prescription image is processed on your device and sent directly to the AI provider for transcription. It is never uploaded to our servers and is discarded straight after the text is extracted.',
                          'Only the structured result — medicine names, dosage and instructions — is stored, and it stays in a local database on this phone. It is not synced to the cloud.',
                          'Your email address and display name are stored by our authentication provider so you can sign in. Nothing else about you is collected.',
                          'You can remove everything at any time using “Clear local data” or “Delete account & data” on this screen.',
                        ],
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.info_outline_rounded,
                      title: 'Medical disclaimer',
                      subtitle: 'Important safety information',
                      onTap: () => _showInfoSheet(
                        icon: Icons.medical_information_outlined,
                        title: 'Medical disclaimer',
                        paragraphs: const [
                          'Prescription Scanner transcribes text that is visible on a prescription. It does not provide medical advice, diagnosis or treatment recommendations.',
                          'AI transcription can misread handwriting. Always confirm every medicine name, strength and dose with your doctor or pharmacist before taking anything.',
                          'Never start, stop or change a medicine based on what this app shows. In an emergency, contact your doctor or local emergency services immediately.',
                          'Results marked “needs review” have low confidence and must be checked by a qualified professional.',
                        ],
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.delete_sweep_outlined,
                      title: 'Clear local data',
                      subtitle: results.isEmpty
                          ? 'No prescriptions saved on this device'
                          : '${results.length} prescription${results.length == 1 ? '' : 's'} on this device',
                      onTap: busy || results.isEmpty ? null : _clearLocalData,
                    ),

                    const SizedBox(height: 18),
                    _SectionLabel('Support'),
                    _ProfileRow(
                      icon: Icons.mail_outline_rounded,
                      title: 'Help & support',
                      subtitle: supportEmail,
                      onTap: _openSupportEmail,
                      trailing: IconButton(
                        tooltip: 'Copy email',
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        color: AppColors.muted,
                        onPressed: () async {
                          await Clipboard.setData(
                            const ClipboardData(text: supportEmail),
                          );
                          _toast('Support email copied.');
                        },
                      ),
                    ),
                    const _AboutRow(),

                    const SizedBox(height: 18),
                    _SectionLabel('Danger zone'),
                    _ProfileRow(
                      icon: Icons.person_remove_outlined,
                      title: 'Delete account & data',
                      subtitle: 'Permanently remove your account',
                      danger: true,
                      onTap: busy ? null : _requestDeletion,
                    ),
                    _ProfileRow(
                      icon: Icons.logout_rounded,
                      title: 'Sign out',
                      subtitle: 'You can sign back in anytime',
                      onTap: busy ? null : _signOut,
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Made by Keshab Studios',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.emailVerified,
    required this.memberSince,
    required this.onEdit,
  });

  final String displayName;
  final String? email;
  final bool emailVerified;
  final DateTime? memberSince;
  final VoidCallback? onEdit;

  String get _initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return parts.isEmpty ? 'PS' : parts;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 46),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.teal, AppColors.indigo],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              _initials,
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email ?? 'Not signed in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (email != null)
                      _HeaderChip(
                        icon: emailVerified
                            ? Icons.verified_rounded
                            : Icons.error_outline_rounded,
                        label: emailVerified ? 'Verified' : 'Unverified',
                      ),
                    if (memberSince != null)
                      _HeaderChip(
                        icon: Icons.calendar_today_rounded,
                        label:
                            'Since ${DateFormat.yMMM().format(memberSince!.toLocal())}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit name',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.thisMonth,
    required this.needsReview,
  });

  final int total;
  final int thisMonth;
  final int needsReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _StatCell(
              value: total,
              label: 'Total scans',
              color: AppColors.teal,
            ),
            const _StatDivider(),
            _StatCell(
              value: thisMonth,
              label: 'This month',
              color: AppColors.indigo,
            ),
            const _StatDivider(),
            _StatCell(
              value: needsReview,
              label: 'Needs review',
              color: needsReview > 0 ? AppColors.amber : AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: AppColors.line);
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final accent = danger ? AppColors.danger : AppColors.teal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: ListTile(
            onTap: onTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: danger ? AppColors.danger : AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5),
                  ),
            trailing:
                trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted.withValues(alpha: 0.7),
                ),
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends ConsumerWidget {
  const _AboutRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider);
    return _ProfileRow(
      icon: Icons.info_rounded,
      title: 'About this app',
      subtitle: version.when(
        loading: () => 'Loading version…',
        error: (_, _) => 'Prescription Scanner',
        data: (value) => 'Version $value',
      ),
      onTap: () => showAboutDialog(
        context: context,
        applicationName: 'Prescription Scanner',
        applicationVersion: version.value ?? '',
        applicationLegalese: '© Keshab Studios',
        children: const [
          SizedBox(height: 12),
          Text(
            'Privacy-first AI prescription transcription. Images stay on your '
            'device; only the structured result is saved locally.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialValue,
  );
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = controller.text.trim();
    if (value.length < 2) {
      setState(() => error = 'Enter at least 2 characters.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.badge_outlined, color: AppColors.teal),
      title: const Text('Edit your name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Full name',
          errorText: error,
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _SignOutDialog extends StatefulWidget {
  const _SignOutDialog();

  @override
  State<_SignOutDialog> createState() => _SignOutDialogState();
}

class _SignOutDialogState extends State<_SignOutDialog> {
  bool wipeLocal = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.logout_rounded, color: AppColors.teal),
      title: const Text('Sign out?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('You can sign back in anytime with your email.'),
          const SizedBox(height: 6),
          CheckboxListTile(
            value: wipeLocal,
            onChanged: (value) => setState(() => wipeLocal = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Also delete prescriptions saved on this device',
              style: TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
          if (wipeLocal)
            const Text(
              'Recommended on a shared phone.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, wipeLocal),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.service});

  final AuthService service;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (password.text.length < 8) {
      setState(() => error = 'Use at least 8 characters.');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = 'The passwords do not match.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.service.updatePassword(password.text);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (exception) {
      if (mounted) setState(() => error = friendlyAuthError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.teal),
              const SizedBox(width: 10),
              Text(
                'Change password',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: password,
            obscureText: obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'New password',
              helperText: 'At least 8 characters',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: confirm,
            obscureText: obscure,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: loading ? null : _submit,
            child: loading
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update password'),
          ),
        ],
      ),
    );
  }
}

class _ScanLimitsSheet extends ConsumerWidget {
  const _ScanLimitsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(quotaProvider);
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: AppColors.teal),
              const SizedBox(width: 10),
              Text(
                'Scan limits',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          quota.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Could not load your scan limits right now. Check your '
                  'connection and try again.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => ref.invalidate(quotaProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: (value) {
              final limit = value.dailyLimit + value.rewardedBonus;
              final progress = limit == 0
                  ? 0.0
                  : (value.used / limit).clamp(0.0, 1.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${value.remaining} left today',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${value.used} / $limit used',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 9,
                      backgroundColor: AppColors.tealSoft,
                      valueColor: AlwaysStoppedAnimation(
                        value.remaining == 0
                            ? AppColors.danger
                            : AppColors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LimitRow(
                    label: 'Daily free scans',
                    value: '${value.dailyLimit}',
                  ),
                  _LimitRow(
                    label: 'Bonus from rewards',
                    value: '${value.rewardedBonus}',
                  ),
                  _LimitRow(
                    label: 'AI service',
                    value: value.aiEnabled ? 'Available' : 'Paused',
                    danger: !value.aiEnabled,
                  ),
                  if (value.maintenanceMode)
                    const _LimitRow(
                      label: 'Maintenance mode',
                      value: 'Active',
                      danger: true,
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Limits reset every day at midnight. Watch a rewarded ad '
                    'from the scan screen to earn extra scans.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: danger ? AppColors.danger : AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.icon,
    required this.title,
    required this.paragraphs,
  });

  final IconData icon;
  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          Row(
            children: [
              Icon(icon, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final paragraph in paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        paragraph,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
