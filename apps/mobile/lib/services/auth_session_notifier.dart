import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authSessionNotifierProvider = Provider<AuthSessionNotifier>((ref) {
  final notifier = AuthSessionNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Bridges Firebase Auth state changes into a ChangeNotifier so go_router can
/// react to sign-in / sign-out without polling. Password-recovery completion
/// is driven by the reset-password screen calling [completePasswordRecovery].
class AuthSessionNotifier extends ChangeNotifier {
  AuthSessionNotifier() {
    _subscription = fb.FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  fb.User? get currentUser => fb.FirebaseAuth.instance.currentUser;

  StreamSubscription<fb.User?>? _subscription;
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
