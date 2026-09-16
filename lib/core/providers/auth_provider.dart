import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  authenticated,
}

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? token;
  final bool isBusy;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.token,
    this.isBusy = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? token,
    bool? isBusy,
    bool clearSession = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearSession ? null : (user ?? this.user),
      token: clearSession ? null : (token ?? this.token),
      isBusy: isBusy ?? this.isBusy,
    );
  }

  bool get isSignedIn => status == AuthStatus.authenticated && token != null;
}

class AuthNotifier extends Notifier<AuthState> {
  static const _tokenKey = 'ipon_session_token';
  static const _userKey = 'ipon_session_user';

  @override
  AuthState build() {
    _restoreSession();
    return const AuthState();
  }
  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);

    if (token == null || token.isEmpty || userJson == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final decoded = jsonDecode(userJson);
      final user = AppUser.fromJson(Map<String, dynamic>.from(decoded as Map));
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        token: token,
      );
    } catch (_) {
      // Corrupted saved session — start clean rather than crashing.
      await _clearStoredSession();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _storeSession(String token, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true);
    final result = await AuthService.register(
      ref,
      fullName: fullName,
      email: email,
      password: password,
    );
    state = state.copyWith(isBusy: false);
    return result;
  }

  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    state = state.copyWith(isBusy: true);
    final result = await AuthService.verifyEmail(ref, email: email, code: code);
    state = state.copyWith(isBusy: false);
    return result;
  }

  Future<AuthResult> resendVerification({required String email}) async {
    state = state.copyWith(isBusy: true);
    final result = await AuthService.resendVerification(ref, email: email);
    state = state.copyWith(isBusy: false);
    return result;
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true);
    final result = await AuthService.login(ref, email: email, password: password);

    if (result.ok && result.token != null && result.user != null) {
      await _storeSession(result.token!, result.user!);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result.user,
        token: result.token,
        isBusy: false,
      );
    } else {
      state = state.copyWith(isBusy: false);
    }

    return result;
  }

  Future<AuthResult> forgotPassword({required String email}) async {
    state = state.copyWith(isBusy: true);
    final result = await AuthService.forgotPassword(ref, email: email);
    state = state.copyWith(isBusy: false);
    return result;
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(isBusy: true);
    final result = await AuthService.resetPassword(
      ref,
      email: email,
      code: code,
      newPassword: newPassword,
    );
    state = state.copyWith(isBusy: false);
    return result;
  }
  Future<void> logout() async {
    await _clearStoredSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
  Future<void> handleExpiredSession() async {
    await _clearStoredSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).user;
});