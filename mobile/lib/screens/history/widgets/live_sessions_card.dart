import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/field_notes_api.dart';
import '../../../data/live_sessions_api.dart';
import '../../../data/reports_api.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/voice_note_player.dart';
import '../../live_detection/widgets/field_note_tile.dart';
import '../../reports/widgets/pavement_type_selector.dart';
import '../../reports/widgets/report_ready_sheet.dart';
import 'activity_timeline.dart' show formatDateTimeIN;

const _kShownAtFirst = 6;

String _duration(double? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final total = seconds.round();
  if (total < 60) return '${total}s';
  final m = total ~/ 60;
  final s = total % 60;
  return s == 0 ? '${m}m' : '${m}m ${s}s';
}

/// Every past live detection session, with what it found and the snapshots / voice notes added to it,
/// and buttons to open its PDF or Excel report. (Sessions used to appear here only as generic
/// "video uploaded" lines, with no way to open their report.)
class LiveSessionsCard extends StatefulWidget {
  const LiveSessionsCard({super.key});

  @override
  State<LiveSessionsCard> createState() => _LiveSessionsCardState();
}

class _LiveSessionsCardState extends State<LiveSessionsCard> {
  final _api = LiveSessionsApi();
  final _reportsApi = ReportsApi();
  final _notesApi = FieldNotesApi();
  late final VoiceNotePlayer _player = VoiceNotePlayer(
    onFinished: () {
      if (mounted) setState(() => _playingNoteId = null);
    },
  );

  List<LiveSessionSummary> _sessions = [];
  bool _loading = true;
  bool _failed = false;
  bool _showAll = false;
  int? _openSessionId;
  final Map<int, List<FieldNote>> _notes = {};
  final Set<String> _busy = {};
  int? _playingNoteId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    _api.dispose();
    _reportsApi.dispose();
    _notesApi.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final sessions = await _api.fetch();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _generate(LiveSessionSummary session, {required bool excel}) async {
    final key = '${session.id}-${excel ? 'xlsx' : 'pdf'}';
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      final record = excel
          ? await _reportsApi.generateExcelReport(session.id)
          : await _reportsApi.generatePdfReport(session.id);
      if (!mounted) return;
      await showReportReadySheet(
        context,
        api: _reportsApi,
        reportId: record.id,
        excel: excel,
        name: record.reportName,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(excel ? 'Could not build the Excel report.' : 'Could not build the PDF report.')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _toggleNotes(LiveSessionSummary session) async {
    if (_openSessionId == session.id) {
      _player.stop();
      setState(() {
        _openSessionId = null;
        _playingNoteId = null;
      });
      return;
    }
    _player.stop();
    setState(() {
      _openSessionId = session.id;
      _playingNoteId = null;
    });
    if (_notes.containsKey(session.id)) return;
    try {
      final notes = await _notesApi.list(session.id);
      if (!mounted) return;
      setState(() => _notes[session.id] = notes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notes[session.id] = const []);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load the notes.')));
    }
  }

  Future<void> _togglePlay(FieldNote note) async {
    final url = note.audioUrl;
    if (url == null) return;
    if (_playingNoteId == note.id) {
      _player.stop();
      setState(() => _playingNoteId = null);
      return;
    }
    // No `await` before the player starts: browsers only allow sound that starts straight from the tap.
    setState(() => _playingNoteId = note.id);
    try {
      await _player.play(url);
    } on VoicePlaybackException catch (e) {
      if (mounted) setState(() => _playingNoteId = null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _showAll ? _sessions : _sessions.take(_kShownAtFirst).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.radio, size: 18, color: AppColors.accentBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _sessions.isEmpty ? 'Live detection sessions' : 'Live detection sessions (${_sessions.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                tooltip: 'Refresh',
                icon: const Icon(LucideIcons.refreshCw, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Every live detection run, with its report. Open a session to see the snapshots and voice notes '
            'added during it.',
            style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 12),
          const PavementTypeSelector(showHint: false),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Could not load the live sessions.',
                      style: TextStyle(fontSize: 13, color: AppColors.danger),
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            )
          else if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No live detection sessions yet. Start live detection and its sessions will be listed here.',
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            )
          else ...[
            for (final session in visible) _sessionRow(session),
            if (_sessions.length > _kShownAtFirst)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? 'Show fewer' : 'Show all ${_sessions.length} sessions'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, {Color color = AppColors.secondaryText}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _sessionRow(LiveSessionSummary session) {
    final open = _openSessionId == session.id;
    final duration = _duration(session.durationSeconds);
    final pdfBusy = _busy.contains('${session.id}-pdf');
    final xlsxBusy = _busy.contains('${session.id}-xlsx');
    final anyBusy = pdfBusy || xlsxBusy;
    final notes = _notes[session.id];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            session.startedAt == null ? session.name : formatDateTimeIN(session.startedAt!),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (duration.isNotEmpty) _chip(LucideIcons.clock, duration),
              _chip(
                LucideIcons.scanSearch,
                '${session.detectionCount} detection${session.detectionCount == 1 ? '' : 's'}',
              ),
              if (session.seriousCount > 0)
                _chip(LucideIcons.alertTriangle, '${session.seriousCount} serious', color: AppColors.danger),
              if (session.fieldNoteCount > 0)
                _chip(
                  LucideIcons.clipboardList,
                  '${session.fieldNoteCount} field note${session.fieldNoteCount == 1 ? '' : 's'}',
                  color: AppColors.accentBlue,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: anyBusy ? null : () => _generate(session, excel: false),
                icon: pdfBusy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.fileText, size: 15),
                label: const Text('PDF report'),
              ),
              OutlinedButton.icon(
                onPressed: anyBusy ? null : () => _generate(session, excel: true),
                icon: xlsxBusy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.sheet, size: 15),
                label: const Text('Excel report'),
              ),
              if (session.fieldNoteCount > 0)
                TextButton.icon(
                  onPressed: () => _toggleNotes(session),
                  icon: Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 15),
                  label: Text(open ? 'Hide notes' : 'Show notes'),
                ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: 4),
            if (notes == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else
              for (final note in notes)
                FieldNoteTile(note: note, playing: _playingNoteId == note.id, onPlay: () => _togglePlay(note)),
          ],
        ],
      ),
    );
  }
}
