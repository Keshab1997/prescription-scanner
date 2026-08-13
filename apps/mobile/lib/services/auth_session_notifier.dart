import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authSessionNotifierProvider = Provider<AuthSessionNotifier>((ref) {
  final notifier = AuthSessionNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

class AuthSessionNotifier extends ChangeNotifier {
  AuthSessionNotifier() {
    if (AppConfig.hasSupabaseConfig) {
      _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (state) {
          if (state.event == AuthChangeEvent.passwordRecovery) {
            passwordRecovery = true;
          }
          notifyListeners();
        },
        onError: (Object _, StackTrace _) {
          // Network refresh errors are handled by the next auth retry; do not crash.
          notifyListeners();
        },
      );
    }
  }

  StreamSubscription<AuthState>? _subscription;
  bool passwordRecovery = false;

  void completePasswordRecovery() {
    passwordRecovery = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
