import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;

/// Installs the certificate-validation relaxation ONLY in debug builds.
///
/// Release and profile builds never touch [HttpOverrides.global], so every
/// dart:io HTTP client and WebSocket performs normal TLS validation (use a
/// real certificate for the production backend / tunnel host).
void configureHttpOverrides() {
  if (!kDebugMode) return;
  HttpOverrides.global = _DebugHttpOverrides();
}

/// Debug-only: lets a developer reach temporary tunnel endpoints and ad-hoc
/// self-signed demo certificates without failing TLS handshakes.
class _DebugHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // `kDebugMode` is a compile-time constant that is false in release
      // builds, so the callback can never accept a bad certificate there.
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => kDebugMode;
  }
}
