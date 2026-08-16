import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Prevents a standalone/deep-linked page from closing the Android app when
/// there is no route underneath it.
///
/// A normal pushed page still pops to its real previous page. If the current
/// page is the root of the navigator, Back navigates to [fallbackLocation]
/// instead of allowing the system to exit the app.
class AppBackScope extends StatefulWidget {
  const AppBackScope({
    required this.fallbackLocation,
    required this.child,
    super.key,
  });

  final String fallbackLocation;
  final Widget child;

  @override
  State<AppBackScope> createState() => _AppBackScopeState();
}

class _AppBackScopeState extends State<AppBackScope> {
  bool _backNavigationScheduled = false;

  void _handleBack(bool didPop) {
    if (didPop || _backNavigationScheduled) return;
    _backNavigationScheduled = true;

    // Never mutate go_router's route tree from inside PopScope's notification.
    // At that point Flutter may still be deactivating inherited elements; a
    // synchronous pop/go can trigger framework `_dependents.isEmpty` asserts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        final currentPath = router.routeInformationProvider.value.uri.path;
        if (currentPath != widget.fallbackLocation) {
          router.go(widget.fallbackLocation);
        }
      }

      if (mounted) _backNavigationScheduled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: widget.child,
    );
  }
}
