import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  return GestureDetector(
    onTap: onTap,
    child: Container(
      color: const Color(0xFF111827),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPlaying ? LucideIcons.pause : LucideIcons.play,
              size: 44,
              color: Colors.white70,
            ),
            const SizedBox(height: 8),
            Text(
              'Video Stream (${currentTime.inSeconds}s)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
