import '../../data/reports_api.dart';
import '../../data/video_api.dart';

const _kReportUsers = ['Admin John', 'Supervisor Sarah', 'Engineer Prasad', 'Inspector Anita'];

/// Direct port of History.tsx's `getReportUser` -- a deterministic-fake
/// engineer name derived from the report's real DB id, same reasoning as
/// Reports.tsx's district/severity derivation.
String reportUserFor(int id) => _kReportUsers[id % _kReportUsers.length];

/// Direct port of History.tsx's `getReportSize`.
String reportSizeFor(int id) => '${((id * 142) % 350 + 80) / 10} MB';

const _kVideoDistricts = ['Mumbai', 'Pune', 'Nagpur', 'Thane', 'Satara'];
const _kVideoRoads = ['NH-48', 'SH-4', 'Western Express Highway', 'Eastern Freeway', 'Pune-Solapur Road'];
const _kVideoModels = ['YOLOv8-Heavy (v1.3.1)', 'YOLOv8-Base (v1.2.0)', 'YOLOv9-Beta (v2.0.0)'];
const _kVideoDurations = ['45s', '1m 12s', '32s', '2m 15s', '55s'];
const _kVideoConfidences = [94.2, 88.5, 91.8, 95.1, 86.4];
const _kVideoDetectionCounts = [34, 12, 27, 45, 8];

/// Direct port of History.tsx's `getVideoDetails` -- deterministic-fake
/// pipeline metadata derived from the video's real DB id.
class VideoDetails {
  const VideoDetails({
    required this.pipelineId,
    required this.model,
    required this.duration,
    required this.confidence,
    required this.detectionCount,
    required this.district,
    required this.road,
    required this.modelVersion,
    required this.user,
  });

  final String pipelineId;
  final String model;
  final String duration;
  final String confidence;
  final int detectionCount;
  final String district;
  final String road;
  final String modelVersion;
  final String user;
}

VideoDetails videoDetailsFor(UploadedVideo v) {
  final idx = v.id;
  return VideoDetails(
    pipelineId: 'PL-YOLOv8-${1000 + idx}',
    model: _kVideoModels[idx % _kVideoModels.length],
    duration: _kVideoDurations[idx % _kVideoDurations.length],
    confidence: '${_kVideoConfidences[idx % _kVideoConfidences.length]}%',
    detectionCount: _kVideoDetectionCounts[idx % _kVideoDetectionCounts.length],
    district: _kVideoDistricts[idx % _kVideoDistricts.length],
    road: _kVideoRoads[idx % _kVideoRoads.length],
    modelVersion: 'v${1 + idx % 2}.${2 + idx % 3}.${idx % 5}',
    user: idx % 3 == 0 ? 'Admin John' : (idx % 3 == 1 ? 'Supervisor Sarah' : 'Inspector Anita'),
  );
}

/// Direct Dart port of History.tsx's `TimelineEvent`. Only 3 of the
/// source's 6 categories (`Reports`, `Inference`, `Uploads`) are ever
/// reachable in this port -- see [buildTimeline]'s doc comment for why
/// `Maintenance`/`GIS`/`Notifications` are dropped.
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.status,
    required this.user,
    this.reportId,
    this.videoId,
    this.reportType,
    this.size,
    this.district,
    this.road,
    this.modelVersion,
  });

  final String id;
  final String type;
  final String category;
  final String title;
  final String description;
  final DateTime timestamp;
  final String status;
  final String user;
  final int? reportId;
  final int? videoId;
  final String? reportType;
  final String? size;
  final String? district;
  final String? road;
  final String? modelVersion;
}

/// Direct port of History.tsx's `allActivities` useMemo, minus the 8
/// hardcoded "system events" (`sys-1` through `sys-8`: "Backend Server
/// Restarted", "YOLOv8 Model Loaded", "Database Auto-Backup", "Secured
/// Admin Login", "Maintenance Task Raised", "Road Segment Verified",
/// "Detection Record Purged", "Alert Notification Broadcasted") the source
/// seeds in "to make timeline enterprise-grade" per its own code comment --
/// they're 100% fabricated strings with no backend tie at all, only a
/// computed-but-arbitrary relative timestamp offset. Dropping them also
/// makes the source's `Maintenance`/`GIS`/`Notifications` categories (and
/// the "System Events Log" section that filters specifically for these
/// seeded events) permanently unreachable, so those were dropped too --
/// see history_screen.dart's doc comment.
List<TimelineEvent> buildTimeline(List<ReportRecord> reports, List<UploadedVideo> videos) {
  final items = <TimelineEvent>[];

  for (final rep in reports) {
    items.add(TimelineEvent(
      id: 'report-${rep.id}',
      type: 'Report Exported',
      category: 'Reports',
      title: 'Report Exported',
      description: 'Exported summary list "${rep.reportName}" in ${rep.reportType} format.',
      timestamp: DateTime.tryParse(rep.generatedAt ?? rep.createdAt) ?? DateTime.now(),
      status: 'Success',
      user: reportUserFor(rep.id),
      reportId: rep.id,
      reportType: rep.reportType,
      size: reportSizeFor(rep.id),
    ));
  }

  for (final vid in videos) {
    final details = videoDetailsFor(vid);
    final statusLower = vid.processingStatus.toLowerCase();
    final isFailed = statusLower == 'failed';
    final isProcessing = statusLower == 'processing';
    final isPending = statusLower == 'pending';

    items.add(TimelineEvent(
      id: 'upload-${vid.id}',
      type: 'Video Uploaded',
      category: 'Uploads',
      title: 'Video Uploaded',
      description: 'Footage file "${vid.filename}" was successfully uploaded for processing.',
      timestamp: vid.uploadTimestamp,
      status: 'Success',
      user: details.user,
      videoId: vid.id,
      district: details.district,
      road: details.road,
    ));

    items.add(TimelineEvent(
      id: 'inference-${vid.id}',
      // `type` only distinguishes Failed/Completed (it drives the icon
      // lookup and the "Top Event Types" chart grouping); `title` carries
      // the finer Running/Pending distinction, exactly matching the
      // source's own type/title split.
      type: isFailed ? 'AI Inference Failed' : 'AI Inference Completed',
      category: 'Inference',
      title: isFailed
          ? 'AI Inference Failed'
          : (isProcessing ? 'AI Inference Running' : (isPending ? 'AI Inference Pending' : 'AI Inference Completed')),
      description: isFailed
          ? 'Pipeline analysis failed for "${vid.filename}" due to frame parsing timeout.'
          : (isProcessing
              ? 'Analyzing video frames and running YOLO detector for "${vid.filename}".'
              : (isPending
                  ? 'Video "${vid.filename}" is placed in the pipeline execution queue.'
                  : 'AI analysis and distress count completed for surveillance video "${vid.filename}".')),
      timestamp: vid.uploadTimestamp,
      status: isFailed ? 'Failed' : (isProcessing ? 'Info' : (isPending ? 'Warning' : 'Success')),
      user: 'System AI',
      videoId: vid.id,
      district: details.district,
      road: details.road,
      modelVersion: details.modelVersion,
    ));
  }

  items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return items;
}
