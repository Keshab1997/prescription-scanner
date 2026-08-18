import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/router.dart';
import 'package:prescription_scanner/screens/force_update_screen.dart';
import 'package:prescription_scanner/screens/splash_screen.dart';
import 'package:prescription_scanner/services/play_in_app_update.dart';
import 'package:prescription_scanner/theme.dart';

class PrescriptionScannerApp extends ConsumerStatefulWidget {
  const PrescriptionScannerApp({
    super.key,
    this.skipLaunchSplash = false,
    this.skipPlayUpdate = false,
    this.playUpdater = const PlayInAppUpdate(),
  });

  /// Widget tests skip the 2.2s branded overlay so pumps stay finite.
  final bool skipLaunchSplash;

  /// Widget tests skip the Play Store check (plugin is not registered).
  final bool skipPlayUpdate;

  final PlayInAppUpdate playUpdater;

  @override
  ConsumerState<PrescriptionScannerApp> createState() =>
      _PrescriptionScannerAppState();
}

class _PrescriptionScannerAppState
    extends ConsumerState<PrescriptionScannerApp> {
  late bool _showLaunchSplash = !widget.skipLaunchSplash;
  PlayUpdateAction? _requiredUpdate;

  @override
  void initState() {
    super.initState();
    SystemNavigator.setFrameworkHandlesBack(true);
    if (widget.skipLaunchSplash && !widget.skipPlayUpdate) {
      unawaited(_checkPlayUpdate());
    }
  }

  void _finishLaunchSplash() {
    if (!mounted || !_showLaunchSplash) return;
    setState(() => _showLaunchSplash = false);
    if (!widget.skipPlayUpdate) unawaited(_checkPlayUpdate());
  }

  Future<void> _checkPlayUpdate() async {
    if (widget.skipPlayUpdate) return;
    final action = await widget.playUpdater.check();
    if (!mounted || action == PlayUpdateAction.none) return;
    setState(() => _requiredUpdate = action);
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
            if (_requiredUpdate != null)
              ForceUpdateGate(
                action: _requiredUpdate!,
                updater: widget.playUpdater,
              ),
          ],
        );
      },
    );
  }
}
