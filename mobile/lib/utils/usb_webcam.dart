import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A USB webcam plugged into the phone (through an OTG adapter), read directly over USB.
///
/// Android's normal camera system does not list most USB webcams, so the usual `camera` plugin cannot see
/// them. The Android side (UsbWebcamBridge.kt) talks to the webcam itself and hands over JPEG pictures.
/// Everywhere other than Android this reports "nothing plugged in".
const String kUsbWebcamCameraName = 'usb-webcam';

class UsbWebcamDevice {
  const UsbWebcamDevice({required this.name});
  final String name;
}

/// What the webcam reports while it is being opened and used.
class UsbWebcamStatus {
  const UsbWebcamStatus({required this.state, required this.message, this.width = 0, this.height = 0});

  /// `connecting`, `running` or `error`.
  final String state;
  final String message;
  final int width;
  final int height;

  bool get isRunning => state == 'running';
  bool get isError => state == 'error';
}

class UsbWebcam {
  UsbWebcam._();

  static const MethodChannel _methods = MethodChannel('road_inspection/usb_webcam');
  static const EventChannel _events = EventChannel('road_inspection/usb_webcam/events');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// USB webcams that are plugged in right now.
  static Future<List<UsbWebcamDevice>> devices() async {
    if (!supported) return const [];
    try {
      final raw = await _methods.invokeMethod<List<dynamic>>('devices') ?? const [];
      return raw
          .whereType<Map>()
          .map((m) => UsbWebcamDevice(name: (m['name'] as String?) ?? 'USB webcam'))
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Opens the webcam. Pictures and status changes arrive through [onFrame] and [onStatus].
  /// Completes with the first `running` or `error` status (a permission dialog may be shown meanwhile).
  static Future<UsbWebcamStatus> start({
    required void Function(Uint8List jpeg) onFrame,
    required void Function(UsbWebcamStatus status) onStatus,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await stop();
    final completer = Completer<UsbWebcamStatus>();
    _subscription = _events.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Uint8List) {
          onFrame(event);
        } else if (event is Map) {
          final status = UsbWebcamStatus(
            state: (event['state'] as String?) ?? 'error',
            message: (event['message'] as String?) ?? '',
            width: (event['width'] as num?)?.toInt() ?? 0,
            height: (event['height'] as num?)?.toInt() ?? 0,
          );
          onStatus(status);
          if ((status.isRunning || status.isError) && !completer.isCompleted) completer.complete(status);
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          completer.complete(UsbWebcamStatus(state: 'error', message: 'The USB webcam stopped: $e'));
        }
      },
    );
    try {
      await _methods.invokeMethod<void>('start');
    } on PlatformException catch (e) {
      await stop();
      return UsbWebcamStatus(state: 'error', message: e.message ?? 'Could not start the USB webcam.');
    } on MissingPluginException {
      await stop();
      return const UsbWebcamStatus(state: 'error', message: 'USB webcams are only supported on Android.');
    }
    final status = await completer.future.timeout(
      timeout,
      onTimeout: () => const UsbWebcamStatus(
        state: 'error',
        message: 'The USB webcam did not start. Check that you allowed USB access, then try again.',
      ),
    );
    if (status.isError) await stop();
    return status;
  }

  static StreamSubscription<dynamic>? _subscription;

  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (!supported) return;
    try {
      await _methods.invokeMethod<void>('stop');
    } catch (_) {
      // Nothing to stop.
    }
  }
}
