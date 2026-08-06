import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Matches the React source's `API_BASE_URL = import.meta.env.VITE_API_URL
/// || 'http://127.0.0.1:8000'` (LiveMonitoringDashboard.tsx). Same idea via
/// Flutter's compile-time --dart-define: defaults to localhost for local
/// dev (`flutter run -d chrome` needs no flag), overridden for a real
/// deployment with:
///   flutter build web --release --dart-define=API_BASE_URL=https://your-domain-or-ip
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');
const String kApiV1 = '$kApiBaseUrl/api/v1';

/// Mirrors the backend's `GET /api/v1/live/status` (and the `status` field
/// pushed over the `/live/ws` WebSocket).
class LiveStatus {
  const LiveStatus({
    required this.running,
    required this.error,
    required this.frames,
    required this.inferences,
    required this.detectionsTotal,
    required this.detectionsRoad,
    required this.detectionsSign,
    required this.criticalAlerts,
    required this.persisted,
    required this.avgConfidence,
    required this.fps,
    required this.inferenceFps,
  });

  final bool running;
  final String? error;
  final int frames;
  final int inferences;
  final int detectionsTotal;
  final int detectionsRoad;
  final int detectionsSign;
  final int criticalAlerts;
  final int persisted;
  final double avgConfidence;
  final double fps;
  final double? inferenceFps;

  factory LiveStatus.fromJson(Map<String, dynamic> json) {
    return LiveStatus(
      running: json['running'] as bool? ?? false,
      error: json['error'] as String?,
      frames: (json['frames'] as num?)?.toInt() ?? 0,
      inferences: (json['inferences'] as num?)?.toInt() ?? 0,
      detectionsTotal: (json['detections_total'] as num?)?.toInt() ?? 0,
      detectionsRoad: (json['detections_road'] as num?)?.toInt() ?? 0,
      detectionsSign: (json['detections_sign'] as num?)?.toInt() ?? 0,
      criticalAlerts: (json['critical_alerts'] as num?)?.toInt() ?? 0,
      persisted: (json['persisted'] as num?)?.toInt() ?? 0,
      avgConfidence: (json['avg_confidence'] as num?)?.toDouble() ?? 0,
      fps: (json['fps'] as num?)?.toDouble() ?? 0,
      inferenceFps: (json['inference_fps'] as num?)?.toDouble(),
    );
  }
}

/// Mirrors one entry of the `events` array pushed over the WebSocket.
class LiveEvent {
  const LiveEvent({
    required this.seq,
    required this.time,
    required this.className,
    required this.confidence,
    required this.severity,
    required this.modelSource,
    required this.frame,
    required this.latitude,
    required this.longitude,
  });

  final int seq;
  final String time;
  final String className;
  final double confidence;
  final String severity;
  final String modelSource;
  final int frame;
  final double latitude;
  final double longitude;

  factory LiveEvent.fromJson(Map<String, dynamic> json) {
    return LiveEvent(
      seq: (json['seq'] as num).toInt(),
      time: json['time'] as String,
      className: json['class_name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      severity: json['severity'] as String,
      modelSource: json['model_source'] as String,
      frame: (json['frame'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

/// Thrown when `/live/start` responds with a non-2xx status; carries the
/// backend's `detail` message (e.g. "YOLOX models not found").
class LiveDetectionException implements Exception {
  const LiveDetectionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Direct port of the fetch/WebSocket calls in LiveMonitoringDashboard.tsx.
/// Deliberately bypasses the app's Riverpod/dio setup, same as the React
/// source bypasses `apiService.ts` for this one feature.
class LiveDetectionApi {
  LiveDetectionApi();

  final http.Client _client = http.Client();

  Future<void> start({required int cameraIndex}) async {
    final response = await _client.post(
      Uri.parse('$kApiV1/live/start'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'camera_index': cameraIndex}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = 'Failed to start';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        detail = body['detail']?.toString() ?? detail;
      } catch (_) {
        // Non-JSON error body; fall back to the generic message.
      }
      throw LiveDetectionException(detail);
    }
  }

  Future<void> stop() async {
    try {
      await _client.post(Uri.parse('$kApiV1/live/stop'));
    } catch (_) {
      // Matches the React source's fire-and-forget `catch { /* noop */ }`.
    }
  }

  /// Returns null on any failure (offline backend, network error, etc.) —
  /// matches the React source's silent `catch (e) { /* ignore offline */ }`.
  Future<LiveStatus?> fetchStatus() async {
    try {
      final response = await _client.get(Uri.parse('$kApiV1/live/status'));
      if (response.statusCode == 200) {
        return LiveStatus.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Offline/unreachable backend.
    }
    return null;
  }

  String streamUrlFor(int streamKey) => '$kApiV1/live/stream?k=$streamKey';

  WebSocketChannel connectWs() {
    final wsBase = kApiBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return WebSocketChannel.connect(Uri.parse('$wsBase/api/v1/live/ws'));
  }

  void dispose() => _client.close();
}
