import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/config.dart';
import 'package:prescription_scanner/screens.dart';
import 'package:prescription_scanner/services/auth_session_notifier.dart';
import 'package:prescription_scanner/widgets/app_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authSessionNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final path = state.uri.path;
      final isAuthRoute = path == '/login' ||
          path == '/register' ||
          path == '/forgot-password' ||
          path == '/reset-password';

      if (!AppConfig.hasSupabaseConfig) {
        return isAuthRoute ? null : '/login';
      }

      if (authNotifier.passwordRecovery && path != '/reset-password') {
        return '/reset-password';
      }

      final session = Supabase.instance.client.auth.currentSession;
      final signedIn = session != null && !session.isExpired;
      if (!signedIn && !isAuthRoute) return '/login';
      if (signedIn &&
          (path == '/login' || path == '/register' || path == '/forgot-password')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      ShellRoute(
        builder: (_, state, child) => AppShell(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/upload', builder: (_, __) => const UploadScreen()),
      GoRoute(
        path: '/processing',
        builder: (_, state) => ProcessingScreen(
          prescriptionId: state.uri.queryParameters['prescriptionId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/result',
        builder: (_, state) => ResultScreen(
          prescriptionId: state.uri.queryParameters['prescriptionId'] ?? '',
        ),
      ),
    ],
  );
});
