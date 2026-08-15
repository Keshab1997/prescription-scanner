import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Inside the shell, back should move to Home rather than exit the
        // app. From Home, confirm before leaving the app entirely.
        if (currentPath != '/home') {
          context.go('/home');
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Exit app?'),
            content: const Text('You will be signed out of this screen.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          // Allow the pending pop so the system closes the app.
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 30),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.teal.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.push('/upload'),
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(Icons.document_scanner_rounded, size: 28),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.indigo.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomAppBar(
          color: Colors.white,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 10,
          height: 65,
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                label: 'Home',
                icon: currentPath == '/home'
                    ? Icons.home_rounded
                    : Icons.home_outlined,
                selected: currentPath == '/home',
                onTap: () => context.go('/home'),
              ),
              _NavItem(
                label: 'History',
                icon: currentPath == '/history'
                    ? Icons.history_rounded
                    : Icons.history_outlined,
                selected: currentPath == '/history',
                onTap: () => context.go('/history'),
              ),
              const SizedBox(width: 48), // Space for the notched FAB
              _NavItem(
                label: 'Help',
                icon: Icons.help_outline_rounded,
                selected: false,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Help centre is coming next.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              ),
              _NavItem(
                label: 'Profile',
                icon: currentPath == '/profile'
                    ? Icons.person_rounded
                    : Icons.person_outline_rounded,
                selected: currentPath == '/profile',
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.teal
        : AppColors.muted.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.only(bottom: 2),
              child: Icon(icon, color: color, size: selected ? 26 : 24),
            ),
            if (selected)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
