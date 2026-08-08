import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

Future<void> triggerReportDownload(String url, String filename) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final bytes = response.bodyBytes;
      final blob = web.Blob([bytes.toJS].toJS);
      final blobUrl = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = blobUrl;
      anchor.download = filename;
      anchor.click();
      web.URL.revokeObjectURL(blobUrl);
      return;
    }
  } catch (_) {}
}
