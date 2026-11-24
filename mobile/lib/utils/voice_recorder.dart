import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

import 'audio_bytes_reader.dart';

/// A finished voice recording, ready to upload.
class RecordedClip {
  const RecordedClip({required this.bytes, required this.filename, required this.seconds});

  final Uint8List bytes;
  final String filename;
  final double seconds;
}

/// Records a short voice note from the microphone, on a phone or in a browser.
///
/// Everything records AAC (`.m4a`) where it can: Safari / iPhone play that format and Chrome does too.
/// Opus (`.webm`) is only a fallback for a browser that cannot record AAC -- Safari often cannot play
/// WebM, so a note recorded that way would be unplayable on an iPhone. The server accepts both.
class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;
  String _extension = 'm4a';

  /// Starts recording. Returns false when the microphone is not allowed.
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    var encoder = AudioEncoder.aacLc;
    _extension = 'm4a';
    if (kIsWeb &&
        !await _recorder.isEncoderSupported(AudioEncoder.aacLc) &&
        await _recorder.isEncoderSupported(AudioEncoder.opus)) {
      encoder = AudioEncoder.opus;
      _extension = 'webm';
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await _recorder.start(
      RecordConfig(encoder: encoder),
      path: newRecordingPath('voice_note_$stamp.$_extension'),
    );
    _startedAt = DateTime.now();
    return true;
  }

  /// Stops and returns the recording, or null if nothing was recorded.
  Future<RecordedClip?> stop() async {
    final path = await _recorder.stop();
    final started = _startedAt;
    _startedAt = null;
    if (path == null) return null;
    final bytes = await readRecordedAudioBytes(path);
    if (bytes.isEmpty) return null;
    final seconds = started == null ? 0.0 : DateTime.now().difference(started).inMilliseconds / 1000.0;
    return RecordedClip(
      bytes: bytes,
      filename: 'voice_note_${DateTime.now().millisecondsSinceEpoch}.$_extension',
      seconds: seconds,
    );
  }

  /// Throws the current recording away.
  Future<void> cancel() async {
    _startedAt = null;
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  Future<void> dispose() => _recorder.dispose();
}
