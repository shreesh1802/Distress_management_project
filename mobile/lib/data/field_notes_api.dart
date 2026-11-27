import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'custom_http_client.dart';
import 'live_detection_api.dart' show kApiBaseUrl, kApiV1;
import '../utils/local_time.dart';

/// A snapshot and / or voice note the surveyor added by hand during a live session, for something the
/// camera detection missed. It belongs to the session's report.
class FieldNote {
  const FieldNote({
    required this.id,
    required this.videoId,
    required this.createdAt,
    required this.note,
    required this.hasImage,
    required this.hasAudio,
    required this.audioDurationSeconds,
    required this.transcript,
    required this.transcriptStatus,
    required this.imageUrl,
    required this.audioUrl,
  });

  final int id;
  final int videoId;
  final DateTime? createdAt;
  final String? note;
  final bool hasImage;
  final bool hasAudio;
  final double? audioDurationSeconds;
  final String? transcript;
  final String transcriptStatus;

  /// Full address of the picture / recording (a short-lived signed link, so an image widget or an
  /// audio player can open it without sending a token). Null when the note has none.
  final String? imageUrl;
  final String? audioUrl;

  factory FieldNote.fromJson(Map<String, dynamic> json) {
    String? absolute(Object? path) => path is String && path.isNotEmpty ? '$kApiBaseUrl$path' : null;
    return FieldNote(
      id: (json['id'] as num).toInt(),
      videoId: (json['video_id'] as num).toInt(),
      createdAt: parseServerTime(json['created_at']?.toString()),
      note: json['note'] as String?,
      hasImage: json['has_image'] == true,
      hasAudio: json['has_audio'] == true,
      audioDurationSeconds: (json['audio_duration_seconds'] as num?)?.toDouble(),
      transcript: json['transcript'] as String?,
      transcriptStatus: (json['transcript_status'] as String?) ?? 'none',
      imageUrl: absolute(json['image_url']),
      audioUrl: absolute(json['audio_url']),
    );
  }
}

class FieldNotesException implements Exception {
  const FieldNotesException(this.message);
  final String message;

  @override
  String toString() => message;
}

class FieldNotesApi {
  FieldNotesApi();

  final http.Client _client = CustomHttpClient();

  /// Adds a note to the live session that is running now. [snapshot] saves the newest camera picture
  /// (taken by the server, so it is exactly what the detector saw); [audio] is a voice recording;
  /// [note] is an optional typed caption. At least one of the three is required.
  Future<FieldNote> addToLiveSession({
    bool snapshot = false,
    Uint8List? audio,
    String? audioFilename,
    double? audioSeconds,
    String? note,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$kApiV1/observations/live'));
    request.fields['snapshot'] = snapshot ? 'true' : 'false';
    if (note != null && note.trim().isNotEmpty) request.fields['note'] = note.trim();
    if (audioSeconds != null) request.fields['audio_duration_seconds'] = audioSeconds.toStringAsFixed(1);
    if (audio != null) {
      request.files.add(http.MultipartFile.fromBytes('file', audio, filename: audioFilename ?? 'voice_note.m4a'));
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      throw const FieldNotesException('Could not reach the server. Check your connection and try again.');
    }
    if (response.statusCode != 201) throw FieldNotesException(_detail(response, 'Could not save the note.'));
    return FieldNote.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<FieldNote>> list(int videoId) async {
    final response = await _client.get(Uri.parse('$kApiV1/observations?video_id=$videoId'));
    if (response.statusCode != 200) throw FieldNotesException(_detail(response, 'Could not load the notes.'));
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((e) => FieldNote.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> delete(int id) async {
    final response = await _client.delete(Uri.parse('$kApiV1/observations/$id'));
    if (response.statusCode != 204) throw FieldNotesException(_detail(response, 'Could not delete the note.'));
  }

  void dispose() => _client.close();

  static String _detail(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      final detail = body is Map ? body['detail'] : null;
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // Not JSON: use the generic message.
    }
    return fallback;
  }
}
