import 'dart:typed_data';

Future<Uint8List> readRecordedAudioBytes(String path) async {
  throw UnsupportedError('Audio recording is not available on this platform.');
}

/// Where a recording called [name] should be written (see the web and io versions).
String newRecordingPath(String name) => name;
