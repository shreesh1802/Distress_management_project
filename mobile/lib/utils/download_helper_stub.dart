import 'package:url_launcher/url_launcher.dart';

Future<void> triggerReportDownload(String url, String filename) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
