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

  void dispose() => _client.close();
}
