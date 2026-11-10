import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api.dart';

/// Google sign-in session state, backed by the DB-backed opaque bearer
/// token issued by POST /auth/google (see app/services/session_service.py).
/// Only emails an admin has added to the users table can sign in.
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
      await prefs.remove(_tokenKey);
      state = const AuthState(isAuthenticated: false, isRestoring: false);
      return;
    }

    state = AuthState(
      isAuthenticated: true,
      token: token,
      user: user,
      isRestoring: false,
    );
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
        rethrow;
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await _signOutOfGoogle();
    state = const AuthState(isAuthenticated: false, isRestoring: false);
  }

  Future<void> _signOutOfGoogle() async {
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb && _googleInitialized) await GoogleSignIn.instance.signOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
