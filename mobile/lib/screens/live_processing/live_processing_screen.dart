import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/video_api.dart';
import '../../theme/app_colors.dart';

enum _LogType { info, success, warning, error }

class _ActivityLog {
  const _ActivityLog({required this.time, required this.message, required this.type});
  final String time;
  final String message;
  final _LogType type;
}

/// Matches the real stage strings pipeline_manager.py actually sets on
/// UploadedVideo.processing_stage, in order (10% / 25% / 80% / 90% / 95% /
/// 100%) -- not an arbitrary/simulated vocabulary, since this screen now
/// displays the real polled progress instead of a client-side animation.
const _kMilestones = [
  'Uploading Video',
  'Extracting Frames',
  'Running AI Detection',
  'Saving Results',
  'Generating Reports',
  'Finalizing Inspection',
  'Completed',
];

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// LiveProcessing/LiveProcessingDashboard.tsx: real backend wiring against
/// GET /api/v1/videos/, GET /api/v1/detection/summary, GET /api/v1/reports/,
/// and POST /api/v1/detection/video/{id} -- same precedent as Live
/// Detection/GIS Map/Upload Video. The frame-extraction/YOLO/tracking
/// progress bar is a client-side simulation in the React source too (no
/// backend push channel for pipeline progress), so it's ported as-is.
class LiveProcessingScreen extends StatefulWidget {
  const LiveProcessingScreen({super.key});

  @override
  State<LiveProcessingScreen> createState() => _LiveProcessingScreenState();
}

class _LiveProcessingScreenState extends State<LiveProcessingScreen> {
  final _api = VideoApi();
  Timer? _pollTimer;
  Timer? _elapsedTicker;

  List<UploadedVideo> _videos = [];
  UploadedVideo? _selectedVideo;
  bool _loading = true;
  String? _error;

  int _videosUploaded = 0;
  int _videosProcessed = 0;
  int _totalDistresses = 0;
  double _roadHealthScore = 100.0;
  int _reportsGenerated = 0;

  int _progress = 0;
  String _currentStage = 'Idle';
  final List<_ActivityLog> _activityLogs = [];

