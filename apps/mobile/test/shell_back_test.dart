import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prescription_scanner/app.dart';

class _MockFirebaseAppPlatform extends FirebaseAppPlatform {
  _MockFirebaseAppPlatform(super.name, super.options);
}

class _MockFirebasePlatform extends FirebasePlatform {
  final Map<String, FirebaseAppPlatform> appsByName = {};

  @override
  List<FirebaseAppPlatform> get apps => appsByName.values.toList();

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    final appName = name ?? defaultFirebaseAppName;
    final app = _MockFirebaseAppPlatform(appName, options ?? _noOptions);
    appsByName[appName] = app;
    return app;
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      appsByName[name]!;

  static const _noOptions = FirebaseOptions(
    apiKey: 'test',
    appId: 'test',
    messagingSenderId: 'test',
    projectId: 'test',
  );
}

class _MockAuthPlatform extends FirebaseAuthPlatform {
  _MockAuthPlatform({super.appInstance});

  final StreamController<UserPlatform?> _controller =
      StreamController<UserPlatform?>.broadcast();

  @override
  Stream<UserPlatform?> authStateChanges() => _controller.stream;

  @override
  UserPlatform? get currentUser => null;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) =>
      _MockAuthPlatform(appInstance: app);
}

void main() {
  setUpAll(() async {
    FirebasePlatform.instance = _MockFirebasePlatform();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _MockAuthPlatform();
  });

  testWidgets(
    'back from a shell tab (history) returns to home instead of exiting',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: PrescriptionScannerApp()),
      );
      // Wait past the branded launch splash and the login screen entrance.
      await tester.pump(const Duration(milliseconds: 2600));

      // Enter as guest → home.
      await tester.tap(find.text('Try a free scan without signing in'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Ready to scan?'), findsOneWidget);

      // Go to History tab.
      await tester.tap(find.text('History'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Ready to scan?'), findsNothing);

      // Press the system back button.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 800));

      // Must be back on home — NOT exited.
      expect(find.text('Ready to scan?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
