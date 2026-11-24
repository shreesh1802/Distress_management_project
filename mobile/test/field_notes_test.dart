import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/field_notes_api.dart';
import 'package:mobile/data/live_detection_api.dart' show kApiBaseUrl;

void main() {
  test('a note with a snapshot and a voice note is read from the server answer', () {
    final note = FieldNote.fromJson({
      'id': 7,
      'video_id': 3,
      'created_at': '2026-11-24T09:15:30Z',
      'note': 'Edge failure',
      'has_image': true,
      'has_audio': true,
      'audio_duration_seconds': 12.4,
      'transcript': 'pothole near the culvert',
      'transcript_status': 'done',
      'image_url': '/api/v1/observations/7/image?t=1.abc',
      'audio_url': '/api/v1/observations/7/audio?t=1.def',
    });
    expect(note.id, 7);
    expect(note.videoId, 3);
    expect(note.hasImage && note.hasAudio, isTrue);
    expect(note.audioDurationSeconds, 12.4);
    expect(note.transcript, 'pothole near the culvert');
    // The picture and sound are opened from absolute addresses on the configured server.
    expect(note.imageUrl, '$kApiBaseUrl/api/v1/observations/7/image?t=1.abc');
    expect(note.audioUrl, '$kApiBaseUrl/api/v1/observations/7/audio?t=1.def');
    expect(note.createdAt, isNotNull);
  });

  test('a text-only note has no picture or sound links', () {
    final note = FieldNote.fromJson({
      'id': 1,
      'video_id': 1,
      'note': 'Only a caption',
      'has_image': false,
      'has_audio': false,
    });
    expect(note.imageUrl, isNull);
    expect(note.audioUrl, isNull);
    expect(note.transcriptStatus, 'none');
    expect(note.createdAt, isNull);
  });
}
