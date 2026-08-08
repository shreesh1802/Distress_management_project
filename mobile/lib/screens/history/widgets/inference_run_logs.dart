import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/reports_api.dart';
import '../../../data/video_api.dart';
import '../../../theme/app_colors.dart';
import '../timeline_event.dart';
import 'activity_timeline.dart' show formatDateTimeIN;

(Color, Color) _themeColors(String statusLower) {
  switch (statusLower) {
    case 'failed':
      return (AppColors.danger, AppColors.dangerLight);
    case 'processing':
      return (AppColors.accentBlue, AppColors.accentBlueLight);
    case 'pending':
      return (AppColors.warning, AppColors.warningLight);
    default:
      return (AppColors.success, AppColors.successLight);
  }
}

/// Direct port of History.tsx's "Inference Run Logs" section: one
/// expandable card per uploaded video, with a pipeline-stage tracker
/// (computed from the video's real `processing_status`), deterministic-fake
/// district/road/model metadata (see `timeline_event.dart`'s
/// `videoDetailsFor`), and action buttons.
///
/// "Retry Pipeline" mirrors the source's own `alert('Restarting AI
/// pipeline for Video Run #{id}... (Simulated)')` -- it's simulated in the
/// source too, so it's ported as a simulated confirmation rather than
/// trimmed, unlike fully-fake peripheral buttons trimmed on earlier screens
/// (e.g. Reports' "Schedule Report"): this one is a primary action on an
/// otherwise-real card, not a bolted-on extra.
class InferenceRunLogs extends StatefulWidget {
  const InferenceRunLogs({
    super.key,
    required this.videos,
    required this.reports,
    required this.isLoading,
    required this.onRetry,
    required this.onDelete,
    required this.onReviewVideo,
    required this.onOpenReport,
  });

  final List<UploadedVideo> videos;
  final List<ReportRecord> reports;
  final bool isLoading;
  final ValueChanged<UploadedVideo> onRetry;
  final ValueChanged<UploadedVideo> onDelete;
  final ValueChanged<UploadedVideo> onReviewVideo;
  final void Function(UploadedVideo video, ReportRecord report) onOpenReport;

  @override
  State<InferenceRunLogs> createState() => _InferenceRunLogsState();
}

class _InferenceRunLogsState extends State<InferenceRunLogs> {
  final Set<int> _expanded = {};

  ReportRecord? _matchedReport(UploadedVideo v) {
    for (final r in widget.reports) {
      if (r.reportName.contains('Video_${v.id}') || r.reportName.contains(v.filename)) {
        return r;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.brain, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Inference Run Logs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${widget.videos.length} processed video runs',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Syncing video runs databases...',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ),
            )
          else if (widget.videos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No processed video runs present in records.',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ),
            )
          else
            for (final v in widget.videos) _card(v),
        ],
      ),
    );
  }

  Widget _card(UploadedVideo v) {
    final details = videoDetailsFor(v);
    final statusLower = v.processingStatus.toLowerCase();
    final (accent, accentLight) = _themeColors(statusLower);
    final isExpanded = _expanded.contains(v.id);
    final matchedReport = _matchedReport(v);

    // A `Border` with per-side colors can't be combined with `borderRadius`
    // in a single BoxDecoration, so the colored left accent is drawn as a
    // `Positioned` strip in a `Stack` instead of a border side (same
    // underlying fix as the Analytics KPI grid's top accent, but a Stack
    // rather than a stretched Row here since this card's height is
    // intrinsic/unbounded -- a Row with CrossAxisAlignment.stretch would
    // otherwise throw "BoxConstraints forces an infinite height").
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: accent),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _cardBody(
                  v,
                  details,
                  statusLower,
                  accent,
                  accentLight,
                  isExpanded,
                  matchedReport,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardBody(
    UploadedVideo v,
    VideoDetails details,
    String statusLower,
    Color accent,
    Color accentLight,
    bool isExpanded,
    ReportRecord? matchedReport,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (!_expanded.remove(v.id)) _expanded.add(v.id);
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.video, size: 16, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.filename,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Pipeline: ${details.pipelineId} • Model: ${details.model}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _metaPill('⌛ ${details.duration}'),
                      _metaPill('🎯 ${details.confidence}'),
                      _metaPill('🚨 ${details.detectionCount} Distresses'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentLight,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    v.processingStatus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _details(v, details, statusLower, matchedReport),
      ],
    );
  }

  Widget _metaPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }

  Widget _details(
    UploadedVideo v,
    VideoDetails details,
    String statusLower,
    ReportRecord? matchedReport,
  ) {
    final steps = [
      ('Video Uploaded', 'Source file validated', true),
      ('Frames Parsed', 'FPS extracted & buffered', true),
      ('YOLO Detections', 'Distress bounding boxes', statusLower != 'pending'),
      ('GIS Catalogued', 'Lat/Long geo-stamped', statusLower == 'completed'),
      (
        'Summary Exported',
        'Audit report archived',
        statusLower == 'completed' && matchedReport != null,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final s in steps)
                SizedBox(
                  width: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.$3
                              ? AppColors.successLight
                              : AppColors.primaryBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.$3
                                ? AppColors.success
                                : AppColors.cardBorder,
                          ),
                        ),
                        child: Text(
                          s.$3 ? '✓' : '',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.$1,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              s.$2,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _metaField('District Jurisdiction', details.district),
              _metaField('Road Identification', details.road),
              _metaField('Model Target Version', details.modelVersion),
              _metaField(
                'Registered Upload Time',
                formatDateTimeIN(v.uploadTimestamp),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _expanded.remove(v.id)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryText,
                  side: BorderSide(color: AppColors.cardBorder),
                ),
                child: const Text(
                  'Close Details',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (matchedReport != null)
                    ElevatedButton.icon(
                      onPressed: () => widget.onOpenReport(v, matchedReport),
                      icon: const Icon(LucideIcons.download, size: 13),
                      label: const Text(
                        'Open Report',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () => widget.onReviewVideo(v),
                    icon: const Icon(LucideIcons.video, size: 13),
                    label: const Text(
                      'Review Video',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => widget.onRetry(v),
                    icon: const Icon(LucideIcons.refreshCw, size: 13),
                    label: const Text(
                      'Retry Pipeline',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryText,
                      side: BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => widget.onDelete(v),
                    icon: const Icon(
                      LucideIcons.trash2,
                      size: 13,
                      color: AppColors.danger,
                    ),
                    label: const Text(
                      'Delete Video Run',
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaField(String label, String value) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.secondaryText),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
