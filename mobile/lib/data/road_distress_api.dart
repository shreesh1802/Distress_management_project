import 'dart:convert';

import 'package:http/http.dart' as http;

import 'live_detection_api.dart' show kApiBaseUrl, kApiV1;

/// Direct Dart port of the raw `RoadDistressResponse` shape (as used by
/// RoadDistresses.tsx, which works with the unmapped API record directly --
/// unlike GISMap.tsx, which maps it into a `RoadDistress` with synthetic
/// state/district/roadName fields).
class DistressRecord {
  const DistressRecord({
    required this.id,
    required this.distressType,
    required this.severity,
    required this.confidenceScore,
    required this.latitude,
    required this.longitude,
    required this.detectedAt,
    required this.status,
    this.imageUrl,
    this.videoId,
    this.frameNumber,
    this.videoTimestamp,
    this.trackingId,
    this.boxWidth,
    this.boxHeight,
    this.affectedArea,
    this.detectionImagePath,
  });

  final int id;
  final String distressType;
  final String severity;
  final double confidenceScore;
  final double latitude;
  final double longitude;
  final DateTime detectedAt;
  final String status;
  final String? imageUrl;
  final int? videoId;
  final int? frameNumber;
  final double? videoTimestamp;
  final int? trackingId;
  final int? boxWidth;
  final int? boxHeight;
  final double? affectedArea;
  final String? detectionImagePath;

  factory DistressRecord.fromJson(Map<String, dynamic> json) {
    return DistressRecord(
      id: json['id'] as int,
      distressType: json['distress_type'] as String? ?? 'unknown',
      severity: ((json['severity'] as String?) ?? 'low').toLowerCase(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      detectedAt: DateTime.tryParse(json['detected_at'] as String? ?? '') ?? DateTime.now(),
      status: (json['status'] as String?) ?? 'detected',
      imageUrl: json['image_url'] as String?,
      videoId: (json['video_id'] as num?)?.toInt(),
      frameNumber: (json['frame_number'] as num?)?.toInt(),
      videoTimestamp: (json['video_timestamp'] as num?)?.toDouble(),
      trackingId: (json['tracking_id'] as num?)?.toInt(),
      boxWidth: (json['box_width'] as num?)?.toInt(),
      boxHeight: (json['box_height'] as num?)?.toInt(),
      affectedArea: (json['affected_area'] as num?)?.toDouble(),
      detectionImagePath: json['detection_image_path'] as String?,
    );
  }

  /// Matches PopupCard.tsx/RoadDistresses.tsx's
  /// `image_url.startsWith('http') ? image_url : \`${API_BASE_URL}/${image_url}\``.
  String? get resolvedImageUrl {
    final url = imageUrl;
    if (url == null || url.isEmpty) return null;
    return url.startsWith('http') ? url : '$kApiBaseUrl/$url';
  }
}

class RoadDistressApiException implements Exception {
  const RoadDistressApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Direct port of the `getDistressLogs`/`generatePDFReport` calls in
/// apiService.ts as used by RoadDistresses.tsx.
class RoadDistressApi {
  RoadDistressApi();

  final http.Client _client = http.Client();

  Future<List<DistressRecord>> fetchDistresses({int skip = 0, int limit = 500}) async {
    final uri = Uri.parse(
      '$kApiV1/distress/',
    ).replace(queryParameters: {'skip': '$skip', 'limit': '$limit'});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw const RoadDistressApiException(
        'Failed to sync distress logs database. Make sure backend service is active.',
      );
    }
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((e) => DistressRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> generatePdfReport(int id) async {
    final response = await _client.post(Uri.parse('$kApiV1/reports/generate/$id'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const RoadDistressApiException('Failed to generate report');
    }
  }

  void dispose() => _client.close();
}