  int? _statusAppliedForId;
  String? _statusAppliedValue;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchData());
    // Ticks the elapsed-time display live between the 4s poll refreshes;
    // the progress/stage numbers themselves only update on each real poll.
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_selectedVideo?.processingStatus.toLowerCase() == 'processing') {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _elapsedTicker?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final videoList = await _api.fetchVideos(limit: 100);
      final uploaded = videoList.length;
      final processed =
          videoList.where((v) => v.processingStatus.toLowerCase() == 'completed').length;

      final results = await Future.wait([_api.fetchDetectionSummary(), _api.fetchReportsCount()]);
      final summary = results[0] as DetectionSummary;
      final reportsCount = results[1] as int;

      if (!mounted) return;
      setState(() {
        _videos = videoList;
        _videosUploaded = uploaded;
        _videosProcessed = processed;
        _totalDistresses = summary.totalDetections;
        _roadHealthScore = summary.roadHealthScore;
        _reportsGenerated = reportsCount;
        _error = null;
        _loading = false;
      });

      UploadedVideo? next = _selectedVideo;
      if (next != null) {
        next = videoList.where((v) => v.id == next!.id).firstOrNull ?? next;
      } else if (videoList.isNotEmpty) {
        next = videoList.first;
      }
      // Re-applies every poll while status stays "processing", not just on
      // the first transition into it -- real progress/stage advance across
      // multiple polls within that same status, so this needs to keep
      // re-syncing from the backend's real numbers each time, not just once.
      final stillProcessing = next?.processingStatus.toLowerCase() == 'processing';
      if (next != null &&
          (next.id != _statusAppliedForId || next.processingStatus != _statusAppliedValue || stillProcessing)) {
        setState(() => _selectedVideo = next);
        _applyStatusEffects(next);
      } else if (next?.id != _selectedVideo?.id) {
        setState(() => _selectedVideo = next);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to synchronize dashboard statistics with backend registry.';
        _loading = false;
      });
    }
  }

  void _addLogOnce(String message, _LogType type) {
    final exists = _activityLogs.take(3).any((l) => l.message == message);
    if (exists) return;
    setState(() {
      _activityLogs.insert(0, _ActivityLog(time: _formatTime(DateTime.now()), message: message, type: type));
    });
  }

  String _formatTime(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour < 12 ? 'am' : 'pm';
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hour12:$mm:$ss $period';
  }

  /// Reads real progress/stage straight from the polled UploadedVideo record
  /// (progress 0-100, processing_stage set by pipeline_manager.py at each
  /// real step) instead of running a client-side simulated timer -- called
  /// on every poll while status stays "processing" so it keeps re-syncing
  /// as the real numbers advance, not just once on the status transition.
  void _applyStatusEffects(UploadedVideo video) {
    _statusAppliedForId = video.id;
    _statusAppliedValue = video.processingStatus;

    final status = video.processingStatus.toLowerCase();
    if (status == 'completed') {
      setState(() {
        _progress = 100;
        _currentStage = 'Completed';
      });
      _addLogOnce(
        'Detection pipeline finished successfully. PDF report and CSV datasets compiled.',
        _LogType.success,
      );
    } else if (status == 'failed') {
      final failureDetail = video.processingStage ?? 'Unknown error';
      setState(() {
        _progress = video.progress ?? 0;
        _currentStage = 'Failed';
      });
      _addLogOnce('Pipeline failure: $failureDetail', _LogType.error);
    } else if (status == 'processing') {
      final realStage = video.processingStage ?? 'Extracting Frames';
      setState(() {
        _progress = video.progress ?? 0;
        _currentStage = realStage;
      });
      _logForRealStage(realStage);
    } else {
      setState(() {
        _progress = 0;
        _currentStage = 'Pending';
      });
    }
  }

  void _logForRealStage(String stage) {
    switch (stage) {
      case 'Extracting Frames':
        _addLogOnce('Decompressing video stream and caching frame segments.', _LogType.info);
        break;
      case 'Running AI Detection':
        _addLogOnce(
          'Running YOLOX inference weights. Scanning frames for road distress markers.',
          _LogType.info,
        );
        break;
      case 'Saving Results':
        _addLogOnce('Persisting detection records and computing severity metrics.', _LogType.info);
        break;
      case 'Generating Reports':
        _addLogOnce('Executing priority recommendation engine and compiling reports.', _LogType.success);
        break;
      case 'Finalizing Inspection':
        _addLogOnce('Finalizing inspection record and generating annotated video.', _LogType.info);
        break;
    }
  }

  void _selectVideoRow(UploadedVideo video) {
    _activityLogs.clear();
    setState(() => _selectedVideo = video);
    _applyStatusEffects(video);
  }

  Future<void> _handleTriggerProcessing() async {
    final video = _selectedVideo;
    if (video == null) return;
    _addLogOnce('Sending execution request to backend orchestration pipeline...', _LogType.info);
    try {
      await _api.triggerDetection(video.id);
      final updated = video.copyWith(processingStatus: 'processing');
      setState(() => _selectedVideo = updated);
      _applyStatusEffects(updated);
      _fetchData();
    } catch (e) {
      final detail = e is VideoApiException ? e.message : e.toString();
      _addLogOnce('Failed to trigger processing: $detail', _LogType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(LucideIcons.activity, size: 24, color: Color(0xFFA855F7)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live Pipeline Monitor',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTextLight,
                      shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Track video ingestion, frame extraction, YOLO inference, and task allocation milestones.',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryTextLight),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.xCircle, size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger))),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        _KpiGrid(
          videosUploaded: _videosUploaded,
          videosProcessed: _videosProcessed,
          totalDistresses: _totalDistresses,
          roadHealthScore: _roadHealthScore,
          reportsGenerated: _reportsGenerated,
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final queue = _QueueCard(
              loading: _loading,
              videos: _videos,
              selectedId: _selectedVideo?.id,
              onSelect: _selectVideoRow,
            );
            final monitor = _MonitorCard(
              video: _selectedVideo,
              progress: _progress,
              currentStage: _currentStage,
              activityLogs: _activityLogs,
              onTriggerProcessing: _handleTriggerProcessing,
            );

            if (narrow) {
              return Column(
                children: [
                  SizedBox(height: 360, child: queue),
                  const SizedBox(height: 24),
                  monitor,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 320, height: 560, child: queue),
                const SizedBox(width: 24),
                Expanded(child: monitor),
              ],
            );
          },
        ),
      ],
    );
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.videosUploaded,
    required this.videosProcessed,
    required this.totalDistresses,
    required this.roadHealthScore,
    required this.reportsGenerated,
  });

  final int videosUploaded;
  final int videosProcessed;
  final int totalDistresses;
  final double roadHealthScore;
  final int reportsGenerated;

  @override
  Widget build(BuildContext context) {
    final completionRate =
        videosUploaded > 0 ? '${((videosProcessed / videosUploaded) * 100).round()}% completion rate' : '0% completion rate';

    final cards = [
      _KpiData(LucideIcons.video, 'Ingested Footage', '$videosUploaded', 'Total video files uploaded', AppColors.accentBlue),
      _KpiData(LucideIcons.checkCircle2, 'Processed Feeds', '$videosProcessed', completionRate, AppColors.success),
      _KpiData(LucideIcons.shieldAlert, 'Total Distresses', '$totalDistresses', 'Logged anomalies on map', AppColors.danger),
      _KpiData(
        LucideIcons.trendingUp,
        'Road Health Index',
        '${roadHealthScore.toStringAsFixed(1)}%',
        'Weighted distress deductions',
        AppColors.warning,
      ),
      _KpiData(LucideIcons.fileText, 'Generated Reports', '$reportsGenerated', 'PDF & Excel datasets exported', const Color(0xFFA855F7)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700 ? 2 : (constraints.maxWidth < 1200 ? 3 : 5);
        const gap = 16.0;
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in cards) SizedBox(width: tileWidth, child: _KpiCard(data: c))],
        );
      },
    );
  }
}

