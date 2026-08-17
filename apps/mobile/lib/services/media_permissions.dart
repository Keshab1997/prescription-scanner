import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// System camera / photos prompts. Failures are swallowed in tests.
abstract final class MediaPermissions {
  static Future<bool> ensureCamera() async {
    return _request(Permission.camera);
  }

  static Future<bool> ensureGallery() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        if (info.version.sdkInt >= 33) {
          return _request(Permission.photos);
        }
        return _request(Permission.storage);
      } catch (error) {
        debugPrint('[permissions] gallery check skipped: $error');
        return _request(Permission.photos);
      }
    }
    return _request(Permission.photos);
  }

  static Future<bool> requestOnFirstLaunch() async {
    final camera = await ensureCamera();
    final gallery = await ensureGallery();
    return camera || gallery;
  }

  static Future<bool> _request(Permission permission) async {
    try {
      var status = await permission.status;
      if (status.isGranted || status.isLimited) return true;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        status = await permission.status;
        return status.isGranted || status.isLimited;
      }
      status = await permission.request();
      return status.isGranted || status.isLimited;
    } catch (error) {
      debugPrint('[permissions] $permission skipped: $error');
      return true;
    }
  }
}
