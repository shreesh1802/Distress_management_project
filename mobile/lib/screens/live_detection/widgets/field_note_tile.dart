import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/field_notes_api.dart';
import '../../../theme/app_colors.dart';

String _minutesSeconds(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _timeOfDay(DateTime? t) {
  if (t == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// One field note in a list: the snapshot (or a microphone for a voice note), the time, the typed caption,
/// the words that were spoken, and play / remove buttons. Used on the live screen and in History.
class FieldNoteTile extends StatelessWidget {
  const FieldNoteTile({
    super.key,
    required this.note,
    required this.playing,
    required this.onPlay,
    this.onDelete,
  });

  final FieldNote note;
  final bool playing;
  final VoidCallback onPlay;

  /// Null hides the remove button (a read-only list).
  final VoidCallback? onDelete;

  String get _voiceLine {
    final transcript = note.transcript;
    if (transcript != null && transcript.trim().isNotEmpty) return transcript.trim();
    if (note.transcriptStatus == 'pending') return 'Writing out what was said...';
    return 'Voice note recorded';
  }

  @override
  Widget build(BuildContext context) {
    final length = note.audioDurationSeconds;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                note.imageUrl!,
                width: 84,
                height: 62,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 84,
                  height: 62,
                  color: AppColors.primaryBg,
                  child: const Icon(LucideIcons.imageOff, size: 18, color: AppColors.secondaryText),
                ),
              ),
            )
          else
            Container(
              width: 84,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.mic, size: 20, color: AppColors.secondaryText),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _timeOfDay(note.createdAt),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                ),
                if (note.note != null && note.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(note.note!, style: const TextStyle(fontSize: 13, color: AppColors.primaryText)),
                  ),
                if (note.hasAudio)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${length == null ? '' : '(${_minutesSeconds(length.round())}) '}$_voiceLine',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (note.hasAudio)
            IconButton(
              onPressed: onPlay,
              tooltip: playing ? 'Stop playing' : 'Play the voice note',
              icon: Icon(playing ? LucideIcons.square : LucideIcons.play, size: 18),
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Remove this note from the report',
              icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}
