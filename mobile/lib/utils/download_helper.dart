import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

/// Cross-platform download handler for PDF and Excel reports.
/// On web (desktop & mobile browsers), fetches the binary file bytes and uses
/// an in-memory Blob + HTML <a> click element to trigger direct native OS file save.
/// On native platforms, invokes external application URL handler.
Future<void> triggerReportDownload(String url, String filename) async {
  if (kIsWeb) {
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
    } catch (_) {
      // Fall back to direct url_launcher open if http fetch fails
    }
  }

  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
