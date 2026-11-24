import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// While true, [DashboardShell] shows only the screen's own content: no side bar, app bar or
/// bottom navigation, and no padding or scrolling around it. Screens switch it on with
/// [enterLandscapeFullscreen] and off with [exitLandscapeFullscreen].
final ValueNotifier<bool> gHideDashboardChrome = ValueNotifier<bool>(false);

/// Full-screen viewing: hides the dashboard chrome, locks the phone to landscape and hides the
/// system bars (status bar / navigation bar). Does nothing harmful where those are not supported
/// (for example in a desktop or mobile browser, which ignore the orientation lock -- there the
/// person simply rotates the phone themselves).
Future<void> enterLandscapeFullscreen() async {
  gHideDashboardChrome.value = true;
  try {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (_) {
    // Unsupported on this platform: the in-app full-screen layout still works.
  }
}

/// Undoes [enterLandscapeFullscreen]: shows the dashboard chrome and the system bars again and
/// lets the phone rotate freely, as it did before.
Future<void> exitLandscapeFullscreen() async {
  gHideDashboardChrome.value = false;
  try {
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  } catch (_) {
    // Unsupported on this platform.
  }
}
