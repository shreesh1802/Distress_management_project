import 'dart:io';

void configureHttpOverrides() {
  HttpOverrides.global = _GlobalHttpOverrides();
}

/// Allows mobile clients to reach temporary tunnel endpoints and ad-hoc
/// demo certificates without failing TLS handshakes.
class _GlobalHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
