import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/widgets/app_back_scope.dart';
import 'package:prescription_scanner/widgets/app_shell.dart';

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
    expect(tester.takeException(), isNull);
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell back navigation is intercepted and lifecycle-safe', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/history',
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              AppShell(currentPath: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Center(child: Text('Shell home')),
            ),
            GoRoute(
              path: '/history',
              builder: (_, _) => const Center(child: Text('Shell history')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('Shell history'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Shell home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home back shows and dismisses exit confirmation safely', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              AppShell(currentPath: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Center(child: Text('Shell home')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    final backHandled = tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Exit app?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    await backHandled;
    expect(find.text('Shell home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom nav tab tap navigates within the shell', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              AppShell(currentPath: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Center(child: Text('HOME PAGE')),
            ),
            GoRoute(
              path: '/history',
              builder: (_, _) => const Center(child: Text('HISTORY PAGE')),
            ),
            GoRoute(
              path: '/help',
              builder: (_, _) => const Center(child: Text('HELP PAGE')),
            ),
            GoRoute(
              path: '/profile',
              builder: (_, _) => const Center(child: Text('PROFILE PAGE')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('HOME PAGE'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('HISTORY PAGE'), findsOneWidget);

    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(find.text('HELP PAGE'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE PAGE'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('HOME PAGE'), findsOneWidget);
  });

  testWidgets('shell route onExit guards must not block tab navigation', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              AppShell(currentPath: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/home',
              onExit: (_, _) => false,
              builder: (_, _) => const Center(child: Text('HOME PAGE')),
            ),
            GoRoute(
              path: '/history',
              onExit: (_, _) => false,
              builder: (_, _) => const Center(child: Text('HISTORY PAGE')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('HOME PAGE'), findsOneWidget);
    expect(find.text('HISTORY PAGE'), findsNothing);
  });
}
