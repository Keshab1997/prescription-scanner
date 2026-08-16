import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/widgets/app_back_scope.dart';

void main() {
  GoRouter buildRouter(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home page')),
      ),
      GoRoute(
        path: '/details',
        builder: (_, _) => const AppBackScope(
          fallbackLocation: '/home',
          child: Scaffold(body: Text('Details page')),
        ),
      ),
    ],
  );

  testWidgets('root detail page goes home instead of exiting', (tester) async {
    final router = buildRouter('/details');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('Details page'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('pushed detail page returns to its previous page', (
    tester,
  ) async {
    final router = buildRouter('/home');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    router.push('/details');
    await tester.pumpAndSettle();
    expect(find.text('Details page'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Home page'), findsOneWidget);
  });
}
