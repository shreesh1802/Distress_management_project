import 'dart:io';
import 'dart:typed_data';

/// On a phone `record` writes the recording to a file and `stop()` returns its path.
Future<Uint8List> readRecordedAudioBytes(String path) async {
  final file = File(path);
  try {
    return await file.readAsBytes();
  } finally {
    // The bytes are uploaded from memory; do not leave the recording lying around on the phone.
    try {
      await file.delete();
    } catch (_) {}
  }
}

/// A recording must be written to a real folder on a phone: the app's temporary one.
String newRecordingPath(String name) => '${Directory.systemTemp.path}${Platform.pathSeparator}$name';
