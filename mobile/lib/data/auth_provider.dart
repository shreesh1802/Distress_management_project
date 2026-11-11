import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api.dart';
import 'custom_http_client.dart' show SessionToken;

/// Google sign-in session state, backed by the DB-backed opaque bearer
/// token issued by POST /auth/google (see app/services/session_service.py).
/// Only emails on the Firestore allow-list can sign in.
class AuthState {
  const AuthState({
    required this.isAuthenticated,
    this.token,
    this.user,
    this.isRestoring = true,
  });

  final bool isAuthenticated;
  final String? token;
  final SessionUser? user;

  /// True while the app is checking a saved token against /auth/me on
  /// launch -- the router should hold on the splash/login route until this
  /// settles, so an already-logged-in user isn't bounced to /login first.
  final bool isRestoring;

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    SessionUser? user,
    bool? isRestoring,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      user: user ?? this.user,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _tokenKey = 'auth_token';

  /// Web client ID (oauth_client with client_type 3 in google-services.json).
  /// Android needs it as serverClientId to get an ID token back.
  static const _googleServerClientId =
      '949675387155-veq1cn4h9lbq8l3ah9mvdtj66a1qb139.apps.googleusercontent.com';

  final _api = AuthApi();
  bool _googleInitialized = false;

  @override
  AuthState build() {
    // A 401 on any authenticated request means the session is gone (expired /
    // revoked / removed from the allow-list): sign out locally so the router
    // returns to the login screen.
    SessionToken.onUnauthorized = _handleUnauthorized;
    _restore();
    return const AuthState(isAuthenticated: false, isRestoring: true);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token == null) {
      state = const AuthState(isAuthenticated: false, isRestoring: false);
      return;
    }

    final user = await _api.restoreSession(token);
    if (user == null) {
      SessionToken.value = null;
      await prefs.remove(_tokenKey);
      state = const AuthState(isAuthenticated: false, isRestoring: false);
      return;
    }

    SessionToken.value = token;
    state = AuthState(
      isAuthenticated: true,
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
    await _signOutOfGoogle();
    state = const AuthState(isAuthenticated: false, isRestoring: false);
  }

  /// Google sign-in via Firebase, then exchanged for our own session token
  /// at POST /auth/google. Returns false if the user closed the account
  /// picker (not an error -- the UI should just stay put).
  Future<bool> signInWithGoogle() async {
    final UserCredential credential;

    if (kIsWeb) {
      credential = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } else {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId);
        _googleInitialized = true;
      }
      final GoogleSignInAccount account;
      try {
        account = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) return false;
        throw AuthApiException(
          'Google sign-in is not set up correctly on this device (${e.code.name}). Please contact your administrator.',
        );
      }
      credential = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
    }

    final String token;
    final SessionUser user;
    try {
      final firebaseIdToken = await credential.user!.getIdToken();
      (token, user) = await _api.googleLogin(firebaseIdToken!);
    } catch (_) {
      // Not on the allow-list (or the backend rejected the token): drop the
      // Google session too, so the next attempt shows the account picker
      // again instead of silently reusing the rejected account.
      await _signOutOfGoogle();
      rethrow;
    }

    SessionToken.value = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    state = AuthState(
      isAuthenticated: true,
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

  Future<void> _signOutOfGoogle() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb && _googleInitialized) await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing to sign out of (for example in a unit test without Firebase).
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
