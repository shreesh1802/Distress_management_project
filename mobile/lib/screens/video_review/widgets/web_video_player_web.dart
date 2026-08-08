import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class _ManagedVideo {
  _ManagedVideo(this.element);
  final web.HTMLVideoElement element;
  ValueChanged<Duration>? onPositionUpdate;
}

final Map<String, _ManagedVideo> _videoElements = {};

Widget buildWebVideoPlayer({
  required String viewId,
  required String videoUrl,
  required bool isPlaying,
  required Duration currentTime,
  required double playbackSpeed,
  required double volume,
  required bool isMuted,
  required VoidCallback onTap,
  ValueChanged<Duration>? onPositionUpdate,
}) {
  var managed = _videoElements[viewId];
  if (managed == null) {
    final video = web.document.createElement('video') as web.HTMLVideoElement;
    video.src = videoUrl;
    video.controls = false;
    video.autoplay = false;
    video.muted = isMuted;
    video.playbackRate = playbackSpeed;
    video.preload = 'auto';
    video.playsInline = true;
    video.setAttribute('playsinline', 'true');
    video.setAttribute('webkit-playsinline', 'true');
    video.setAttribute('preload', 'auto');
    video.style.width = '100%';
    video.style.height = '100%';
    video.style.objectFit = 'contain';
    video.style.backgroundColor = '#111827';
    video.load();
    video.currentTime = 0.05;

    managed = _ManagedVideo(video);
    _videoElements[viewId] = managed;

    // Reports this element's real playback position so sibling players are
    // driven from an element that is actually on screen, instead of a
    // separate proxy video whose independent buffering drifts from what's
    // displayed and causes corrective seeks that fight real playback.
    video.addEventListener(
      'timeupdate',
      (web.Event _) {
        _videoElements[viewId]?.onPositionUpdate?.call(
              Duration(milliseconds: (video.currentTime * 1000).round()),
            );
      }.toJS,
    );

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) => video);
  }
  managed.onPositionUpdate = onPositionUpdate;

  final video = managed.element;
  if (isPlaying) {
    video.play();
  } else {
    video.pause();
  }
  if ((video.currentTime - (currentTime.inMilliseconds / 1000.0)).abs() > 0.3) {
    video.currentTime = currentTime.inMilliseconds / 1000.0;
  }
  video.playbackRate = playbackSpeed;
  video.volume = isMuted ? 0.0 : volume;
  video.muted = isMuted;

  return GestureDetector(
    onTap: onTap,
    child: HtmlElementView(viewType: viewId),
  );
}
