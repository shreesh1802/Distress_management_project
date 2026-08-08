import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Global HttpOverrides to allow localtunnel / custom backend SSL certs on Android/iOS
class GlobalHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

/// Custom HTTP Client that automatically injects 'Bypass-Tunnel-Reminder: true'
/// into every HTTP request so localtunnel never returns HTML reminder pages.
class CustomHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Bypass-Tunnel-Reminder'] = 'true';
    request.headers['User-Agent'] = 'RoadDistressMobileApp/1.0';
    return _inner.send(request);
  }
}
