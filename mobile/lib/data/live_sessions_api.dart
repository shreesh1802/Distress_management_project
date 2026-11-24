import 'dart:convert';

import 'package:http/http.dart' as http;

import 'custom_http_client.dart';
import 'live_detection_api.dart' show kApiV1;

/// One past live detection session: what it found and how many notes were added to it.
/// [id] is also the id of the session's report (generate it with `ReportsApi`).
class LiveSessionSummary {
  const LiveSessionSummary({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.durationSeconds,
    required this.detectionCount,
    required this.seriousCount,
    required this.fieldNoteCount,
  });

  final int id;
  final String name;
  final DateTime? startedAt;
  final double? durationSeconds;
  final int detectionCount;
  final int seriousCount;
  final int fieldNoteCount;

  factory LiveSessionSummary.fromJson(Map<String, dynamic> json) {
    return LiveSessionSummary(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? 'Live session',
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? '')?.toLocal(),
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      detectionCount: (json['detection_count'] as num?)?.toInt() ?? 0,
      seriousCount: (json['serious_count'] as num?)?.toInt() ?? 0,
      fieldNoteCount: (json['field_note_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class LiveSessionsApi {
  LiveSessionsApi();

  final http.Client _client = CustomHttpClient();

  /// Past live sessions, newest first.
  Future<List<LiveSessionSummary>> fetch({int limit = 50}) async {
    final response = await _client.get(Uri.parse('$kApiV1/live/sessions?limit=$limit'));
    if (response.statusCode != 200) {
      throw Exception('Could not load the live sessions.');
    }
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((e) => LiveSessionSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  void dispose() => _client.close();
}
