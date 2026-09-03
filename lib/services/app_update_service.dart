import 'dart:io';

import 'package:in_app_update/in_app_update.dart';

/// Forces the user to update when a newer version is live on the Play
/// Store, using Google's own Play Core "In-App Updates" API — not a
/// custom version-check server. Play Store already knows the installed
/// versionCode vs. the published one, so this needs no backend of ours;
/// it just has to be called, and the *next release's* pubspec.yaml
/// versionCode has to be higher than the one currently on Play Store.
///
/// Android only — Play Core has no iOS equivalent. On iOS this is a
/// no-op; if you need forced updates there too, that requires a
/// different approach (an App Store version check plus a manual
/// redirect), which isn't implemented here.
class AppUpdateService {
  AppUpdateService._();

  /// Call once, early in the app's life (e.g. in the home screen's
  /// initState). If an immediate update is available, this shows Play
  /// Store's native full-screen update UI, which the user cannot dismiss
  /// or work around — the app is unusable until they update.
  static Future<void> checkAndForceUpdateIfNeeded() async {
    if (!Platform.isAndroid) return;

    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // Fails silently: no Play Store on this install (sideloaded APK,
      // emulator without Play services, F-Droid-style builds, no
      // internet, etc). An update-check failure should never block the
      // app from being usable.
    }
  }
}
