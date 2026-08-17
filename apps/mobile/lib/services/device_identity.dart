import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Stable, per-device identifier used to track anonymous guest scan usage
/// server-side.
///
/// On Android this is the ANDROID_ID, which survives clearing the app's data
/// and reinstalls (it only changes after a factory reset or a different
/// signing key), so clearing app data cannot reset the guest free-scan
/// allowance. Falls back to null when the ID cannot be determined (e.g. web).
abstract final class DeviceIdentity {
  static String? _cached;

  /// A stable device-scoped id, or null when unavailable.
  static Future<String?> get id async {
    if (_cached != null) return _cached;
    if (kIsWeb) return null;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final androidId = info.id;
        if (androidId.isNotEmpty && androidId != 'unknown') {
          _cached = 'android-$androidId';
        }
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final vendorId = info.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) {
          _cached = 'ios-$vendorId';
        }
      }
    } catch (_) {
      // Platform channel failures must never block quota handling.
    }
    return _cached;
  }
}
