import 'dart:io';

/// Lightweight connectivity check without extra packages.
abstract final class NetworkStatus {
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup(
        'dns.google',
      ).timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
