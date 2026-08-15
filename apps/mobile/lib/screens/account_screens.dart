import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';
import 'package:prescription_scanner/theme.dart';

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
          'This submits a permanent deletion request for your account, history and associated data. This cannot be undone after completion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request deletion'),
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
        const SnackBar(content: Text('Account deletion request submitted.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit the request. Try again.'),
        ),
      );
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
                      validator: (value) =>
                          (value?.trim().length ?? 0) < 2
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
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
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
                    validator: (value) => value != next.text
                        ? 'Passwords do not match.'
                        : null,
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
                                  if (!formKey.currentState!.validate()) return;
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
                                      ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(authServiceProvider);
    final quotaAsync = ref.watch(quotaProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 170,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.teal, AppColors.indigo],
              ),
            ),
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 20,
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
                      if (_loadingProfile)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else ...[
                        Text(
                          _displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_profileError != null)
                        const Text(
                          'Could not load profile',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadingProfile ? null : () => _editProfile(context),
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Edit profile',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            child: Column(
              children: [
                quotaAsync.when(
                  loading: () => const _ProfileRow(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Scan limits & rewards',
                    onTap: null,
                  ),
                  error: (_, _) => _ProfileRow(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Scan limits & rewards',
                    onTap: () => _openScanLimits(context),
                  ),
                  data: (quota) => _ProfileRow(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Scan limits & rewards',
                    subtitle:
                        '${quota.remaining} of ${quota.dailyLimit} scans left today',
                    onTap: () => _openScanLimits(context, quota),
                  ),
                ),
                _ProfileRow(
                  icon: Icons.shield_outlined,
                  title: 'Privacy & consent',
                  onTap: () => _showInfoDialog(
                    context: context,
                    title: 'Privacy & consent',
                    body:
                        'Your prescription images and results are processed on your device and stored only locally. They are never uploaded to any server, and Gemini is called directly from your device. See the app privacy policy for details.',
                  ),
                ),
                _ProfileRow(
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
                _ProfileRow(
                  icon: Icons.info_outline_rounded,
                  title: 'Medical disclaimer',
                  onTap: () => _showInfoDialog(
                    context: context,
                    title: 'Medical disclaimer',
                    body:
                        'Prescription Scanner provides AI-assisted transcription for informational purposes only. It is not a medical device and does not provide medical advice, diagnosis, or treatment. Always confirm details with your doctor or pharmacist before acting on any extracted information.',
                  ),
                ),
                _ProfileRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change password',
                  onTap: () => _changePassword(context),
                ),
                _ProfileRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete account & data',
                  danger: true,
                  onTap: () => requestDeletion(context, ref),
                ),
                _ProfileRow(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  onTap: () async {
                    await service.signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
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
        child: ListTile(
          onTap: onTap,
          enabled: onTap != null,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: danger ? const Color(0xFFFEEEEF) : AppColors.tealSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: danger ? AppColors.danger : AppColors.teal,
              size: 20,
            ),
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
              : Text(subtitle!, style: const TextStyle(fontSize: 11)),
          trailing: onTap == null
              ? null
              : const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}
