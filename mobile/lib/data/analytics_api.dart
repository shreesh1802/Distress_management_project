import 'package:http/http.dart' as http;

import 'live_detection_api.dart' show kApiV1;

class AnalyticsApiException implements Exception {
  const AnalyticsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// AnalyticsDashboard.tsx fetches `GET /api/v1/detection/summary` as part of
/// its `Promise.all` load, but every field it reads off the response
/// (`model_name`, `yolo_version`, `model_size`, `inference_device`,
/// `inference_speed`) is absent from the backend's actual
/// `get_detection_analytics` payload -- so in practice every one of those
/// fields always falls back to the source's own hardcoded defaults. This
/// call still matters for one reason: if it fails, the source's
/// `Promise.all` rejects and the whole page shows the error state. So this
/// client only pings the endpoint and throws on failure; the response body
/// is never parsed since nothing in the port reads it either.
class AnalyticsApi {
  AnalyticsApi();

  final http.Client _client = http.Client();

  Future<void> pingDetectionSummary() async {
    final response = await _client.get(Uri.parse('$kApiV1/detection/summary'));
    if (response.statusCode != 200) {
      throw const AnalyticsApiException('Failed to synchronize executive analytics databases.');
    }
  }

  void dispose() => _client.close();
}
