import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:web/web.dart' as web;

import '../../../theme/app_colors.dart';

class WebVideoCard extends StatefulWidget {
  const WebVideoCard({
    super.key,
    required this.label,
    required this.videoUrl,
    required this.isPlaying,
    required this.currentTime,
    required this.playbackSpeed,
    required this.volume,
    required this.isMuted,
    required this.onTap,
    this.onToggleFullscreen,
    this.isFullscreen = false,
  });

  final String label;
  final String videoUrl;
  final bool isPlaying;
  final Duration currentTime;
  final double playbackSpeed;
  final double volume;
  final bool isMuted;
  final VoidCallback onTap;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;

  @override
  State<WebVideoCard> createState() => _WebVideoCardState();
}

class _WebVideoCardState extends State<WebVideoCard> {
  late String _viewId;
  web.HTMLVideoElement? _videoElement;

  @override
  void initState() {
    super.initState();
    _viewId = 'web-video-${widget.videoUrl.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

    if (kIsWeb) {
      final video = web.document.createElement('video') as web.HTMLVideoElement;
      video.src = widget.videoUrl;
      video.controls = false;
      video.autoplay = false;
      video.muted = widget.isMuted;
      video.playbackRate = widget.playbackSpeed;
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
      _videoElement = video;

      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) => video);
    }
  }

  @override
  void didUpdateWidget(WebVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final video = _videoElement;
    if (video == null) return;

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        video.play();
      } else {
        video.pause();
      }
    }

    if ((widget.currentTime - oldWidget.currentTime).abs() > const Duration(milliseconds: 300)) {
      video.currentTime = widget.currentTime.inMilliseconds / 1000.0;
    }

    if (widget.playbackSpeed != oldWidget.playbackSpeed) {
      video.playbackRate = widget.playbackSpeed;
    }

    if (widget.volume != oldWidget.volume || widget.isMuted != oldWidget.isMuted) {
      video.volume = widget.isMuted ? 0.0 : widget.volume;
      video.muted = widget.isMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.isFullscreen ? 460 : 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isFullscreen ? AppColors.accentBlue : AppColors.cardBorder,
          width: widget.isFullscreen ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header Bar with Label & Independent Fullscreen Toggle Button
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF1F2937),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.onToggleFullscreen != null)
                  InkWell(
                    onTap: widget.onToggleFullscreen,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isFullscreen ? LucideIcons.minimize2 : LucideIcons.maximize2,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.isFullscreen ? 'Exit' : 'Fullscreen',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Video viewport frame
          Expanded(
            child: kIsWeb
                ? GestureDetector(
                    onTap: widget.onTap,
                    child: HtmlElementView(viewType: _viewId),
                  )
                : const Center(child: Icon(LucideIcons.video, size: 32, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
