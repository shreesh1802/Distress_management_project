import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

const _pdfMime = 'application/pdf';
const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

class ReportShareException implements Exception {
  const ReportShareException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A file name that is safe on every platform and in every chat app: letters, digits, `.`, `_`, `-`.
String reportFileName(String base, {required bool excel}) {
  var name = base.trim().replaceAll(RegExp(r'\.(pdf|xlsx)$', caseSensitive: false), '');
  name = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').replaceAll(RegExp(r'_+'), '_');
  name = name.replaceAll(RegExp(r'^[_.]+|[_.]+$'), '');
  if (name.isEmpty) name = 'Road_Inspection_Report';
  return '$name.${excel ? 'xlsx' : 'pdf'}';
}

/// Fetches the report from [url] (the short-lived signed link from `ReportsApi.signedUrl`, valid ~5 minutes,
/// so call this right after getting it) and opens the system share sheet with the file attached, so the user can
/// send it through any installed app that accepts documents (WhatsApp, Telegram, Gmail, Drive, ...).
///
/// On the web the browser's own share dialog is used where it exists, otherwise the file is downloaded.
Future<void> shareReportFromUrl({
  required String url,
  required String filename,
  required bool excel,
}) async {
  final http.Response response;
  try {
    response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
  } catch (_) {
    throw const ReportShareException('Could not reach the server. Check your connection and try again.');
  }
  if (response.statusCode < 200 || response.statusCode >= 300 || response.bodyBytes.isEmpty) {
    throw const ReportShareException('Could not prepare the report for sharing. Please try again.');
  }

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(response.bodyBytes, mimeType: excel ? _xlsxMime : _pdfMime, name: filename)],
      fileNameOverrides: [filename],
      subject: 'Road Inspection report',
      text: 'Road Inspection report: $filename',
      downloadFallbackEnabled: true,
    ),
  );
}
