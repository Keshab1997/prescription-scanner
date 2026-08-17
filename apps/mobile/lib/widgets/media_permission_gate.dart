import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prescription_scanner/legal/legal_copy.dart';
import 'package:prescription_scanner/services/app_prefs.dart';
import 'package:prescription_scanner/services/media_permissions.dart';
import 'package:prescription_scanner/theme.dart';

/// Asks for the Android/iOS camera and photos dialogs once after install.
class MediaPermissionGate extends StatefulWidget {
  const MediaPermissionGate({super.key});

  @override
  State<MediaPermissionGate> createState() => _MediaPermissionGateState();
}

class _MediaPermissionGateState extends State<MediaPermissionGate> {
  static bool _askedThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAsk());
    });
  }

  Future<void> _maybeAsk() async {
    if (!mounted || _askedThisSession) return;
    // Widget tests have no Hive prefs / permission plugin.
    if (!AppPrefs.isReady) return;
    if (AppPrefs.hasAskedMediaPermissions) return;
    _askedThisSession = true;

    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.photo_camera_outlined, color: AppColors.teal),
        title: const Text('Camera and photos'),
        content: const Text(
          '${LegalCopy.cameraRationale}\n\n'
          'Photos/gallery is used only when you pick an existing prescription image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (go == true) {
      await MediaPermissions.requestOnFirstLaunch();
    }
    await AppPrefs.markMediaPermissionsAsked();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
