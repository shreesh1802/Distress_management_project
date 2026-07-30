import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'live_detection_api.dart' show kApiV1;

/// Direct Dart port of `UploadedVideoResponse` in apiService.ts.
class UploadedVideo {
  const UploadedVideo({
    required this.id,
    required this.filename,
    required this.processingStatus,
    required this.uploadTimestamp,
    this.filepath,
    this.processedFilepath,
    this.progress,
    this.processingStage,
  });

  final int id;
  final String filename;
  final String processingStatus;
  final DateTime uploadTimestamp;
  final String? filepath;
  final String? processedFilepath;
  final int? progress;
  final String? processingStage;

  factory UploadedVideo.fromJson(Map<String, dynamic> json) {
    return UploadedVideo(
      id: json['id'] as int,
      filename: json['filename'] as String,
      processingStatus: json['processing_status'] as String? ?? 'queued',
      uploadTimestamp: DateTime.tryParse(json['upload_timestamp'] as String? ?? '') ??
          DateTime.now(),
      filepath: json['filepath'] as String?,
      processedFilepath: json['processed_filepath'] as String?,
      progress: (json['progress'] as num?)?.toInt(),
      processingStage: json['processing_stage'] as String?,
    );
  }

  UploadedVideo copyWith({String? processingStatus}) {
    return UploadedVideo(
      id: id,
      filename: filename,
      processingStatus: processingStatus ?? this.processingStatus,
      uploadTimestamp: uploadTimestamp,
      filepath: filepath,
      processedFilepath: processedFilepath,
      progress: progress,
      processingStage: processingStage,
    );
  }
}

/// Mirrors the fields of `GET /api/v1/detection/summary` this app actually
/// reads (`total_detections`, `road_health_score`); the endpoint returns a
/// larger analytics payload, but the rest isn't used by this screen.
class DetectionSummary {
  const DetectionSummary({required this.totalDetections, required this.roadHealthScore});

  final int totalDetections;
  final double roadHealthScore;

  factory DetectionSummary.fromJson(Map<String, dynamic> json) {
    return DetectionSummary(
      totalDetections: (json['total_detections'] as num?)?.toInt() ?? 0,
      roadHealthScore: (json['road_health_score'] as num?)?.toDouble() ?? 100.0,
    );
  }

  static const fallback = DetectionSummary(totalDetections: 0, roadHealthScore: 100.0);
}

class VideoApiException implements Exception {
  const VideoApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Direct port of the `/videos`-related calls in apiService.ts.
class VideoApi {
  VideoApi();

  final http.Client _client = http.Client();

  Future<List<UploadedVideo>> fetchVideos({int skip = 0, int limit = 100}) async {
    final uri = Uri.parse(
      '$kApiV1/videos/',
    ).replace(queryParameters: {'skip': '$skip', 'limit': '$limit'});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw const VideoApiException('Failed to fetch upload registry.');
    }
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((e) => UploadedVideo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UploadedVideo> uploadVideo(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$kApiV1/videos/upload'))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = 'Video upload failed. Verify backend services.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        detail = body['detail']?.toString() ?? detail;
      } catch (_) {
        // Non-JSON error body; fall back to the generic message.
      }
      throw VideoApiException(detail);
    }
    return UploadedVideo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteVideo(int id) async {
    final response = await _client.delete(Uri.parse('$kApiV1/videos/$id'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const VideoApiException('Failed to delete video.');
    }
  }

  Future<void> generatePdfReport(int videoId) async {
    final response = await _client.post(Uri.parse('$kApiV1/reports/generate/$videoId'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const VideoApiException('Failed to export PDF report.');
    }
  }

  /// Matches apiService's `getDetectionSummary().catch(() => ({...fallback}))`
  /// — returns the fallback on any failure rather than throwing.
  Future<DetectionSummary> fetchDetectionSummary() async {
    try {
      final response = await _client.get(Uri.parse('$kApiV1/detection/summary'));
      if (response.statusCode != 200) return DetectionSummary.fallback;
      return DetectionSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return DetectionSummary.fallback;
    }
  }

  /// Matches apiService's `getReports().catch(() => [])` — just the count is
  /// needed here, so the full report list isn't modeled.
  Future<int> fetchReportsCount() async {
    try {
      return await fetchReportsCountStrict();
    } catch (_) {
      return 0;
    }
  }

  /// Like [fetchReportsCount], but throws instead of swallowing errors --
  /// used by DashboardGrid.tsx's port, which calls `getReports` directly
  /// inside a `Promise.all` with no per-call `.catch`, so a failure there
  /// should surface via the same error banner as the rest of the dashboard.
  Future<int> fetchReportsCountStrict({int skip = 0, int limit = 100}) async {
    final uri = Uri.parse(
      '$kApiV1/reports/',
    ).replace(queryParameters: {'skip': '$skip', 'limit': '$limit'});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw const VideoApiException('Failed to fetch reports.');
    }
    return (jsonDecode(response.body) as List<dynamic>).length;
  }

  Future<void> triggerDetection(int videoId) async {
    final response = await _client.post(Uri.parse('$kApiV1/detection/video/$videoId'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = 'Failed to trigger processing';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        detail = body['detail']?.toString() ?? detail;
      } catch (_) {
        // Non-JSON error body; fall back to the generic message.
      }
      throw VideoApiException(detail);
    }
  }

  void dispose() => _client.close();
}
