import 'dart:async';
import 'dart:io';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show Text;
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
      await tester.pumpWidget(
        const ProviderScope(child: PrescriptionScannerApp()),
      );
      // Wait past the branded launch splash and the login screen entrance.
      await tester.pump(const Duration(milliseconds: 2600));

      // Enter as guest → home. The button sits below the fold on small
      // screens, so scroll it into view first.
      final guestButton = find.text('Try a free scan without signing in');
      await tester.ensureVisible(guestButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(guestButton);
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text('Ready to scan?'), findsOneWidget);

      // Go to the History tab.
      await tester.tap(find.text('History'));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Ready to scan?'), findsNothing);

      // Press the system back button — must return home, not exit.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 900));

      // Debug: include what is actually on screen in the failure message.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((d) => d.isNotEmpty)
          .take(14)
          .toList();

      expect(
        find.text('Ready to scan?'),
        findsOneWidget,
        reason: 'After back press, visible texts: $texts',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
