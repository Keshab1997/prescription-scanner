import 'package:firebase_analytics/firebase_analytics.dart';

/// Fail-safe Firebase Analytics helper.
///
/// Analytics is a non-critical enhancement: a failing analytics call must
/// never break the user flow, so every method swallows errors quietly.
abstract final class AnalyticsService {
  static Future<void> _log(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {
      // Analytics must never break the app.
    }
  }

  /// A user signed in successfully.
  static Future<void> logLogin({String method = 'email'}) =>
      _log('login', parameters: {'method': method});

  /// A new account was created.
  static Future<void> logSignUp({String method = 'email'}) =>
      _log('sign_up', parameters: {'method': method});

  /// A user started a scan (guest = scanned without an account).
  static Future<void> logScanStarted({bool guest = false}) =>
      _log('scan_started', parameters: {'guest': guest});

  /// A scan finished with a successful extraction.
  static Future<void> logScanSucceeded({bool guest = false}) =>
      _log('scan_succeeded', parameters: {'guest': guest});

  /// A scan failed.
  static Future<void> logScanFailed({String? reason}) =>
      _log('scan_failed', parameters: {'reason': reason ?? 'unknown'});

  /// A user deleted their account and data.
  static Future<void> logAccountDeleted() => _log('account_deleted');
}