class _KpiData {
  const _KpiData(this.icon, this.label, this.value, this.footer, this.color);
  final IconData icon;
  final String label;
  final String value;
  final String footer;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 16, color: data.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 4),
          Text(data.footer, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
        ],
      ),
    );
  }
}

Color _statusTagColor(String status) {
  switch (status.toLowerCase()) {
    case 'processing':
      return const Color(0xFF3B82F6);
    case 'completed':
      return const Color(0xFF10B981);
    case 'failed':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF616161);
  }
}

Color _statusTagBg(String status) {
  switch (status.toLowerCase()) {
    case 'processing':
      return const Color(0x263B82F6);
    case 'completed':
      return const Color(0x2610B981);
    case 'failed':
      return const Color(0x26EF4444);
    default:
      return const Color(0xFFE0E0E0);
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.loading,
    required this.videos,
    required this.selectedId,
    required this.onSelect,
  });

  final bool loading;
  final List<UploadedVideo> videos;
  final int? selectedId;
  final ValueChanged<UploadedVideo> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.video, size: 16, color: AppColors.primaryText),
              SizedBox(width: 8),
              Text(
                'Footage Registry Queue',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA855F7)),
                        SizedBox(height: 10),
                        Text('Loading video archives...', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                      ],
                    ),
                  )
                : videos.isEmpty
                    ? const Center(
                        child: Text(
                          'No surveillance logs indexed in the database.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                        ),
                      )
                    : ListView.builder(
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final v = videos[index];
                          final isActive = v.id == selectedId;
                          final status = v.processingStatus.toLowerCase();
                          return InkWell(
                            onTap: () => onSelect(v),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.accentBlueLight : Colors.transparent,
                                border: Border.all(
                                  color: isActive ? AppColors.accentBlue : Colors.transparent,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          v.filename,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${v.uploadTimestamp.day}/${v.uploadTimestamp.month}/${v.uploadTimestamp.year}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _statusTagBg(status),
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _statusTagColor(status)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.secondaryText),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _MonitorCard extends StatelessWidget {
  const _MonitorCard({
    required this.video,
    required this.progress,
    required this.currentStage,
    required this.activityLogs,
    required this.onTriggerProcessing,
  });

  final UploadedVideo? video;
  final int progress;
  final String currentStage;
  final List<_ActivityLog> activityLogs;
  final VoidCallback onTriggerProcessing;

  @override
  Widget build(BuildContext context) {
    if (video == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.cpu, size: 32, color: AppColors.secondaryText),
              SizedBox(height: 10),
              Text(
                'Select a video source to begin surveillance monitoring.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryText),
              ),
            ],
          ),
        ),
      );
    }

    final v = video!;
    final status = v.processingStatus.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.filename, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Video ID: #${v.id} • Registry date: ${v.uploadTimestamp.day}/${v.uploadTimestamp.month}/${v.uploadTimestamp.year}',
                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
              if (status == 'waiting')
                ElevatedButton.icon(
                  onPressed: onTriggerProcessing,
                  icon: const Icon(LucideIcons.play, size: 14),
                  label: const Text('Run AI Pipeline', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryText,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final boxes = [
                _StatusBox('Ingestion Status', 'Uploaded', AppColors.success),
                _StatusBox('Pipeline Status', v.processingStatus, _statusTagColor(status)),
                _StatusBox('Current Stage', currentStage, AppColors.primaryText),
              ];
              if (narrow) {
                return Column(
                  children: [for (final b in boxes) Padding(padding: const EdgeInsets.only(bottom: 8), child: b)],
                );
              }
              return Row(
                children: [for (final b in boxes) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: b))],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progress Rate', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
              Row(
                children: [
                  if (status == 'processing' && video?.processingStartedAt != null) ...[
                    Text(
                      _formatElapsedLive(video!.processingStartedAt!),
                      style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text('$progress%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(status == 'failed' ? AppColors.danger : AppColors.primaryText),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pipeline Milestones Progression',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 10),
          _MilestonesStepper(status: status, currentStage: currentStage),
          const SizedBox(height: 20),
          const Text(
            'Pipeline Activity Log',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 180, minHeight: 80),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: activityLogs.isEmpty
                ? const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.clock, size: 16, color: AppColors.secondaryText),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Diagnostics logs are currently empty. Run pipeline to stream activity logs.',
                            style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: activityLogs.length,
                    itemBuilder: (context, index) {
                      final log = activityLogs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('[${log.time}]', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                log.message,
                                style: TextStyle(fontSize: 10, color: _logColor(log.type)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _logColor(_LogType type) {
    switch (type) {
      case _LogType.success:
        return const Color(0xFF10B981);
      case _LogType.error:
        return const Color(0xFFEF4444);
      case _LogType.warning:
        return const Color(0xFFF59E0B);
      case _LogType.info:
        return AppColors.secondaryText;
    }
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox(this.label, this.value, this.valueColor);
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _MilestonesStepper extends StatelessWidget {
  const _MilestonesStepper({required this.status, required this.currentStage});

  final String status;
  final String currentStage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var idx = 0; idx < _kMilestones.length; idx++) _buildRow(idx),
      ],
    );
  }

  Widget _buildRow(int idx) {
    final label = _kMilestones[idx];
    var isDone = false;
    var isCurrent = false;

    if (status == 'completed') {
      isDone = true;
    } else if (status == 'failed') {
      isDone = false;
    } else if (status == 'processing') {
      if (currentStage == label) {
        isCurrent = true;
      } else {
        final stepIndex = _kMilestones.indexOf(currentStage);
        if (stepIndex > idx) isDone = true;
      }
    } else {
      if (idx == 0) isDone = true;
      if (idx == 1) isCurrent = true;
    }

    final bulletColor = isDone
        ? const Color(0xFF10B981)
        : isCurrent
            ? const Color(0xFF3B82F6)
            : AppColors.secondaryText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: isDone || isCurrent ? 1 : 0.4,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: bulletColor, width: 1.5),
                color: isDone
                    ? const Color(0x1A10B981)
                    : isCurrent
                        ? const Color(0x143B82F6)
                        : Colors.transparent,
              ),
              child: isDone
                  ? const Icon(LucideIcons.checkCircle2, size: 13, color: Color(0xFF10B981))
                  : Text('${idx + 1}', style: TextStyle(fontSize: 10, color: bulletColor, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primaryText)),
          ],
        ),
      ),
    );
  }
}

/// Real wall-clock elapsed time since processing_started_at, ticked live by
/// _elapsedTicker -- not a fixed/simulated number.
String _formatElapsedLive(DateTime startedAt) {
  final elapsed = DateTime.now().toUtc().difference(startedAt.toUtc());
  final totalSeconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
  if (totalSeconds < 60) return '${totalSeconds}s';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes}m ${seconds}s';
}
