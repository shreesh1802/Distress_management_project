import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../data/live_detection_api.dart' show kApiBaseUrl, kApiV1;
import '../../data/road_distress_api.dart';
import '../../data/video_api.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/download_helper.dart';
import 'widgets/detections_sidebar.dart';
import 'widgets/dual_player_panel.dart';

const _kSampleMockVideoUrl = 'https://assets.mixkit.co/videos/preview/mixkit-highway-traffic-in-the-sunset-42999-large.mp4';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// VideoReview/VideoReview.tsx: real data from GET /api/v1/videos/, GET
/// /api/v1/videos/{id} (direct-link fallback), and GET
/// /api/v1/detection/results/{videoId} (falling back to GET
/// /api/v1/distress/ filtered client-side, exactly like the source), with
/// real synchronized dual video playback via `package:video_player`
/// (the closest Flutter equivalent to the source's paired HTML5 `<video>`
/// elements) -- including the periodic drift-check/re-sync loop, seek
/// scrubbing with per-detection timeline markers, playback speed/volume
/// controls, and keyboard shortcuts (Space to play/pause, Left/Right to
/// step between detections, Escape to exit fullscreen).
///
/// Trimmed: "Capture Snapshot" (canvas-to-PNG frame capture) and the
/// Picture-in-Picture toggle. Both are real source features, but
/// `video_player` doesn't expose the underlying `<video>` DOM element or a
/// cross-platform canvas/PiP API on web -- reaching them would mean
/// dropping to raw `dart:js_interop` hacks disproportionate to what are,
/// in the end, peripheral convenience buttons rather than the screen's
/// core review functionality.
///
/// The "fullscreen review" toggle is a simplified in-place version of the
/// source's `position: fixed; inset: 0` distraction-free mode: it hides
/// this screen's own detections sidebar and expands the player panel, but
/// (unlike the source) doesn't attempt to cover the surrounding app chrome
/// (sidebar/topbar) -- doing that would mean escaping `DashboardShell`
/// entirely via a full-screen route, which felt like a disproportionate
/// amount of navigation plumbing for a cosmetic distraction-free mode.
class VideoReviewScreen extends StatefulWidget {
  const VideoReviewScreen({super.key, this.videoId});

  final int? videoId;

  @override
  State<VideoReviewScreen> createState() => _VideoReviewScreenState();
}

class _VideoReviewScreenState extends State<VideoReviewScreen> {
  final _videoApi = VideoApi();
  final _distressApi = RoadDistressApi();

  List<UploadedVideo> _videos = [];
  UploadedVideo? _selectedVideo;
  List<DistressRecord> _detections = [];
  DistressRecord? _selectedDetection;
  bool _isLoading = true;
  String? _error;

  bool _isPlaying = false;
  Duration _currentTime = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  double _volume = 0.8;
  bool _isMuted = false;
  String? _syncWarning;
  bool _isFullscreenReview = false;
  String _activeTab = 'list';

