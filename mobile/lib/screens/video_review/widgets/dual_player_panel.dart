import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../data/road_distress_api.dart';
import '../../../data/video_api.dart';
import '../../../theme/app_colors.dart';
import '../video_review_helpers.dart';

/// Direct port of VideoReview.tsx's synchronized dual-player workspace:
/// the original/annotated `<video>` pair, the seek timeline with per-
/// detection markers, the synchronized transport controls, and the
/// playback-stats telemetry strip.
///
/// Trimmed: "Capture Snapshot" (canvas-to-PNG frame capture) and Picture-
/// in-Picture toggle. Both are real source features, but `package:
/// video_player` doesn't expose the underlying `<video>` DOM element or a
/// cross-platform canvas/PiP API on web -- reaching them would mean
/// dropping to raw `dart:js_interop` hacks disproportionate to what are,
/// in the end, peripheral convenience buttons (not the screen's core
/// review functionality), so they were left out rather than half-built.
class DualPlayerPanel extends StatelessWidget {
  const DualPlayerPanel({
    super.key,
    required this.selectedVideo,
    required this.originalController,
    required this.annotatedController,
    required this.hasAnnotatedVideo,
    required this.isPlaying,
    required this.currentTime,
    required this.duration,
    required this.playbackSpeed,
    required this.volume,
    required this.isMuted,
    required this.syncWarning,
    required this.detections,
    required this.selectedDetection,
    required this.isFullscreen,
    required this.onPlayPause,
    required this.onStop,
    required this.onReplay,
    required this.onSeek,
    required this.onSpeedChange,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onFocusDetection,
    required this.onToggleFullscreen,
  });

