import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Prevents a standalone/deep-linked page from closing the Android app when
/// there is no route underneath it.
///
/// Back is intercepted before Navigator begins popping. This avoids mutating
/// go_router from a PopScope notification while Flutter is deactivating route
/// elements (which can trigger framework `_dependents.isEmpty` assertions).
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
  bool _handlingBack = false;

  Future<bool> _onBackButtonPressed() async {
    // Returning true tells Router that this Back event was fully handled, so
    // no second pop/deactivation runs underneath our navigation operation.
    if (_handlingBack) return true;
    _handlingBack = true;

    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      final currentPath = router.routeInformationProvider.value.uri.path;
      if (currentPath != widget.fallbackLocation) {
        router.go(widget.fallbackLocation);
      }
    }

    if (mounted) _handlingBack = false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: _onBackButtonPressed,
      child: widget.child,
    );
  }
}
