import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Prevents a standalone/deep-linked page from closing the Android app when
/// there is no route underneath it.
///
/// A normal pushed page still pops to its real previous page. If the current
/// page is the root of the navigator, Back navigates to [fallbackLocation]
/// instead of allowing the system to exit the app.
class AppBackScope extends StatelessWidget {
  const AppBackScope({
    required this.fallbackLocation,
    required this.child,
    super.key,
  });

  final String fallbackLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }

        final currentLocation = router.routeInformationProvider.value.uri
            .toString();
        if (currentLocation != fallbackLocation) {
          context.go(fallbackLocation);
        }
      },
      child: child,
    );
  }
}
