import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// While true, [DashboardShell] shows only the screen's own content: no side bar, app bar or
/// bottom navigation, and no padding or scrolling around it. Screens switch it on with
/// [enterLandscapeFullscreen] and off with [exitLandscapeFullscreen].
final ValueNotifier<bool> gHideDashboardChrome = ValueNotifier<bool>(false);

const MethodChannel _display = MethodChannel('road_inspection/display');
Timer? _rotationWatch;
bool? _followingPhone;

/// The phone's "Auto rotate" setting: true / false on Android, null where it cannot be read.
Future<bool?> _autoRotateOn() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    return await _display.invokeMethod<bool>('autoRotate');
  } catch (_) {
    return null;
  }
}

/// Landscape while auto-rotate is off (or unknown); with auto-rotate on, follow how the phone is held.
Future<void> _applyOrientation() async {
  final follow = (await _autoRotateOn()) ?? false;
  if (follow == _followingPhone) return;
  _followingPhone = follow;
  try {
    await SystemChrome.setPreferredOrientations(
      follow
          ? const [DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    );
  } catch (_) {
    // Unsupported on this platform.
  }
}

/// Full-screen viewing: hides the dashboard chrome and the system bars (status bar / navigation bar).
/// The picture opens in landscape; when the phone's auto-rotate is on it turns with the phone instead
/// (checked every couple of seconds, so switching auto-rotate on or off takes effect straight away).
/// Does nothing harmful where those are not supported (for example in a browser, where the person
/// simply rotates the phone themselves).
Future<void> enterLandscapeFullscreen() async {
  gHideDashboardChrome.value = true;
  _followingPhone = null;
  await _applyOrientation();
  _rotationWatch?.cancel();
  _rotationWatch = Timer.periodic(const Duration(seconds: 2), (_) => _applyOrientation());
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (_) {
    // Unsupported on this platform: the in-app full-screen layout still works.
  }
}

/// Undoes [enterLandscapeFullscreen]: shows the dashboard chrome and the system bars again and
/// lets the phone rotate freely, as it did before.
Future<void> exitLandscapeFullscreen() async {
  gHideDashboardChrome.value = false;
  _rotationWatch?.cancel();
  _rotationWatch = null;
  _followingPhone = null;
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
