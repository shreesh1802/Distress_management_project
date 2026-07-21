import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the localStorage keys used by the React LoginPage:
/// `isAuthenticated` and `rememberedEmail`.
class AuthState {
  const AuthState({required this.isAuthenticated, this.rememberedEmail});

  final bool isAuthenticated;
  final String? rememberedEmail;

  AuthState copyWith({bool? isAuthenticated, String? rememberedEmail}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      rememberedEmail: rememberedEmail ?? this.rememberedEmail,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _authKey = 'isAuthenticated';
  static const _rememberedEmailKey = 'rememberedEmail';

  @override
  AuthState build() {
    _restore();
    return const AuthState(isAuthenticated: false);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuthenticated = prefs.getBool(_authKey) ?? false;
    final rememberedEmail = prefs.getString(_rememberedEmailKey);
    state = AuthState(isAuthenticated: isAuthenticated, rememberedEmail: rememberedEmail);
  }

  /// Hardcoded admin credential check, matching the React prototype's
  /// LoginPage.tsx (admin@akcm.com / Admin@123) until real auth wiring lands.
  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (email != 'admin@akcm.com' || password != 'Admin@123') {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, true);
    if (rememberMe) {
      await prefs.setString(_rememberedEmailKey, email);
    } else {
      await prefs.remove(_rememberedEmailKey);
    }

    state = AuthState(
      isAuthenticated: true,
      rememberedEmail: rememberMe ? email : null,
    );
    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
    state = state.copyWith(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