  final UploadedVideo? selectedVideo;
  final VideoPlayerController? originalController;
  final VideoPlayerController? annotatedController;
  final bool hasAnnotatedVideo;
  final bool isPlaying;
  final Duration currentTime;
  final Duration duration;
  final double playbackSpeed;
  final double volume;
  final bool isMuted;
  final String? syncWarning;
  final List<DistressRecord> detections;
  final DistressRecord? selectedDetection;
  final bool isFullscreen;

  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onReplay;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onSpeedChange;
  final ValueChanged<double> onVolumeChange;
  final VoidCallback onToggleMute;
  final ValueChanged<DistressRecord> onFocusDetection;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            final original = _playerCard('Original Surveillance Feed', originalController, selectedVideo != null, false);
            final annotated = _playerCard('AI Annotated Feed', annotatedController, hasAnnotatedVideo, true);
            if (narrow) {
              return Column(children: [original, const SizedBox(height: 12), annotated]);
            }
            return Row(
              children: [
                Expanded(child: original),
                const SizedBox(width: 12),
                Expanded(child: annotated),
              ],
            );
          },
        ),
        if (duration > Duration.zero) ...[
          const SizedBox(height: 14),
          _timeline(context),
        ],
        const SizedBox(height: 14),
        _controlsBar(),
        const SizedBox(height: 14),
        _statsPanel(),
      ],
    );
  }

  Widget _playerCard(String label, VideoPlayerController? controller, bool shouldHaveContent, bool isAnnotated) {
    return Container(
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            GestureDetector(
              onTap: onPlayPause,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else if (selectedVideo == null)
            _placeholder(LucideIcons.alertCircle, 'No footage selected.')
          else if (isAnnotated && !shouldHaveContent)
            _placeholder(LucideIcons.tv, 'Annotated Video Unresolved',
                subtitle: 'Processing not complete or annotated MP4 not yet generated.', color: AppColors.warning)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(6)),
              child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(IconData icon, String title, {String? subtitle, Color color = Colors.white70}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white54), textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeline(BuildContext context) {
    final totalMs = duration.inMilliseconds.toDouble();
    return SizedBox(
      height: 34,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The Slider's thumb/track inset a few pixels of padding on each
          // side; approximate that so the marker dots line up with the
          // scrubber position they represent instead of the raw fraction
          // of the full widget width.
          const inset = 10.0;
          final trackWidth = (constraints.maxWidth - inset * 2).clamp(0.0, double.infinity);

          return Stack(
            alignment: Alignment.center,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  min: 0,
                  max: totalMs,
                  value: currentTime.inMilliseconds.toDouble().clamp(0, totalMs),
                  activeColor: AppColors.accentBlue,
                  onChanged: (v) => onSeek(Duration(milliseconds: v.round())),
                ),
              ),
              // Not wrapped in IgnorePointer, unlike a typical marker
              // overlay: each dot below is individually tappable (to seek
              // + focus that detection) while the gaps between them still
              // fall through to the Slider underneath, since a Stack only
              // intercepts hits within each Positioned child's own bounds.
              SizedBox(
                width: constraints.maxWidth,
                height: 34,
                child: Stack(
                  children: [
                    for (final det in detections)
                      Builder(builder: (context) {
                        final t = (det.videoTimestamp ?? 0) * 1000;
                        final percent = totalMs > 0 ? (t / totalMs).clamp(0.0, 1.0) : 0.0;
                        final isSelected = selectedDetection?.id == det.id;
                        final color = severityColor(det.severity);
                        return Positioned(
                          left: inset + trackWidth * percent - 6,
                          top: 11,
                          child: Tooltip(
                            message:
                                '${formatDistressType(det.distressType)}\nTracking: #${det.trackingId ?? det.id}\nSeverity: ${det.severity.toUpperCase()}\nTime: ${formatTime(Duration(milliseconds: t.round()))}',
                            child: GestureDetector(
                              onTap: () => onFocusDetection(det),
                              child: Container(
                                width: 12,
                                height: 12,
                                alignment: Alignment.center,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: isSelected ? 2 : 1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _controlsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.primaryBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(10)),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(onPressed: onPlayPause, icon: Icon(isPlaying ? LucideIcons.pause : LucideIcons.play, size: 16), tooltip: isPlaying ? 'Pause' : 'Play'),
              IconButton(onPressed: onStop, icon: const Icon(LucideIcons.square, size: 14), tooltip: 'Stop'),
              IconButton(onPressed: onReplay, icon: const Icon(LucideIcons.rotateCcw, size: 15), tooltip: 'Replay'),
              const SizedBox(width: 6),
              Text('${formatTime(currentTime)} / ${formatTime(duration)}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('SPEED:', style: TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'monospace')),
              const SizedBox(width: 6),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    value: playbackSpeed,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 0.5, child: Text('0.5x', style: TextStyle(fontSize: 11, color: AppColors.primaryText))),
                      DropdownMenuItem(value: 1.0, child: Text('1.0x', style: TextStyle(fontSize: 11, color: AppColors.primaryText))),
                      DropdownMenuItem(value: 1.5, child: Text('1.5x', style: TextStyle(fontSize: 11, color: AppColors.primaryText))),
                      DropdownMenuItem(value: 2.0, child: Text('2.0x', style: TextStyle(fontSize: 11, color: AppColors.primaryText))),
                    ],
                    onChanged: (v) => onSpeedChange(v ?? playbackSpeed),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onToggleMute,
                icon: Icon(isMuted ? LucideIcons.volumeX : LucideIcons.volume2, size: 15),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
              SizedBox(
                width: 90,
                child: Slider(
                  min: 0,
                  max: 1,
                  value: volume,
                  activeColor: AppColors.accentBlue,
                  onChanged: onVolumeChange,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onToggleFullscreen,
                icon: Icon(isFullscreen ? LucideIcons.minimize2 : LucideIcons.maximize2, size: 15),
                tooltip: 'Fullscreen mode',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsPanel() {
    const fps = 30.0;
    final currentFrame = (currentTime.inMilliseconds / 1000 * fps).floor();
    final totalFrame = (duration.inMilliseconds / 1000 * fps).floor();
    final status = selectedVideo?.processingStatus ?? 'idle';
    final statusColor = status == 'completed' ? AppColors.success : AppColors.warning;

    final stats = [
      ('Status', status.toUpperCase(), statusColor),
      ('Resolution', '1920x1080 (1080p)', AppColors.primaryText),
      ('FPS', '30.0 fps', AppColors.primaryText),
      ('Frame', '$currentFrame / $totalFrame', AppColors.primaryText),
      ('Total Detections', '${detections.length}', AppColors.primaryText),
      ('Target speed', '${playbackSpeed}x', AppColors.primaryText),
    ];

    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: [
        for (final s in stats)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${s.$1}: ', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'monospace')),
              Text(s.$2, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: s.$3, fontFamily: 'monospace')),
            ],
          ),
        if (syncWarning != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertTriangle, size: 12, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(syncWarning!, style: const TextStyle(fontSize: 10, color: AppColors.warning)),
            ],
          ),
      ],
    );
  }
}
