import 'dart:convert';

import 'package:http/http.dart' as http;

import 'custom_http_client.dart';
import 'live_detection_api.dart' show kApiV1;

/// Matches backend `UserResponse` (app/schemas/user.py).
class SessionUser {
  const SessionUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String email;
  final String? fullName;
  final String role;

  bool get isAdmin => role == 'admin';

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      role: (json['role'] as String?) ?? 'employee',
    );
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to the `/auth/google` and `/auth/me` routes
/// (app/api/v1/routes/auth.py) -- Google sign-in is the only login method.
class AuthApi {
  AuthApi();

  final http.Client _client = CustomHttpClient();

  /// Exchanges a Firebase ID token (from Google sign-in) for our own
  /// bearer session token -- see POST /auth/google.
  Future<(String token, SessionUser user)> googleLogin(String firebaseIdToken) async {
    final response = await _client.post(
      Uri.parse('$kApiV1/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': firebaseIdToken}),
    );
    if (response.statusCode == 403) {
      throw const AuthApiException(
          'No account exists for this Google email. Ask an admin to add you.');
    }
    if (response.statusCode != 200) {
      throw const AuthApiException('Google sign-in failed. Please try again.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token'] as String;
    final user = SessionUser.fromJson(body['user'] as Map<String, dynamic>);
    return (token, user);
  }

  Future<SessionUser?> restoreSession(String token) async {
    final response = await _client.get(
      Uri.parse('$kApiV1/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) return null;
    return SessionUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
