import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api.dart';
import 'custom_http_client.dart' show SessionToken;

/// Real Email + OTP session state, backed by the DB-backed opaque bearer
/// token issued by POST /auth/verify-otp (see app/services/otp_service.py).
/// Replaces the old hardcoded admin@akcm.com / Admin@123 mock check.
class AuthState {
  const AuthState({
    required this.isAuthenticated,
    this.rememberedEmail,
    this.token,
    this.user,
    this.isRestoring = true,
  });

  final bool isAuthenticated;
  final String? rememberedEmail;
  final String? token;
  final SessionUser? user;

  /// True while the app is checking a saved token against /auth/me on
  /// launch -- the router should hold on the splash/login route until this
  /// settles, so an already-logged-in user isn't bounced to /login first.
  final bool isRestoring;

  AuthState copyWith({
    bool? isAuthenticated,
    String? rememberedEmail,
    String? token,
    SessionUser? user,
    bool? isRestoring,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      rememberedEmail: rememberedEmail ?? this.rememberedEmail,
      token: token ?? this.token,
      user: user ?? this.user,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _tokenKey = 'auth_token';
  static const _rememberedEmailKey = 'rememberedEmail';

  final _api = AuthApi();

  @override
  AuthState build() {
    // A 401 on any authenticated request means the session is gone (expired /
    // revoked): sign out locally so the router returns to the login screen.
    SessionToken.onUnauthorized = _handleUnauthorized;
    _restore();
    return const AuthState(isAuthenticated: false, isRestoring: true);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedEmail = prefs.getString(_rememberedEmailKey);
    final token = prefs.getString(_tokenKey);

    if (token == null) {
      state = AuthState(
        isAuthenticated: false,
        rememberedEmail: rememberedEmail,
        isRestoring: false,
      );
      return;
    }

    final user = await _api.restoreSession(token);
    if (user == null) {
      SessionToken.value = null;
      await prefs.remove(_tokenKey);
      state = AuthState(
        isAuthenticated: false,
        rememberedEmail: rememberedEmail,
        isRestoring: false,
      );
      return;
    }

    SessionToken.value = token;
    state = AuthState(
      isAuthenticated: true,
      rememberedEmail: rememberedEmail,
      token: token,
      user: user,
      isRestoring: false,
    );
  }

  void _handleUnauthorized() {
    if (!state.isAuthenticated) return;
    _clearLocalSession();
  }

  Future<void> _clearLocalSession() async {
    SessionToken.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    state = AuthState(
      isAuthenticated: false,
      rememberedEmail: state.rememberedEmail,
      isRestoring: false,
    );
  }

  /// Step 1 of Email + OTP login. Returns the dev-mode OTP so the UI can
  /// surface it (no real mailbox wired up yet -- see otp_service.py).
  Future<String?> requestOtp(String email) => _api.requestOtp(email);

  /// Step 2: verify the code, persist the session token, and mark the user
  /// authenticated.
  Future<bool> verifyOtp({
    required String email,
    required String code,
    required bool rememberMe,
  }) async {
    final (token, user) = await _api.verifyOtp(email: email, code: code);

    SessionToken.value = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (rememberMe) {
      await prefs.setString(_rememberedEmailKey, email);
    } else {
      await prefs.remove(_rememberedEmailKey);
    }

    state = AuthState(
      isAuthenticated: true,
      rememberedEmail: rememberMe ? email : null,
      token: token,
      user: user,
      isRestoring: false,
    );
    return true;
  }

  /// Deletes the signed-in user's account on the server and, on success, clears the local session.
  /// Returns null on success or an error message to show the user.
  Future<String?> deleteAccount(String confirmEmail) async {
    final token = state.token;
    if (token == null) return 'You are not signed in.';
    final error = await _api.deleteAccount(token: token, confirmEmail: confirmEmail);
    if (error != null) return error;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedEmailKey);
    await _clearLocalSession();
    return null;
  }

  Future<void> logout() async {
    // Revoke the session on the server first (best effort), then clear local state.
    final token = state.token;
    if (token != null) {
      await _api.logout(token);
    }
    await _clearLocalSession();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
