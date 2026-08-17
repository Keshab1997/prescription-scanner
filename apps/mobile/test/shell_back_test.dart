import 'dart:async';
import 'dart:io';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart' show Size, Text, TextButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prescription_scanner/app.dart';
import 'package:prescription_scanner/services/result_store.dart';

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
  late Directory tempDir;

  setUpAll(() async {
    FirebasePlatform.instance = _MockFirebasePlatform();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _MockAuthPlatform();

    tempDir = await Directory.systemTemp.createTemp('hive_shell_back_test');
    Hive.init(tempDir.path);
    await ResultStore.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets(
    'back from a shell tab (history) returns to home instead of exiting',
    (tester) async {
      // Tall viewport so the whole login screen (including the guest button)
      // is on screen without scrolling.
      tester.view.physicalSize = const Size(412 * 3, 1000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: PrescriptionScannerApp()),
      );
      // Wait past the branded launch splash and the login screen entrance.
      await tester.pump(const Duration(milliseconds: 2600));

      // Enter as guest → home.
      await tester.tap(find.text('Try a free scan without signing in'));
      await _settle(tester);
      expect(find.text('Ready to scan?'), findsOneWidget);

      // Go to the History tab.
      await tester.tap(find.text('History'));
      await _settle(tester);
      expect(find.text('Ready to scan?'), findsNothing);

      // Press the system back button — must return home, not exit.
      await tester.binding.handlePopRoute();
      await _settle(tester);

      expect(find.text('Ready to scan?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

/// Pumps several frames so go_router's asynchronous navigation completes
/// (the home screen has looping animations, so pumpAndSettle would never
/// settle).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 600));
}
