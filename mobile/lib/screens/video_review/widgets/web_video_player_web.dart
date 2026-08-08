import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Map<String, web.HTMLVideoElement> _videoElements = {};

Widget buildWebVideoPlayer({
  required String viewId,
  required String videoUrl,
  required bool isPlaying,
  required Duration currentTime,
  required double playbackSpeed,
  required double volume,
  required bool isMuted,
  required VoidCallback onTap,
}) {
  if (!_videoElements.containsKey(viewId)) {
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

    _videoElements[viewId] = video;
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) => video);
  }

  final video = _videoElements[viewId];
  if (video != null) {
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
  }

  return GestureDetector(
    onTap: onTap,
    child: HtmlElementView(viewType: viewId),
  );
}
