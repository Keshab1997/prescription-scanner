import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:prescription_scanner/widgets/about_card.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final data = await ref.read(authServiceProvider).fetchProfile();
      if (mounted) setState(() => _profile = data);
    } catch (e) {
      if (mounted) setState(() => _profileError = 'Could not load profile.');
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _refreshAll() async {
    try {
      await ref.read(authServiceProvider).currentUser?.reload();
    } catch (_) {}
    ref.invalidate(quotaProvider);
    ref.invalidate(prescriptionHistoryProvider);
    await _loadProfile();
  }

  String get _displayName {
    final fromProfile = _profile?['displayName'] as String?;
    if (fromProfile != null && fromProfile.trim().isNotEmpty) {
      return fromProfile.trim();
    }
    final authName = ref.read(authServiceProvider).currentUser?.displayName;
    if (authName != null && authName.trim().isNotEmpty) return authName.trim();
    return 'Prescription Scanner User';
  }

  String get _email {
    final fromProfile = _profile?['email'] as String?;
    if (fromProfile != null && fromProfile.trim().isNotEmpty) {
      return fromProfile.trim();
    }
    return ref.read(authServiceProvider).currentUser?.email ?? 'Not signed in';
  }

  String? get _memberSince {
    final created = _profile?['createdAt'];
    if (created is Timestamp) {
      return DateFormat('MMM y').format(created.toDate());
    }
    return null;
  }

  String get _initials {
    final parts = _displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2);
    final joined = parts.map((p) => p[0].toUpperCase()).join();
    return joined.isEmpty ? 'PS' : joined;
  }

  Future<void> requestDeletion(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
        title: const Text('Delete account and data?'),
        content: const Text(
          'This permanently deletes your account, scan history and all associated data from the app and our servers. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final service = ref.read(authServiceProvider);
    try {
      await service.requestAccountDeletion();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account and data have been deleted.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyAuthError(e))));
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final service = ref.read(authServiceProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in anytime. Your scan history stays on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await service.signOut();
    if (context.mounted) context.go('/login');
  }

  Future<void> _resendVerification(BuildContext context) async {
    try {
      await ref.read(authServiceProvider).resendEmailVerification();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email sent. Check your inbox — and your Spam/Junk '
            'folder if it is not there.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyAuthError(e))));
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    final nameController = TextEditingController(text: _displayName);
    final formKey = GlobalKey<FormState>();
    var loading = false;
    var error = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit profile',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter your name.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _email,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        error,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading
                                ? null
                                : () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: loading
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setSheet(() {
                                      loading = true;
                                      error = '';
                                    });
                                    try {
                                      await ref
                                          .read(authServiceProvider)
                                          .updateProfile(
                                            displayName: nameController.text,
                                          );
                                      if (!mounted) return;
                                      await _loadProfile();
                                      if (context.mounted) {
                                        Navigator.pop(sheetContext);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Profile updated.'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setSheet(
                                        () => error = friendlyAuthError(e),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setSheet(() => loading = false);
                                      }
                                    }
                                  },
                            child: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    nameController.dispose();
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var loading = false;
    var error = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change password',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: current,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (value) =>
                          (value?.isEmpty ?? true) ? 'Required.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: next,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirm,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (value) =>
                          value != next.text ? 'Passwords do not match.' : null,
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        error,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading
                                ? null
                                : () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: loading
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setSheet(() {
                                      loading = true;
                                      error = '';
                                    });
                                    try {
                                      await ref
                                          .read(authServiceProvider)
                                          .changePassword(
                                            currentPassword: current.text,
                                            newPassword: next.text,
                                          );
                                      if (context.mounted) {
                                        Navigator.pop(sheetContext);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Password updated.'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setSheet(
                                        () => error = friendlyAuthError(e),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setSheet(() => loading = false);
                                      }
                                    }
                                  },
                            child: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Update'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  Future<void> _showInfoDialog({
    required BuildContext context,
    required String title,
    required String body,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanLimits(BuildContext context, [ScanQuota? quota]) async {
    ScanQuota? q = quota;
    if (q == null) {
      try {
        q = await ref.read(quotaProvider.future);
      } catch (_) {
        q = null;
      }
    }
    if (!context.mounted) return;
    await _showInfoDialog(
      context: context,
      title: 'Scan limits & rewards',
      body: q == null
          ? 'Scan limits are set by the app administrator. Check back later.'
          : 'You have ${q.remaining} of ${q.dailyLimit} scans remaining today. '
                'Used ${q.used} so far. Limits reset daily and are configured by the administrator.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(authServiceProvider);
    final quotaAsync = ref.watch(quotaProvider);
    final historyAsync = ref.watch(prescriptionHistoryProvider);
    final verified = service.currentUser?.emailVerified ?? false;

    final totalScans = historyAsync.when(
      data: (items) => items.length.toString(),
      error: (_, _) => null,
      loading: () => null,
    );
    final scansToday = quotaAsync.when(
      data: (quota) => quota.used.toString(),
      error: (_, _) => null,
      loading: () => null,
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            Entrance(
              child: _ProfileHeader(
                name: _displayName,
                email: _email,
                initials: _initials,
                loading: _loadingProfile,
                verified: verified,
                onEdit: _loadingProfile ? null : () => _editProfile(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_profileError != null) ...[
                    Entrance(child: _InlineProfileError(onRetry: _loadProfile)),
                    const SizedBox(height: 12),
                  ],
                  Entrance(
                    delay: const Duration(milliseconds: 80),
                    child: _StatsStrip(
                      totalScans: totalScans,
                      scansToday: scansToday,
                      memberSince: _memberSince,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('Account'),
                  const SizedBox(height: 10),
                  Entrance(
                    delay: const Duration(milliseconds: 140),
                    child: _ProfileRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit profile',
                      subtitle: _email,
                      onTap: () => _editProfile(context),
                    ),
                  ),
                  if (!verified)
                    Entrance(
                      delay: const Duration(milliseconds: 200),
                      child: _ProfileRow(
                        icon: Icons.mark_email_unread_outlined,
                        title: 'Verify email',
                        subtitle: 'Tap to resend the verification link',
                        onTap: () => _resendVerification(context),
                      ),
                    ),
                  Entrance(
                    delay: Duration(milliseconds: verified ? 200 : 260),
                    child: _ProfileRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Change password',
                      onTap: () => _changePassword(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('Support'),
                  const SizedBox(height: 10),
                  Entrance(
                    delay: const Duration(milliseconds: 260),
                    child: quotaAsync.when(
                      loading: () => const _ProfileRow(
                        icon: Icons.bolt_outlined,
                        title: 'Scan limits & rewards',
                        subtitle: 'Checking today’s limit…',
                        onTap: null,
                      ),
                      error: (_, _) => _ProfileRow(
                        icon: Icons.bolt_outlined,
                        title: 'Scan limits & rewards',
                        subtitle: 'Tap to retry',
                        onTap: () => _openScanLimits(context),
                      ),
                      data: (quota) => _ProfileRow(
                        icon: Icons.bolt_outlined,
                        title: 'Scan limits & rewards',
                        subtitle:
                            '${quota.remaining} of ${quota.dailyLimit} scans left today',
                        onTap: () => _openScanLimits(context, quota),
                      ),
                    ),
                  ),
                  Entrance(
                    delay: const Duration(milliseconds: 320),
                    child: _ProfileRow(
                      icon: Icons.shield_outlined,
                      title: 'Privacy & consent',
                      onTap: () => _showInfoDialog(
                        context: context,
                        title: 'Privacy & consent',
                        body:
                            'Your prescription image is sent directly for AI-powered transcription. The app does not store the image in its own cloud database; the prepared local image is deleted after processing, and the structured result remains on this device under your account.',
                      ),
                    ),
                  ),
                  Entrance(
                    delay: const Duration(milliseconds: 380),
                    child: _ProfileRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & support',
                      subtitle: 'keshabsarkar2018@gmail.com',
                      onTap: () => _showInfoDialog(
                        context: context,
                        title: 'Help & support',
                        body:
                            'For help with Prescription Scanner, email us at keshabsarkar2018@gmail.com. We usually respond within 1–2 business days.',
                      ),
                    ),
                  ),
                  Entrance(
                    delay: const Duration(milliseconds: 440),
                    child: _ProfileRow(
                      icon: Icons.info_outline_rounded,
                      title: 'Medical disclaimer',
                      onTap: () => _showInfoDialog(
                        context: context,
                        title: 'Medical disclaimer',
                        body:
                            'Prescription Scanner provides AI-assisted transcription for informational purposes only. It is not a medical device and does not provide medical advice, diagnosis, or treatment. Always confirm details with your doctor or pharmacist before acting on any extracted information.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('Danger zone'),
                  const SizedBox(height: 10),
                  Entrance(
                    delay: const Duration(milliseconds: 500),
                    child: _ProfileRow(
                      icon: Icons.logout_rounded,
                      title: 'Sign out',
                      onTap: () => _confirmSignOut(context),
                    ),
                  ),
                  Entrance(
                    delay: const Duration(milliseconds: 560),
                    child: _ProfileRow(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete account & data',
                      danger: true,
                      onTap: () => requestDeletion(context, ref),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('About'),
                  const SizedBox(height: 10),
                  Entrance(
                    delay: const Duration(milliseconds: 600),
                    child: const AboutCard(),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Prescription Scanner · Keshab Studios',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.initials,
    required this.loading,
    required this.verified,
    this.onEdit,
  });

  final String name;
  final String email;
  final String initials;
  final bool loading;
  final bool verified;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppColors.softGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ScaleTap(
                onTap: onEdit,
                pressedScale: 0.9,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.totalScans,
    required this.scansToday,
    required this.memberSince,
  });

  final String? totalScans;
  final String? scansToday;
  final String? memberSince;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _Stat(value: totalScans, label: 'Total scans'),
            ),
            Container(width: 1, height: 30, color: AppColors.line),
            Expanded(
              child: _Stat(value: scansToday, label: 'Scans today'),
            ),
            Container(width: 1, height: 30, color: AppColors.line),
            Expanded(
              child: _Stat(value: memberSince, label: 'Member since'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (value == null)
          const ShimmerBox(height: 16, width: 46, radius: 8)
        else
          Text(
            value!,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InlineProfileError extends StatelessWidget {
  const _InlineProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.error_outline_rounded,
          color: AppColors.danger,
        ),
        title: const Text(
          'Could not load profile details',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        trailing: IconButton(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: danger
                        ? const Color(0xFFFEEEEF)
                        : AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: danger ? AppColors.danger : AppColors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: danger ? AppColors.danger : AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
