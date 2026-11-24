import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Playing a voice note failed; [message] is safe to show to the person.
class VoicePlaybackException implements Exception {
  const VoicePlaybackException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Plays one voice note at a time (browser version).
///
/// A plain `<audio>` element that is created and started in the same moment as the tap. Safari only
/// lets sound start straight from a tap -- not after waiting on other work -- and the general audio
/// library creates its player late and routes it through the browser's audio engine, which Safari then
/// refuses. So [play] does nothing asynchronous before it starts the element.
class VoiceNotePlayer {
  VoiceNotePlayer({required this.onFinished});

  /// Called when a note has played to the end.
  final void Function() onFinished;
  web.HTMLAudioElement? _element;

  Future<void> play(String url) async {
    _release();
    final element = web.HTMLAudioElement()
      ..preload = 'auto'
      ..src = url;
    _element = element;
    element.onended = ((web.Event _) {
      if (identical(_element, element)) onFinished();
    }).toJS;
    try {
      await element.play().toDart;
    } catch (error) {
      final code = element.error?.code;
      _release();
      throw VoicePlaybackException(_explain(code, error));
    }
  }

  void stop() => _release();

  void dispose() => _release();

  void _release() {
    final element = _element;
    _element = null;
    if (element == null) return;
    try {
      element.pause();
      element.removeAttribute('src');
      element.load();
    } catch (_) {}
  }

  static String _explain(int? code, Object error) {
    // MediaError codes: 2 = network, 3 = decode, 4 = source not supported.
    if (code == 4 || code == 3) {
      return 'This browser cannot play that recording (format not supported). '
          'It is still saved, and it is in the report.';
    }
    if (code == 2) return 'Could not load the recording. Check your connection.';
    final text = error.toString();
    if (text.contains('NotAllowed')) {
      return 'The browser blocked the sound. Tap the play button again.';
    }
    return 'Could not play the recording.';
  }
}
