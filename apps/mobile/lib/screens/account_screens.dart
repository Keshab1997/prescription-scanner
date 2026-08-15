import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(authServiceProvider);
    final user = service.currentUser;
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Prescription Scanner User';
    final email = user?.email ?? 'Not signed in';
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

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
                    initials.isEmpty ? 'PS' : initials,
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
                      Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$email · Free plan',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Scan limits & rewards',
                  onTap: () {},
                ),
                _ProfileRow(
                  icon: Icons.shield_outlined,
                  title: 'Privacy & consent',
                  onTap: () {},
                ),
                _ProfileRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & support',
                  subtitle: 'keshabsarkar2018@gmail.com',
                  onTap: () {},
                ),
                _ProfileRow(
                  icon: Icons.info_outline_rounded,
                  title: 'Medical disclaimer',
                  onTap: () {},
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
                    await service?.signOut();
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
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: ListTile(
          onTap: onTap,
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
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}