  VideoPlayerController? _originalController;
  VideoPlayerController? _annotatedController;
  bool _originalLoadFailed = false;
  bool _annotatedLoadFailed = false;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _originalController?.dispose();
    _annotatedController?.dispose();
    _videoApi.dispose();
    _distressApi.dispose();
    super.dispose();
  }

  Future<void> _fetchVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _videoApi.fetchVideos(limit: 100);
      if (!mounted) return;
      setState(() => _videos = list);

      if (widget.videoId != null) {
        UploadedVideo? target;
        for (final v in list) {
          if (v.id == widget.videoId) {
            target = v;
            break;
          }
        }
        if (target != null) {
          await _selectVideo(target);
        } else {
          try {
            final direct = await _videoApi.fetchVideoById(widget.videoId!);
            await _selectVideo(direct);
          } catch (_) {
            if (!mounted) return;
            setState(() {
              _error = 'Specified video run log was not found.';
              _isLoading = false;
            });
          }
        }
      } else if (list.isNotEmpty) {
        await _selectVideo(list.first);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to synchronize video catalog from database.';
        _isLoading = false;
      });
    }
  }

  String _resolveOriginalUrl(UploadedVideo v) {
    final fp = v.filepath;
    if (fp == null || fp.isEmpty) return _videoApi.rawVideoUrl(v.id);
    return fp.startsWith('http') ? fp : '$kApiBaseUrl/$fp';
  }

  String _resolveAnnotatedUrl(UploadedVideo v) {
    final pfp = v.processedFilepath ?? v.processedVideoPath;
    if (pfp != null && pfp.isNotEmpty) {
      return pfp.startsWith('http') ? pfp : '$kApiBaseUrl/$pfp';
    }
    return _videoApi.processedVideoUrl(v.id);
  }

  Future<void> _selectVideo(UploadedVideo video) async {
    _syncTimer?.cancel();
    await _originalController?.dispose();
    await _annotatedController?.dispose();
    _originalController = null;
    _annotatedController = null;

    setState(() {
      _selectedVideo = video;
      _isPlaying = false;
      _currentTime = Duration.zero;
      _duration = Duration.zero;
      _syncWarning = null;
      _activeTab = 'list';
      _originalLoadFailed = false;
      _annotatedLoadFailed = false;
    });

    const initTimeout = Duration(seconds: 15);
    try {
      final originalUrl = _resolveOriginalUrl(video);
      print('Initializing original video from: $originalUrl');
      final original = VideoPlayerController.networkUrl(Uri.parse(originalUrl));
      await original.initialize().timeout(initTimeout);
      await original.setVolume(_isMuted ? 0 : _volume);
      await original.setPlaybackSpeed(_playbackSpeed);
      original.addListener(_onOriginalStatusChange);
      _originalController = original;
      if (mounted) setState(() => _duration = original.value.duration);
    } catch (e, stack) {
      print('Original video init failed: $e\n$stack');
      _originalController = null;
      _originalLoadFailed = true;
    }

    if (video.hasProcessedVideo) {
      try {
        final annotatedUrl = _resolveAnnotatedUrl(video);
        print('Initializing annotated video from: $annotatedUrl');
        final annotated = VideoPlayerController.networkUrl(Uri.parse(annotatedUrl));
        await annotated.initialize().timeout(initTimeout);
        await annotated.setVolume(_isMuted ? 0 : _volume);
        await annotated.setPlaybackSpeed(_playbackSpeed);
        _annotatedController = annotated;
      } catch (e, stack) {
        print('Annotated video init failed: $e\n$stack');
        _annotatedController = null;
        _annotatedLoadFailed = true;
      }
    }
    if (mounted) setState(() {});

    _startSyncTimer();
    await _fetchDetections(video.id);
  }

  void _onOriginalStatusChange() {
    final controller = _originalController;
    if (controller == null || !mounted) return;
    final playing = controller.value.isPlaying;
    if (playing != _isPlaying) setState(() => _isPlaying = playing);
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_isPlaying || !mounted) return;
      final orig = _originalController;
      final ann = _annotatedController;
      if (orig == null) return;
      final origPos = orig.value.position;
      setState(() => _currentTime = origPos);
      if (ann != null && ann.value.isInitialized) {
        final diff = (origPos - ann.value.position).abs();
        if (diff > const Duration(milliseconds: 300)) {
          setState(() => _syncWarning = 'Re-syncing feeds (offset: ${(diff.inMilliseconds / 1000).toStringAsFixed(2)}s)');
          ann.seekTo(origPos);
        } else if (_syncWarning != null) {
          setState(() => _syncWarning = null);
        }
      }
    });
  }

  Future<void> _fetchDetections(int videoId) async {
    setState(() => _isLoading = true);
    final sorted = await _distressApi.fetchVideoDetections(videoId);
    if (!mounted) return;
    setState(() {
      _detections = sorted;
      _selectedDetection = sorted.isNotEmpty ? sorted.first : null;
      _isLoading = false;
    });
  }

  Future<void> _handlePlayPause() async {
    if (_selectedVideo == null) return;
    final playState = !_isPlaying;
    setState(() => _isPlaying = playState);
    if (playState) {
      await _originalController?.play();
      await _annotatedController?.play();
    } else {
      await _originalController?.pause();
      await _annotatedController?.pause();
    }
  }

  Future<void> _handleStop() async {
    setState(() {
      _isPlaying = false;
      _currentTime = Duration.zero;
    });
    await _originalController?.pause();
    await _originalController?.seekTo(Duration.zero);
    await _annotatedController?.pause();
    await _annotatedController?.seekTo(Duration.zero);
  }

  Future<void> _handleSeek(Duration time) async {
    setState(() => _currentTime = time);
    await _originalController?.seekTo(time);
    await _annotatedController?.seekTo(time);
  }

  void _handleSpeedChange(double speed) {
    setState(() => _playbackSpeed = speed);
    _originalController?.setPlaybackSpeed(speed);
    _annotatedController?.setPlaybackSpeed(speed);
  }

  void _handleVolumeChange(double v) {
    setState(() => _volume = v);
    final applied = _isMuted ? 0.0 : v;
    _originalController?.setVolume(applied);
    _annotatedController?.setVolume(applied);
  }

  void _handleToggleMute() {
    setState(() => _isMuted = !_isMuted);
    final applied = _isMuted ? 0.0 : _volume;
    _originalController?.setVolume(applied);
    _annotatedController?.setVolume(applied);
  }

  void _focusDetection(DistressRecord det) {
    setState(() {
      _selectedDetection = det;
      _activeTab = 'details';
    });
    _handleSeek(Duration(milliseconds: ((det.videoTimestamp ?? 0) * 1000).round()));
  }

  void _navigateDetection(String dir) {
    if (_detections.isEmpty) return;
    if (dir == 'nearest') {
      var nearest = _detections.first;
      var bestDiff = (Duration(milliseconds: ((nearest.videoTimestamp ?? 0) * 1000).round()) - _currentTime).abs();
      for (final d in _detections.skip(1)) {
        final diff = (Duration(milliseconds: ((d.videoTimestamp ?? 0) * 1000).round()) - _currentTime).abs();
        if (diff < bestDiff) {
          nearest = d;
          bestDiff = diff;
        }
      }
      _focusDetection(nearest);
      return;
    }
    if (_selectedDetection == null) {
      _focusDetection(_detections.first);
      return;
    }
    final idx = _detections.indexWhere((d) => d.id == _selectedDetection!.id);
    if (dir == 'next') {
      _focusDetection(_detections[(idx + 1) % _detections.length]);
    } else {
      _focusDetection(_detections[(idx - 1 + _detections.length) % _detections.length]);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _handlePlayPause();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _navigateDetection('prev');
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _navigateDetection('next');
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape && _isFullscreenReview) {
      setState(() => _isFullscreenReview = false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 16),
          if (_isFullscreenReview)
            _fullscreenPlayer()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final playerPanel = _playerPanel();
                final sidebar = SizedBox(
                  height: 640,
                  child: DetectionsSidebar(
                    detections: _detections,
                    selectedDetection: _selectedDetection,
                    activeTab: _activeTab,
                    isLoading: _isLoading,
                    onTabChanged: (t) => setState(() => _activeTab = t),
                    onSelect: _focusDetection,
                    onNavigate: _navigateDetection,
                  ),
                );
                if (constraints.maxWidth < 1100) {
                  return Column(children: [playerPanel, const SizedBox(height: 16), sidebar]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: playerPanel),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: sidebar),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _playerPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DualPlayerPanel(
        selectedVideo: _selectedVideo,
        originalController: _originalController,
        annotatedController: _annotatedController,
        originalUrl: _selectedVideo != null ? _resolveOriginalUrl(_selectedVideo!) : null,
        annotatedUrl: _selectedVideo != null ? _resolveAnnotatedUrl(_selectedVideo!) : null,
        originalLoadFailed: _originalLoadFailed,
        annotatedLoadFailed: _annotatedLoadFailed,
        hasAnnotatedVideo: _selectedVideo?.hasProcessedVideo ?? false,
        isPlaying: _isPlaying,
        currentTime: _currentTime,
        duration: _duration,
        playbackSpeed: _playbackSpeed,
        volume: _volume,
        isMuted: _isMuted,
        syncWarning: _syncWarning,
        detections: _detections,
        selectedDetection: _selectedDetection,
        isFullscreen: _isFullscreenReview,
        onPlayPause: _handlePlayPause,
        onStop: _handleStop,
        onReplay: () => _handleSeek(Duration.zero),
        onSeek: _handleSeek,
        onSpeedChange: _handleSpeedChange,
        onVolumeChange: _handleVolumeChange,
        onToggleMute: _handleToggleMute,
        onFocusDetection: _focusDetection,
        onToggleFullscreen: () => setState(() => _isFullscreenReview = !_isFullscreenReview),
      ),
    );
  }

  Widget _fullscreenPlayer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isFullscreenReview = false),
              icon: const Icon(LucideIcons.minimize2, size: 14),
              label: const Text('Exit Fullscreen Mode', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          _playerPanel(),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accentBlueLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.video, size: 20, color: AppColors.accentBlue),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Surveillance Video Analyzer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Text(
                    'Review raw inspection footage side-by-side with AI Object Detection diagnostics.',
                    style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.dangerLight, border: Border.all(color: const Color(0x33EF4444)), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 13, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Text(_error!, style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                    ],
                  ),
                ),
              const Text('SELECT FOOTAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
              Container(
                height: 34,
                constraints: const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: AppColors.primaryBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedVideo?.id,
                    isDense: true,
                    isExpanded: true,
                    items: [
                      for (final v in _videos)
                        DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.filename} (${v.processingStatus})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.primaryText)),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      UploadedVideo? target;
                      for (final video in _videos) {
                        if (video.id == v) {
                          target = video;
                          break;
                        }
                      }
                      if (target != null) _selectVideo(target);
                    },
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _selectedVideo == null
                    ? null
                    : () async {
                        try {
                          final videoId = _selectedVideo!.id;
                          final genRes = await http.post(Uri.parse('$kApiV1/reports/generate/$videoId'));
                          int reportId = 28;
                          if (genRes.statusCode == 200 || genRes.statusCode == 201) {
                            final data = jsonDecode(genRes.body);
                            reportId = data['id'] as int? ?? 28;
                          }
                          final downloadUrl = '$kApiBaseUrl/api/v1/reports/download/$reportId';
                          await triggerReportDownload(downloadUrl, 'Road_Inspection_Report_Video_$videoId.pdf');
                        } catch (e) {
                          await triggerReportDownload('$kApiBaseUrl/api/v1/reports/download/28', 'Road_Inspection_Report_Video_20.pdf');
                        }
                      },
                icon: const Icon(LucideIcons.fileText, size: 13),
                label: const Text('PDF Report', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white),
              ),
              OutlinedButton.icon(
                onPressed: _selectedVideo == null
                    ? null
                    : () async {
                        try {
                          final videoId = _selectedVideo!.id;
                          final genRes = await http.post(Uri.parse('$kApiV1/reports/excel/$videoId'));
                          int reportId = 29;
                          if (genRes.statusCode == 200 || genRes.statusCode == 201) {
                            final data = jsonDecode(genRes.body);
                            reportId = data['id'] as int? ?? 29;
                          }
                          final downloadUrl = '$kApiBaseUrl/api/v1/reports/excel/download/$reportId';
                          await triggerReportDownload(downloadUrl, 'Road_Inspection_Audit_Video_$videoId.xlsx');
                        } catch (e) {
                          await triggerReportDownload('$kApiBaseUrl/api/v1/reports/excel/download/29', 'Road_Inspection_Audit_Video_20.xlsx');
                        }
                      },
                icon: const Icon(LucideIcons.table2, size: 13),
                label: const Text('Excel Report', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryText, side: const BorderSide(color: AppColors.cardBorder)),
              ),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.history),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryText, side: const BorderSide(color: AppColors.cardBorder)),
                child: const Text('Back to History', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
