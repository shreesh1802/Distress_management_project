import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../data/road_distress_api.dart';
import '../../../data/video_api.dart';
import '../../../theme/app_colors.dart';
import '../video_review_helpers.dart';
import 'web_video_card.dart';

class DualPlayerPanel extends StatefulWidget {
  const DualPlayerPanel({
    super.key,
    required this.selectedVideo,
    required this.originalController,
    required this.annotatedController,
    this.originalUrl,
    this.annotatedUrl,
    required this.originalLoadFailed,
    required this.annotatedLoadFailed,
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
  final String? originalUrl;
  final String? annotatedUrl;
  final bool originalLoadFailed;
  final bool annotatedLoadFailed;
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
  State<DualPlayerPanel> createState() => _DualPlayerPanelState();
}

class _DualPlayerPanelState extends State<DualPlayerPanel> {
  bool _isOriginalFullscreen = false;
  bool _isAnnotatedFullscreen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            final Widget original = kIsWeb && widget.originalUrl != null
                ? WebVideoCard(
                    label: 'Original Surveillance Feed',
                    videoUrl: widget.originalUrl!,
                    isPlaying: widget.isPlaying,
                    currentTime: widget.currentTime,
                    playbackSpeed: widget.playbackSpeed,
                    volume: widget.volume,
                    isMuted: widget.isMuted,
                    onTap: widget.onPlayPause,
                    isFullscreen: _isOriginalFullscreen,
                    onToggleFullscreen: () => setState(() {
                      _isOriginalFullscreen = !_isOriginalFullscreen;
                      if (_isOriginalFullscreen) _isAnnotatedFullscreen = false;
                    }),
                  )
                : _playerCard('Original Surveillance Feed', widget.originalController, widget.selectedVideo != null, false, widget.originalLoadFailed);

            final Widget annotated = kIsWeb && widget.annotatedUrl != null && widget.hasAnnotatedVideo
                ? WebVideoCard(
                    label: 'AI Annotated Feed',
                    videoUrl: widget.annotatedUrl!,
                    isPlaying: widget.isPlaying,
                    currentTime: widget.currentTime,
                    playbackSpeed: widget.playbackSpeed,
                    volume: widget.volume,
                    isMuted: widget.isMuted,
                    onTap: widget.onPlayPause,
                    isFullscreen: _isAnnotatedFullscreen,
                    onToggleFullscreen: () => setState(() {
                      _isAnnotatedFullscreen = !_isAnnotatedFullscreen;
                      if (_isAnnotatedFullscreen) _isOriginalFullscreen = false;
                    }),
                  )
                : _playerCard('AI Annotated Feed', widget.annotatedController, widget.hasAnnotatedVideo, true, widget.annotatedLoadFailed);

            if (_isOriginalFullscreen) {
              return Column(children: [original, const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => setState(() => _isOriginalFullscreen = false), icon: const Icon(LucideIcons.minimize2, size: 14), label: const Text('Exit Original Feed Fullscreen', style: TextStyle(fontSize: 12)))]);
            }
            if (_isAnnotatedFullscreen) {
              return Column(children: [annotated, const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => setState(() => _isAnnotatedFullscreen = false), icon: const Icon(LucideIcons.minimize2, size: 14), label: const Text('Exit AI Annotated Feed Fullscreen', style: TextStyle(fontSize: 12)))]);
            }

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
        if (widget.duration > Duration.zero) ...[
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

  Widget _playerCard(
    String label,
    VideoPlayerController? controller,
    bool shouldHaveContent,
    bool isAnnotated,
    bool loadFailed,
  ) {
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
              onTap: widget.onPlayPause,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else if (widget.selectedVideo == null)
            _placeholder(LucideIcons.alertCircle, 'No footage selected.')
          else if (isAnnotated && !shouldHaveContent)
            _placeholder(LucideIcons.tv, 'Annotated Video Unresolved',
                subtitle: 'Processing not complete or annotated MP4 not yet generated.', color: AppColors.warning)
          else if (loadFailed)
            _placeholder(LucideIcons.alertTriangle, 'Failed to load video.',
                subtitle: 'The file may be unreachable, corrupted, or in an unsupported format.',
                color: AppColors.danger)
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
    final totalMs = widget.duration.inMilliseconds.toDouble();
    return SizedBox(
      height: 34,
      child: LayoutBuilder(
        builder: (context, constraints) {
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
                  value: widget.currentTime.inMilliseconds.toDouble().clamp(0, totalMs),
                  activeColor: AppColors.accentBlue,
                  onChanged: (v) => widget.onSeek(Duration(milliseconds: v.round())),
                ),
              ),
              SizedBox(
                width: constraints.maxWidth,
                height: 34,
                child: Stack(
                  children: [
                    for (final det in widget.detections)
                      Builder(builder: (context) {
                        final t = (det.videoTimestamp ?? 0) * 1000;
                        final percent = totalMs > 0 ? (t / totalMs).clamp(0.0, 1.0) : 0.0;
                        final isSelected = widget.selectedDetection?.id == det.id;
                        final color = severityColor(det.severity);
                        return Positioned(
                          left: inset + trackWidth * percent - 6,
                          top: 11,
                          child: Tooltip(
                            message:
                                '${formatDistressType(det.distressType)}\nTracking: #${det.trackingId ?? det.id}\nSeverity: ${det.severity.toUpperCase()}\nTime: ${formatTime(Duration(milliseconds: t.round()))}',
                            child: GestureDetector(
                              onTap: () => widget.onFocusDetection(det),
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
              IconButton(onPressed: widget.onPlayPause, icon: Icon(widget.isPlaying ? LucideIcons.pause : LucideIcons.play, size: 16), tooltip: widget.isPlaying ? 'Pause' : 'Play'),
              IconButton(onPressed: widget.onStop, icon: const Icon(LucideIcons.square, size: 14), tooltip: 'Stop'),
              IconButton(onPressed: widget.onReplay, icon: const Icon(LucideIcons.rotateCcw, size: 15), tooltip: 'Replay'),
              const SizedBox(width: 6),
              Text('${formatTime(widget.currentTime)} / ${formatTime(widget.duration)}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
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
                    value: widget.playbackSpeed,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 0.5, child: Text('0.5x', style: TextStyle(fontSize: 11, color: AppColors.primaryText))),
                      DropdownMenuItem(value: 1.0, child: Text('1.0x', style: TextStyle(fontSize: 11, color: AppColors.primaryText))),
                      DropdownMenuItem(value: 1.5, child: Text('1.5x', style: TextStyle(fontSize: 11, color: AppColors.primaryText))),
                      DropdownMenuItem(value: 2.0, child: Text('2.0x', style: TextStyle(fontSize: 11, color: AppColors.primaryText))),
                    ],
                    onChanged: (v) => widget.onSpeedChange(v ?? widget.playbackSpeed),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: widget.onToggleMute,
                icon: Icon(widget.isMuted ? LucideIcons.volumeX : LucideIcons.volume2, size: 15),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
              SizedBox(
                width: 90,
                child: Slider(
                  min: 0,
                  max: 1,
                  value: widget.volume,
                  activeColor: AppColors.accentBlue,
                  onChanged: widget.onVolumeChange,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: widget.onToggleFullscreen,
                icon: Icon(widget.isFullscreen ? LucideIcons.minimize2 : LucideIcons.maximize2, size: 15),
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
    final currentFrame = (widget.currentTime.inMilliseconds / 1000 * fps).floor();
    final totalFrame = (widget.duration.inMilliseconds / 1000 * fps).floor();
    final status = widget.selectedVideo?.processingStatus ?? 'idle';
    final statusColor = status == 'completed' ? AppColors.success : AppColors.warning;

    final stats = [
      ('Status', status.toUpperCase(), statusColor),
      ('Resolution', '1920x1080 (1080p)', AppColors.primaryText),
      ('FPS', '30.0 fps', AppColors.primaryText),
      ('Frame', '$currentFrame / $totalFrame', AppColors.primaryText),
      ('Total Detections', '${widget.detections.length}', AppColors.primaryText),
      ('Target speed', '${widget.playbackSpeed}x', AppColors.primaryText),
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
        if (widget.syncWarning != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertTriangle, size: 12, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(widget.syncWarning!, style: const TextStyle(fontSize: 10, color: AppColors.warning)),
            ],
          ),
      ],
    );
  }
}
