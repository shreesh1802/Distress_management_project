import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen from turning off (and the camera from stopping with it) while [on] is true.
/// Best effort: where the platform or browser has no wake lock this quietly does nothing.
Future<void> keepScreenAwake(bool on) async {
  try {
    if (on) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  } catch (_) {
    // Not supported here; the screen just follows the phone's normal sleep timer.
  }
}
