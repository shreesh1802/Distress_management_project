import 'package:http/http.dart' as http;

import 'live_detection_api.dart' show kApiBaseUrl;

/// Holds the current session's bearer token for the whole app so EVERY API
/// class (they all use [CustomHttpClient]) authenticates the same way, without
/// each screen having to thread a token through its constructors.
///
/// [AuthNotifier] (auth_provider.dart) is the only writer: it sets [value] on
/// login / session restore and clears it on logout or a rejected session.
class SessionToken {
  SessionToken._();

  /// The raw bearer token, or null when nobody is signed in.
  static String? value;

  /// Called when the server answers 401 to a request that carried a bearer
  /// token -- i.e. the session expired or was revoked. AuthNotifier uses it to
  /// sign the user out so the router sends them back to the login screen
  /// instead of showing a cryptic error.
  static void Function()? onUnauthorized;

  /// `Authorization` header for code that cannot go through [CustomHttpClient]
  /// (e.g. `VideoPlayerController.networkUrl(httpHeaders: ...)`). Empty when signed out.
  static Map<String, String> get authHeaders {
    final token = value;
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }
}

/// Custom HTTP Client that automatically injects 'Bypass-Tunnel-Reminder: true'
/// into every HTTP request so localtunnel never returns HTML reminder pages,
/// and attaches `Authorization: Bearer <token>` to every request that goes to
/// the configured backend (never to any other host).
class CustomHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['Bypass-Tunnel-Reminder'] = 'true';
    request.headers['User-Agent'] = 'RoadDistressMobileApp/1.0';

    final token = SessionToken.value;
    if (token != null &&
        !request.headers.containsKey('Authorization') &&
        _isBackendRequest(request.url)) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final response = await _inner.send(request);
    if (response.statusCode == 401 && request.headers.containsKey('Authorization')) {
      SessionToken.onUnauthorized?.call();
    }
    return response;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  /// Only send the token to the backend the app is configured for.
  static bool _isBackendRequest(Uri url) {
    try {
      final base = Uri.parse(kApiBaseUrl);
      return url.scheme == base.scheme && url.host == base.host && url.port == base.port;
    } catch (_) {
      return false;
    }
  }
}
