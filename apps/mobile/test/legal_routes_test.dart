import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/screens/legal_screens.dart';
import 'package:prescription_scanner/widgets/app_back_scope.dart';

void main() {
  GoRouter buildRouter(String initial) => GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Welcome back')),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, _) => const AppBackScope(
          fallbackLocation: '/login',
          child: PrivacyPolicyScreen(),
        ),
      ),
      GoRoute(
        path: '/terms',
        builder: (_, _) => const AppBackScope(
          fallbackLocation: '/login',
          child: TermsScreen(),
        ),
      ),
      GoRoute(
        path: '/disclaimer',
        builder: (_, _) => const AppBackScope(
          fallbackLocation: '/login',
          child: MedicalDisclaimerScreen(),
        ),
      ),
    ],
  );

  testWidgets('privacy terms and disclaimer routes render', (tester) async {
    final router = buildRouter('/login');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    router.push('/privacy');
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsWidgets);

    router.go('/terms');
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use'), findsWidgets);

    router.go('/disclaimer');
    await tester.pumpAndSettle();
    expect(find.text('Medical disclaimer'), findsWidgets);
  });
}