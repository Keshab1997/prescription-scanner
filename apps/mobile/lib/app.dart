import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/router.dart';
import 'package:prescription_scanner/screens/splash_screen.dart';
import 'package:prescription_scanner/theme.dart';

class PrescriptionScannerApp extends ConsumerStatefulWidget {
  const PrescriptionScannerApp({
    super.key,
    this.skipLaunchSplash = false,
  });

  /// Widget tests skip the 2.2s branded overlay so pumps stay finite.
  final bool skipLaunchSplash;

  @override
  ConsumerState<PrescriptionScannerApp> createState() =>
      _PrescriptionScannerAppState();
}

class _PrescriptionScannerAppState
    extends ConsumerState<PrescriptionScannerApp> {
  late bool _showLaunchSplash = !widget.skipLaunchSplash;

  @override
  void initState() {
    super.initState();
    SystemNavigator.setFrameworkHandlesBack(true);
  }

  void _finishLaunchSplash() {
    if (!mounted || !_showLaunchSplash) return;
    setState(() => _showLaunchSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Prescription Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      onNavigationNotification: (_) {
        SystemNavigator.setFrameworkHandlesBack(true);
        return true;
      },
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            if (_showLaunchSplash)
              AnimatedLaunchSplash(onFinished: _finishLaunchSplash),
          ],
        );
      },
    );
  }
}
