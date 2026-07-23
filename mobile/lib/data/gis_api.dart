import 'dart:convert';

import 'package:http/http.dart' as http;

import 'live_detection_api.dart' show kApiBaseUrl, kApiV1;

/// Direct Dart port of `RoadDistress` in
/// Road-Distress-Management-System/frontend/src/types/gis.ts.
class RoadDistress {
  const RoadDistress({
    required this.id,
    required this.roadId,
    required this.roadName,
    required this.location,
    required this.state,
    required this.district,
    required this.distressType,
    required this.severity,
    required this.lastInspectionDate,
    required this.maintenanceStatus,
    required this.latitude,
    required this.longitude,
    required this.reportedDate,
    required this.confidence,
    required this.detectionDate,
    required this.assignedTeam,
    required this.estimatedRepairCost,
    required this.estimatedRepairTime,
    required this.priorityScore,
    this.imageUrl,
    this.videoId,
    this.videoTimestamp,
  });

  final String id;
  final String roadId;
  final String roadName;
  final String location;
  final String state;
  final String district;
  final String distressType;
  final String severity;
  final String lastInspectionDate;
  final String maintenanceStatus;
  final double latitude;
  final double longitude;
  final String reportedDate;
  final int confidence;
  final String detectionDate;
  final String assignedTeam;
  final String estimatedRepairCost;
  final String estimatedRepairTime;
  final int priorityScore;
  final String? imageUrl;
  final int? videoId;
  final double? videoTimestamp;

  /// Mirrors GISMap.tsx's `fetchRealDistresses` mapping from the raw
  /// `RoadDistressResponse` (GET /api/v1/distress/) into the UI-shaped
  /// `RoadDistress` the rest of this screen works with.
  factory RoadDistress.fromApi(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final lat = (json['latitude'] as num).toDouble();
    final lon = (json['longitude'] as num).toDouble();
    final videoId = (json['video_id'] as num?)?.toInt();
    final confidenceScore = (json['confidence_score'] as num?)?.toDouble() ?? 0;
    final confidence = (confidenceScore * 100).round();
    final detectedAt = json['detected_at'] as String?;
    final day = detectedAt != null && detectedAt.isNotEmpty
        ? detectedAt.split('T').first
        : DateTime.now().toIso8601String().split('T').first;
    final status = (json['status'] as String?) ?? 'detected';

    return RoadDistress(
      id: 'DIS-DB-$id',
      roadId: videoId != null ? 'RD-$videoId' : 'RD-DB',
      roadName: videoId != null ? 'Corridor #$videoId' : 'Main Road',
      location:
          'Punjab Sector - Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}',
      state: 'Punjab',
      district: 'Patiala',
      distressType: json['distress_type'] as String? ?? 'unknown',
      severity: ((json['severity'] as String?) ?? 'low').toLowerCase(),
      lastInspectionDate: day,
      maintenanceStatus: status == 'detected' ? 'pending' : status,
      latitude: lat,
      longitude: lon,
      reportedDate: day,
      confidence: confidence > 0 ? confidence : 85,
      detectionDate: day,
      assignedTeam: 'Patiala Main Division Squad',
      estimatedRepairCost: '₹35,000',
      estimatedRepairTime: '6 hours',
      priorityScore: confidence > 0 ? confidence : 85,
      imageUrl: json['image_url'] as String?,
      videoId: videoId,
      videoTimestamp: (json['video_timestamp'] as num?)?.toDouble(),
    );
  }

  /// Resolves `imageUrl` against the backend host, matching PopupCard.tsx's
  /// `image_url.startsWith('http') ? image_url : \`${API_BASE_URL}/${image_url}\``.
  String? get resolvedImageUrl {
    final url = imageUrl;
    if (url == null || url.isEmpty) return null;
    return url.startsWith('http') ? url : '$kApiBaseUrl/$url';
  }
}

class GisFiltersState {
  const GisFiltersState({
    this.state = '',
    this.district = '',
    this.distressType = '',
    this.severity = '',
    this.startDate = '',
    this.endDate = '',
  });

  final String state;
  final String district;
  final String distressType;
  final String severity;
  final String startDate;
  final String endDate;

  GisFiltersState copyWith({
    String? state,
    String? district,
    String? distressType,
    String? severity,
    String? startDate,
    String? endDate,
  }) {
    return GisFiltersState(
      state: state ?? this.state,
      district: district ?? this.district,
      distressType: distressType ?? this.distressType,
      severity: severity ?? this.severity,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

/// Mirrors apiService.ts's `getDistressLogs` — a real call against the
/// PostgreSQL-backed `/api/v1/distress/` endpoint (unauthenticated, same as
/// the backend route itself).
class GisApi {
  GisApi();

  final http.Client _client = http.Client();

  Future<List<RoadDistress>> fetchDistressLogs({
    int skip = 0,
    int limit = 100,
  }) async {
    final uri = Uri.parse(
      '$kApiV1/distress/',
    ).replace(queryParameters: {'skip': '$skip', 'limit': '$limit'});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load distress logs (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((e) => RoadDistress.fromApi(e as Map<String, dynamic>))
        .toList();
  }

  void dispose() => _client.close();
}
