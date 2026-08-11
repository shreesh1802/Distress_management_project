import 'package:url_launcher/url_launcher.dart';

Future<void> triggerReportDownload(String url, String filename) async {
  final uri = Uri.parse(url);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    throw Exception('No app on this device could open the download link: $url');
  }
}
