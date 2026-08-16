import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/router.dart';
import 'package:prescription_scanner/screens/splash_screen.dart';
import 'package:prescription_scanner/theme.dart';

class PrescriptionScannerApp extends ConsumerStatefulWidget {
  const PrescriptionScannerApp({super.key});

  @override
  ConsumerState<PrescriptionScannerApp> createState() =>
      _PrescriptionScannerAppState();
}

class _PrescriptionScannerAppState
    extends ConsumerState<PrescriptionScannerApp> {
  bool _showLaunchSplash = true;

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
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child,
            if (_showLaunchSplash)
              AnimatedLaunchSplash(onFinished: _finishLaunchSplash),
          ],
        );
      },
    );
  }
}
