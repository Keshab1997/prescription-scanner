import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// What the Play Store in-app update flow should do.
enum PlayUpdateAction {
  none,
  immediate,
  flexible,
}

/// Pure decision used by tests. Immediate is preferred so the user cannot
/// keep using a stale build once Play has a newer production version.
PlayUpdateAction decidePlayUpdate({
  required bool updateAvailable,
  required bool immediateAllowed,
  required bool flexibleAllowed,
}) {
  if (!updateAvailable) return PlayUpdateAction.none;
  if (immediateAllowed) return PlayUpdateAction.immediate;
  if (flexibleAllowed) return PlayUpdateAction.flexible;
  // Play reported an update but neither type is flagged — still block and
  // retry immediate so sideloaded/internal-track quirks do not skip a release.
  return PlayUpdateAction.immediate;
}

/// Android Play Core in-app updates. No-ops on iOS, web, and when the app
/// was not installed from Play (debug / sideload).
class PlayInAppUpdate {
  const PlayInAppUpdate();

  Future<PlayUpdateAction> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return PlayUpdateAction.none;
    }
    // dart:io Platform is unavailable on web; guarded above.
    if (!Platform.isAndroid) return PlayUpdateAction.none;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return decidePlayUpdate(
        updateAvailable:
            info.updateAvailability == UpdateAvailability.updateAvailable,
        immediateAllowed: info.immediateUpdateAllowed,
        flexibleAllowed: info.flexibleUpdateAllowed,
      );
    } catch (e, st) {
      debugPrint('[play-update] check skipped: $e\n$st');
      return PlayUpdateAction.none;
    }
  }

  /// Starts the Play update UI. Immediate is full-screen and restarts the app
  /// after install. Flexible downloads then applies on complete.
  Future<void> apply(PlayUpdateAction action) async {
    if (action == PlayUpdateAction.none) return;
    try {
      if (action == PlayUpdateAction.flexible) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }
      await InAppUpdate.performImmediateUpdate();
    } catch (e, st) {
      debugPrint('[play-update] apply failed: $e\n$st');
      rethrow;
    }
  }
}
