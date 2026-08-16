import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/screens.dart';
import 'package:prescription_scanner/services/auth_session_notifier.dart';
import 'package:prescription_scanner/widgets/app_back_scope.dart';
import 'package:prescription_scanner/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authSessionNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final path = state.uri.path;
      final isAuthRoute =
          path == '/login' ||
          path == '/register' ||
          path == '/forgot-password' ||
          path == '/reset-password';

      if (authNotifier.passwordRecovery && path != '/reset-password') {
        return '/reset-password';
      }

      final user = fb.FirebaseAuth.instance.currentUser;
      final signedIn = user != null;
      if (!signedIn && !isAuthRoute) return '/login';
      if (signedIn &&
          (path == '/login' ||
              path == '/register' ||
              path == '/forgot-password')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const AppBackScope(
          fallbackLocation: '/login',
          child: RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const AppBackScope(
          fallbackLocation: '/login',
          child: ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const AppBackScope(
          fallbackLocation: '/login',
          child: ResetPasswordScreen(),
        ),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(currentPath: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/upload',
        builder: (_, _) => const AppBackScope(
          fallbackLocation: '/home',
          child: UploadScreen(),
        ),
      ),
      GoRoute(
        path: '/processing',
        builder: (_, state) => AppBackScope(
          fallbackLocation: '/home',
          child: ProcessingScreen(
            prescriptionId: state.uri.queryParameters['prescriptionId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/result',
        builder: (_, state) => AppBackScope(
          fallbackLocation: '/home',
          child: ResultScreen(
            prescriptionId: state.uri.queryParameters['prescriptionId'] ?? '',
          ),
        ),
      ),
    ],
  );
});
