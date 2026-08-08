import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';
import 'web_video_player_helper.dart';

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
    this.onPositionUpdate,
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
  final ValueChanged<Duration>? onPositionUpdate;

  @override
  State<WebVideoCard> createState() => _WebVideoCardState();
}

class _WebVideoCardState extends State<WebVideoCard> {
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'web-video-${widget.videoUrl.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
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
          // Video Viewport (Web HTML5 Player on Web, Native Video Fallback on Mobile)
          Expanded(
            child: buildWebVideoPlayer(
              viewId: _viewId,
              videoUrl: widget.videoUrl,
              isPlaying: widget.isPlaying,
              currentTime: widget.currentTime,
              playbackSpeed: widget.playbackSpeed,
              volume: widget.volume,
              isMuted: widget.isMuted,
              onTap: widget.onTap,
              onPositionUpdate: widget.onPositionUpdate,
            ),
          ),
        ],
      ),
    );
  }
}
