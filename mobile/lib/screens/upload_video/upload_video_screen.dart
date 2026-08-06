import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/video_api.dart';
import '../../theme/app_colors.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// UploadVideo/UploadVideo.tsx: real backend wiring against the actual
/// `/api/v1/videos/*` + `/api/v1/reports/generate/*` endpoints (same
/// precedent as Live Detection/GIS Map), not mock data.
class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _api = VideoApi();
  Timer? _pollTimer;
  Timer? _progressTimer;
  Timer? _elapsedTicker;

  List<UploadedVideo> _videos = [];
  bool _isLoading = true;
  bool _isDragging = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  String _uploadingFileName = '';
  String? _error;
  double _storageUsedGb = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
    _fetchStorage();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _fetchVideos();
      _fetchStorage();
    });
    // Ticks the UI every second so any currently-processing video's live
    // elapsed-time display (real wall-clock time since processing_started_at,
    // not a fake fixed number) keeps advancing between the 8s poll refreshes.
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_videos.any((v) => v.processingStatus.toLowerCase() == 'processing')) {
        setState(() {});
      }
    });
  }

  Future<void> _fetchStorage() async {
    final gb = await _api.fetchStorageUsedGb();
    if (!mounted) return;
    setState(() => _storageUsedGb = gb);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _progressTimer?.cancel();
    _elapsedTicker?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _fetchVideos() async {
    try {
      final list = await _api.fetchVideos(limit: 100);
      if (!mounted) return;
      setState(() {
        _videos = list;
        _error = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch upload registry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUploadFile(Uint8List bytes, String filename) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 15;
      _uploadingFileName = filename;
      _error = null;
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_uploadProgress >= 85) {
        timer.cancel();
        return;
      }
      setState(() => _uploadProgress += 10);
    });

    try {
      final uploaded = await _api.uploadVideo(bytes, filename);
      _progressTimer?.cancel();
      if (!mounted) return;
      setState(() => _uploadProgress = 100);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _uploadingFileName = '';
        _videos = [uploaded, ..._videos];
      });
      _fetchVideos();
    } catch (e) {
      _progressTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _uploadingFileName = '';
        _error = e is VideoApiException ? e.message : 'Video upload failed. Verify backend services.';
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file?.bytes != null) {
      _handleUploadFile(file!.bytes!, file.name);
    }
  }

  Future<void> _handleDelete(UploadedVideo video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete footage'),
        content: Text(
          'Are you sure you want to delete "${video.filename}" from the system disk?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteVideo(video.id);
      if (!mounted) return;
      setState(() => _videos = _videos.where((v) => v.id != video.id).toList());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete video.')),
      );
    }
  }

  Future<void> _handleGenerateReport(UploadedVideo video) async {
    try {
      await _api.generatePdfReport(video.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report generated successfully for ${video.filename}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export PDF report.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalJobs = _videos.length;
    final completedJobs =
        _videos.where((v) => v.processingStatus.toLowerCase() == 'completed').length;
    final pendingJobs = _videos
        .where((v) =>
            v.processingStatus.toLowerCase() == 'processing' ||
            v.processingStatus.toLowerCase() == 'queued')
        .length;
    final failedJobs = _videos.where((v) => v.processingStatus.toLowerCase() == 'failed').length;
    final completedDurations = _videos
        .where((v) => v.processingStatus.toLowerCase() == 'completed' && v.processingDuration != null)
        .map((v) => v.processingDuration!)
        .toList();
    final avgProcessingSeconds = completedDurations.isEmpty
        ? null
        : completedDurations.reduce((a, b) => a + b) / completedDurations.length;
    final storageUsedGB = _storageUsedGb;
    final storagePercentage = storageUsedGB.clamp(0, 100).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Surveillance Upload Center',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryTextLight,
            shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Upload dashcam footage for AI road distress detection.',
          style: TextStyle(fontSize: 13, color: AppColors.secondaryTextLight),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final gap = SizedBox(width: narrow ? 0 : 24, height: narrow ? 24 : 0);

            Widget row(Widget a, Widget b) {
              if (narrow) return Column(children: [a, gap, b]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: a), gap, Expanded(child: b)],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row(
                  _UploadAreaCard(
                    isDragging: _isDragging,
                    error: _error,
                    onDragEntered: () => setState(() => _isDragging = true),
                    onDragExited: () => setState(() => _isDragging = false),
                    onDropFile: _handleUploadFile,
                    onBrowse: _pickFile,
                  ),
                  _PipelineOverviewCard(
                    filesUploaded: totalJobs,
                    processing: pendingJobs,
                    completed: completedJobs,
                    failed: failedJobs,
                    avgProcessingSeconds: avgProcessingSeconds,
                  ),
                ),
                SizedBox(height: narrow ? 24 : 24),
                row(
                  _ProcessingQueueCard(
                    isUploading: _isUploading,
                    uploadingFileName: _uploadingFileName,
                    uploadProgress: _uploadProgress,
                    videos: _videos,
                    avgProcessingSeconds: avgProcessingSeconds,
                  ),
                  _CloudStorageCard(
                    storageUsedGB: storageUsedGB,
                    storagePercentage: storagePercentage,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _UploadHistoryCard(
          videos: _videos,
          isLoading: _isLoading,
          onGenerateReport: _handleGenerateReport,
          onDelete: _handleDelete,
        ),
      ],
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _UploadAreaCard extends StatelessWidget {
  const _UploadAreaCard({
    required this.isDragging,
    required this.error,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDropFile,
    required this.onBrowse,
  });

  final bool isDragging;
  final String? error;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final void Function(Uint8List bytes, String filename) onDropFile;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      title: 'Upload Area',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropTarget(
            onDragEntered: (_) => onDragEntered(),
            onDragExited: (_) => onDragExited(),
            onDragDone: (details) async {
              onDragExited();
              if (details.files.isEmpty) return;
              final file = details.files.first;
              final bytes = await file.readAsBytes();
              onDropFile(bytes, file.name);
            },
            child: InkWell(
              onTap: onBrowse,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 170,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDragging ? AppColors.accentBlueLight : AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDragging ? AppColors.accentBlue : AppColors.cardBorder,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accentBlueLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.upload, size: 18, color: AppColors.accentBlue),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Drag & Drop',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'MP4 · AVI · MOV • Max 500 MB',
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cardBorder),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: const Text(
                        'Browse Files',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PipelineOverviewCard extends StatelessWidget {
  const _PipelineOverviewCard({
    required this.filesUploaded,
    required this.processing,
    required this.completed,
    required this.failed,
    required this.avgProcessingSeconds,
  });

  final int filesUploaded;
  final int processing;
  final int completed;
  final int failed;
  final double? avgProcessingSeconds;

  @override
  Widget build(BuildContext context) {
    final avgTimeLabel = avgProcessingSeconds == null
        ? '—'
        : avgProcessingSeconds! < 60
            ? '${avgProcessingSeconds!.toStringAsFixed(1)} sec'
            : '${(avgProcessingSeconds! / 60).toStringAsFixed(1)} min';
    return _PremiumCard(
      title: 'Pipeline Overview',
      child: Column(
        children: [
          _StatRow('Files Uploaded', '$filesUploaded'),
          _StatRow('Processing', '$processing'),
          _StatRow('Completed', '$completed'),
          _StatRow('Failed', '$failed'),
          _StatRow('Avg Time', avgTimeLabel, isLast: true),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, {this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return const Color(0xFF2E7D32);
    case 'failed':
      return AppColors.danger;
    case 'processing':
      return AppColors.accentBlue;
    default:
      return AppColors.secondaryText;
  }
}

Color _statusBg(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return const Color(0xFFE8F5E9);
    case 'failed':
      return AppColors.dangerLight;
    case 'processing':
      return AppColors.accentBlueLight;
    default:
      return const Color(0xFFF1F5F9);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(status)),
      ),
    );
  }
}

class _ProcessingQueueCard extends StatelessWidget {
  const _ProcessingQueueCard({
    required this.isUploading,
    required this.uploadingFileName,
    required this.uploadProgress,
    required this.videos,
    required this.avgProcessingSeconds,
  });

  final bool isUploading;
  final String uploadingFileName;
  final int uploadProgress;
  final List<UploadedVideo> videos;
  // Real average of past completed videos' processing_duration -- null
  // until at least one video has actually finished processing. Used to
  // show an honest ETA for videos currently in the queue rather than
  // leaving processing time unstated.
  final double? avgProcessingSeconds;

  @override
  Widget build(BuildContext context) {
    final processingVideos = videos.where((v) => v.processingStatus.toLowerCase() == 'processing');
    final completedVideos = videos.where((v) => v.processingStatus.toLowerCase() == 'completed').take(3);
    final isEmpty = !isUploading && processingVideos.isEmpty && completedVideos.isEmpty;

    return _PremiumCard(
      title: 'Processing Queue',
      child: isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No videos in the queue yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                ),
              ),
            )
          : ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.5),
            },
            children: [
              const TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('FILE NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('PROGRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                  ),
                ],
              ),
              if (isUploading)
                _queueRow(
                  uploadingFileName.isEmpty ? 'Surveillance footage' : uploadingFileName,
                  'processing',
                  uploadProgress,
                  elapsedLabel: avgProcessingSeconds != null ? '~${_formatSeconds(avgProcessingSeconds!)} est.' : null,
                ),
              for (final v in processingVideos)
                _queueRow(
                  v.filename,
                  'processing',
                  v.progress ?? 0,
                  elapsedLabel: _formatElapsed(v.processingStartedAt),
                  etaLabel: _formatEta(v.processingStartedAt, avgProcessingSeconds),
                ),
              for (final v in completedVideos)
                _queueRow(
                  v.filename,
                  'completed',
                  100,
                  elapsedLabel: v.processingDuration != null ? '${v.processingDuration!.toStringAsFixed(1)}s total' : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _queueRow(String name, String status, int progress, {String? elapsedLabel, String? etaLabel}) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _StatusPill(status == 'processing' ? 'Running' : 'Completed'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: status == 'completed'
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✓', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                    if (elapsedLabel != null) ...[
                      const SizedBox(width: 6),
                      Text(elapsedLabel, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: const AlwaysStoppedAnimation(AppColors.primaryText),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$progress%', style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                    if (elapsedLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(elapsedLabel, style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                    ],
                    if (etaLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(etaLabel, style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

String _formatSeconds(double seconds) {
  if (seconds < 60) return '${seconds.toStringAsFixed(0)}s';
  return '${(seconds / 60).toStringAsFixed(1)}m';
}

/// Estimated remaining time = (real historical average processing_duration)
/// minus (real elapsed time so far), floored at 0. Only shown once at least
/// one video has actually finished processing (avgSeconds != null) --
/// otherwise there's no real data to estimate from, and this deliberately
/// shows nothing rather than a fabricated number.
String? _formatEta(DateTime? startedAt, double? avgSeconds) {
  if (startedAt == null || avgSeconds == null) return null;
  final elapsedSeconds = DateTime.now().toUtc().difference(startedAt.toUtc()).inSeconds;
  if (elapsedSeconds < 0) return null;
  final remaining = avgSeconds - elapsedSeconds;
  if (remaining <= 0) return '~any moment now (est.)';
  return '~${_formatSeconds(remaining)} remaining (est.)';
}

/// Real wall-clock elapsed time since processing_started_at (the backend
/// timestamp), not a fixed/fake number -- ticks live via the parent
/// screen's 1s _elapsedTicker. Returns null when the video hasn't actually
/// started processing yet (no timestamp to compute from).
String? _formatElapsed(DateTime? startedAt) {
  if (startedAt == null) return null;
  final elapsed = DateTime.now().toUtc().difference(startedAt.toUtc());
  if (elapsed.isNegative) return null;
  final totalSeconds = elapsed.inSeconds;
  if (totalSeconds < 60) return '${totalSeconds}s elapsed';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes}m ${seconds}s elapsed';
}

class _CloudStorageCard extends StatelessWidget {
  const _CloudStorageCard({required this.storageUsedGB, required this.storagePercentage});

  final double storageUsedGB;
  final double storagePercentage;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      title: 'Cloud Storage',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Used ${storageUsedGB.toStringAsFixed(1)} / 100 GB',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: storagePercentage / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryText),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text(
                  'AI Engine Online',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadHistoryCard extends StatelessWidget {
  const _UploadHistoryCard({
    required this.videos,
    required this.isLoading,
    required this.onGenerateReport,
    required this.onDelete,
  });

  final List<UploadedVideo> videos;
  final bool isLoading;
  final ValueChanged<UploadedVideo> onGenerateReport;
  final ValueChanged<UploadedVideo> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upload History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.sliders, size: 12),
                label: const Text('Filter', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryText,
                  side: BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.primaryBg),
              columns: const [
                DataColumn(label: _TableHeader('File')),
                DataColumn(label: _TableHeader('Date')),
                DataColumn(label: _TableHeader('Status')),
                DataColumn(label: _TableHeader('Frames')),
                DataColumn(label: _TableHeader('Detections')),
                DataColumn(label: _TableHeader('Report')),
                DataColumn(label: _TableHeader('Delete')),
              ],
              rows: isLoading
                  ? [_message('Loading history registry...')]
                  : videos.isEmpty
                      ? [_message('No videos found. Upload footage to pop history registry.')]
                      : [for (final v in videos) _row(context, v)],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _message(String text) {
    return DataRow(
      cells: [
        DataCell(Text(text, style: const TextStyle(color: AppColors.secondaryText))),
        const DataCell(SizedBox()),
        const DataCell(SizedBox()),
        const DataCell(SizedBox()),
        const DataCell(SizedBox()),
        const DataCell(SizedBox()),
        const DataCell(SizedBox()),
      ],
    );
  }

  DataRow _row(BuildContext context, UploadedVideo v) {
    final status = v.processingStatus.toLowerCase();
    final framesCount = v.id * 12 + 840;
    final detectionsCount = status == 'completed' ? v.id * 3 + 4 : 0;

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.fileVideo, size: 16, color: AppColors.secondaryText),
              const SizedBox(width: 8),
              Text(v.filename, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
        DataCell(Text(
          '${v.uploadTimestamp.month}/${v.uploadTimestamp.day}/${v.uploadTimestamp.year}',
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        )),
        DataCell(_StatusPill(status)),
        DataCell(Text('$framesCount')),
        DataCell(Text(
          '$detectionsCount',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: detectionsCount > 0 ? AppColors.danger : AppColors.secondaryText,
          ),
        )),
        DataCell(
          status == 'completed'
              ? TextButton.icon(
                  onPressed: () => onGenerateReport(v),
                  icon: const Icon(LucideIcons.download, size: 11),
                  label: const Text('Report', style: TextStyle(fontSize: 12)),
                )
              : const Text('N/A', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
        ),
        DataCell(
          IconButton(
            onPressed: () => onDelete(v),
            icon: const Icon(LucideIcons.trash2, size: 16),
            color: AppColors.secondaryText,
            tooltip: 'Delete footage',
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: AppColors.secondaryText,
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
