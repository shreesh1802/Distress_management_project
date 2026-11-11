import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/reports_api.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/download_helper.dart';
import '../../../utils/report_share.dart';

const _kNoShareMessage = "This browser can't share files, so the report was downloaded instead.";

/// Shares an existing report through the system share sheet. Failures are shown as a snackbar.
Future<void> shareReport(
  BuildContext context,
  ReportsApi api, {
  required int reportId,
  required bool excel,
  required String name,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final url = await api.signedUrl(reportId, excel ? 'excel' : 'pdf');
    final shared = await shareReportFromUrl(url: url, filename: reportFileName(name, excel: excel), excel: excel);
    if (!shared) {
      messenger.showSnackBar(const SnackBar(content: Text(_kNoShareMessage)));
    }
  } on ReportsApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on ReportShareException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not share the report. Please try again.')));
  }
}

/// Shown right after a PDF / Excel report has been generated: lets the user share it (WhatsApp, Telegram, Gmail,
/// Drive, ... whatever accepts a document) or download it.
Future<void> showReportReadySheet(
  BuildContext context, {
  required ReportsApi api,
  required int reportId,
  required bool excel,
  required String name,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ReportReadySheet(api: api, reportId: reportId, excel: excel, name: name),
  );
}

class _ReportReadySheet extends StatefulWidget {
  const _ReportReadySheet({required this.api, required this.reportId, required this.excel, required this.name});

  final ReportsApi api;
  final int reportId;
  final bool excel;
  final String name;

  @override
  State<_ReportReadySheet> createState() => _ReportReadySheetState();
}

enum _Action { share, download }

class _ReportReadySheetState extends State<_ReportReadySheet> {
  _Action? _busy;
  String? _error;
  String? _note;

  String get _filename => reportFileName(widget.name, excel: widget.excel);

  Future<void> _run(_Action action) async {
    setState(() {
      _busy = action;
      _error = null;
      _note = null;
    });
    try {
      final url = await widget.api.signedUrl(widget.reportId, widget.excel ? 'excel' : 'pdf');
      if (action == _Action.share) {
        final shared = await shareReportFromUrl(url: url, filename: _filename, excel: widget.excel);
        if (!shared) _note = _kNoShareMessage;
      } else {
        await triggerReportDownload(url, _filename);
      }
    } on ReportsApiException catch (e) {
      _error = e.message;
    } on ReportShareException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = action == _Action.share ? 'Could not share the report.' : 'Could not download the report.';
    }
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.circleCheck, color: AppColors.success, size: 22),
                const SizedBox(width: 10),
                Text(
                  widget.excel ? 'Excel report ready' : 'PDF report ready',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_filename, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: busy ? null : () => _run(_Action.share),
              icon: _busy == _Action.share
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.share2, size: 18),
              label: const Text('Share (WhatsApp, Telegram, Gmail, Drive...)'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _run(_Action.download),
              icon: _busy == _Action.download
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.download, size: 18),
              label: const Text('Download'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            if (_note != null) ...[
              const SizedBox(height: 12),
              Text(_note!, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
            ],
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
