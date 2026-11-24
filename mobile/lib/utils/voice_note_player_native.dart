import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Playing a voice note failed; [message] is safe to show to the person.
class VoicePlaybackException implements Exception {
  const VoicePlaybackException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Plays one voice note at a time (phone version).
class VoiceNotePlayer {
  VoiceNotePlayer({required this.onFinished}) {
    _done = _player.onPlayerComplete.listen((_) => onFinished());
  }

  /// Called when a note has played to the end.
  final void Function() onFinished;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _done;

  Future<void> play(String url) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (_) {
      throw const VoicePlaybackException('Could not play the recording.');
    }
  }

  void stop() {
    _player.stop();
  }

  void dispose() {
    _done?.cancel();
    _player.dispose();
  }
}
