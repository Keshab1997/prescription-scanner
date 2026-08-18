import 'dart:async';
import 'dart:io';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prescription_scanner/app.dart';
import 'package:prescription_scanner/services/app_prefs.dart';

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
  });

  // Hive does real file I/O, which must not run inside a testWidgets fake
  // async zone (file/timer-based futures would never complete there). So the
  // prefs box is opened and closed here, in the real async zone.
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ks-onboarding-test');
    Hive.init(tempDir.path);
    await AppPrefs.init();
  });

  tearDown(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Best-effort cleanup only.
    }
  });

  testWidgets(
    'first launch gates the login screen behind the illustrated onboarding',
    (tester) async {
      // Default 800x600 lets the last CTA sit under/off the Next hit target.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> tapCta(Key key) async {
        final finder = find.byKey(key);
        expect(finder, findsOneWidget);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }

      await tester.pumpWidget(
        const ProviderScope(child: PrescriptionScannerApp()),
      );
      // Onboarding illustrations float forever, so pump past the branded
      // launch transition with a fixed duration instead of pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 2400));

      // Step 1 of the illustrated walkthrough is showing, not the login form.
      expect(find.text('Scan any prescription'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);

      await tapCta(const ValueKey('onboarding-next'));
      expect(find.text('AI reads it for you'), findsOneWidget);

      await tapCta(const ValueKey('onboarding-next'));
      expect(find.text('Your medicines, remembered'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);

      await tapCta(const ValueKey('onboarding-get-started'));

      // Completing onboarding remembers the choice and opens the login form.
      // (The Hive box cache is updated synchronously on put.)
      expect(AppPrefs.hasSeenOnboarding, isTrue);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in securely'), findsOneWidget);

      // A relaunch skips the walkthrough entirely.
      await tester.pumpWidget(
        const ProviderScope(child: PrescriptionScannerApp()),
      );
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.text('Scan any prescription'), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );
}
