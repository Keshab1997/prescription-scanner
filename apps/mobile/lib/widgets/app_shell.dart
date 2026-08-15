import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

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
        floatingActionButton: _ScanFab(
          onTap: () {
            context.push('/upload');
          },
        ),
        bottomNavigationBar: _FloatingNavBar(
          currentPath: currentPath,
          onChanged: (path) => context.go(path),
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  const _ScanFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: ScaleTap(
        onTap: onTap,
        pressedScale: 0.88,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.brandGradient,
            boxShadow: [
              BoxShadow(
                color: Color(0x664F46E5),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.document_scanner_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentPath, required this.onChanged});

  final String currentPath;
  final ValueChanged<String> onChanged;

  bool _is(String path) => currentPath == path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 72,
          color: Colors.white,
          child: Row(
            children: [
              _NavItem(
                label: 'Home',
                icon: Icons.home_rounded,
                selected: _is('/home'),
                onTap: () => onChanged('/home'),
              ),
              _NavItem(
                label: 'History',
                icon: Icons.history_rounded,
                selected: _is('/history'),
                onTap: () => onChanged('/history'),
              ),
              const SizedBox(width: 62), // FAB cradle
              _NavItem(
                label: 'Help',
                icon: Icons.help_outline_rounded,
                selected: false,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Help centre is coming next.'),
                  ),
                ),
              ),
              _NavItem(
                label: 'Profile',
                icon: Icons.person_rounded,
                selected: _is('/profile'),
                onTap: () => onChanged('/profile'),
              ),
            ],
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
    return Expanded(
      child: ScaleTap(
        onTap: onTap,
        pressedScale: 0.92,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.tealSoft.withValues(alpha: 0.9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? Colors.white : AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: selected ? 1 : 0.55,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.teal : AppColors.muted,
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