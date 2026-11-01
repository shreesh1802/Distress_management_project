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

/// Talks to the new `/auth/request-otp`, `/auth/verify-otp` and `/auth/me`
/// routes (app/api/v1/routes/auth.py) that replaced the hardcoded mock
/// login check in AuthNotifier.
class AuthApi {
  AuthApi();

  final http.Client _client = CustomHttpClient();

  /// Returns the dev-mode OTP code (only populated when the backend runs in
  /// development mode -- never in production, where `dev_otp` is null and the
  /// code arrives by e-mail) so the UI can surface it instead of requiring a
  /// real mailbox.
  Future<String?> requestOtp(String email) async {
    final response = await _client.post(
      Uri.parse('$kApiV1/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 429) {
      throw const AuthApiException('Too many requests. Please wait a few minutes and try again.');
    }
    if (response.statusCode != 200) {
      throw const AuthApiException('Failed to request a login code. Please try again.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['dev_otp'] as String?;
  }

  Future<(String token, SessionUser user)> verifyOtp({
    required String email,
    required String code,
  }) async {
    final response = await _client.post(
      Uri.parse('$kApiV1/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (response.statusCode == 429) {
      throw const AuthApiException('Too many failed attempts. Please wait a few minutes and try again.');
    }
    if (response.statusCode != 200) {
      throw const AuthApiException('Invalid or expired code. Please request a new one.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token'] as String;
    final user = SessionUser.fromJson(body['user'] as Map<String, dynamic>);
    return (token, user);
  }

  /// Best-effort server-side logout: revokes [token] so it stops working even
  /// if someone copied it. Failures are ignored -- the local session is
  /// cleared regardless.
  Future<void> logout(String token) async {
    try {
      await _client
          .post(
            Uri.parse('$kApiV1/auth/logout'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Offline / server unreachable: nothing more to do.
    }
  }

  /// Permanently deletes the signed-in account (POST /auth/delete-account). [confirmEmail] must be the
  /// account's own address. Returns null on success, otherwise a message that is safe to show the user.
  Future<String?> deleteAccount({required String token, required String confirmEmail}) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$kApiV1/auth/delete-account'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({'confirm_email': confirmEmail}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 204) return null;
      if (response.statusCode == 400) return 'That e-mail address does not match your account.';
      if (response.statusCode == 409) {
        try {
          final detail = (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
          if (detail is String && detail.isNotEmpty) return detail;
        } catch (_) {}
        return 'This account cannot be deleted right now.';
      }
      if (response.statusCode == 401) return 'Your session has expired. Please sign in again.';
      return 'Could not delete the account. Please try again.';
    } catch (_) {
      return 'Could not reach the server. Check your connection and try again.';
    }
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
