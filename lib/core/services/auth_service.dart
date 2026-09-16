import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import 'api_client.dart';

class AuthResult {
  final bool ok;
  final String message;
  final bool needsVerification;
  final AppUser? user;
  final String? token;

  const AuthResult({
    required this.ok,
    required this.message,
    this.needsVerification = false,
    this.user,
    this.token,
  });

  factory AuthResult.failure(String message, {bool needsVerification = false}) {
    return AuthResult(
      ok: false,
      message: message,
      needsVerification: needsVerification,
    );
  }

  factory AuthResult.success(String message, {AppUser? user, String? token}) {
    return AuthResult(ok: true, message: message, user: user, token: token);
  }
}

class AuthService {
  AuthService._();
  static Map<String, dynamic>? _data(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return null;
  }

  static String _message(dynamic body, String fallback) {
    if (body is Map && body['message'] != null) {
      final text = body['message'].toString();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static Future<AuthResult> register(
      Ref ref, {
        required String fullName,
        required String email,
        required String password,
      }) async {
    final res = await ApiClient.post(ref, '/auth/register.php', {
      'full_name': fullName,
      'email': email,
      'password': password,
    });

    if (!res.success) {
      return AuthResult.failure(res.error ?? 'Could not create your account.');
    }

    return AuthResult.success(
      _message(res.data, 'Account created. Check your email for the code.'),
    );
  }

  static Future<AuthResult> verifyEmail(
      Ref ref, {
        required String email,
        required String code,
      }) async {
    final res = await ApiClient.post(ref, '/auth/verify_email.php', {
      'email': email,
      'code': code,
    });

    if (!res.success) {
      return AuthResult.failure(res.error ?? 'Could not verify that code.');
    }

    return AuthResult.success(_message(res.data, 'Email verified.'));
  }

  static Future<AuthResult> resendVerification(
      Ref ref, {
        required String email,
      }) async {
    final res = await ApiClient.post(ref, '/auth/resend_verification.php', {
      'email': email,
    });

    if (!res.success) {
      return AuthResult.failure(res.error ?? 'Could not resend the code.');
    }

    return AuthResult.success(_message(res.data, 'A new code has been sent.'));
  }

  static Future<AuthResult> login(
      Ref ref, {
        required String email,
        required String password,
      }) async {
    final res = await ApiClient.post(ref, '/auth/login.php', {
      'email': email,
      'password': password,
    });

    if (!res.success) {
      final message = res.error ?? 'Could not sign in.';
      final looksUnverified = message.toLowerCase().contains('verify');
      return AuthResult.failure(message, needsVerification: looksUnverified);
    }

    final data = _data(res.data);
    if (data == null || data['token'] == null || data['user'] is! Map) {
      return AuthResult.failure('The server returned an unexpected response.');
    }

    return AuthResult.success(
      _message(res.data, 'Signed in.'),
      token: data['token'].toString(),
      user: AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
    );
  }

  static Future<AuthResult> forgotPassword(
      Ref ref, {
        required String email,
      }) async {
    final res = await ApiClient.post(ref, '/auth/forgot_password.php', {
      'email': email,
    });

    if (!res.success) {
      return AuthResult.failure(res.error ?? 'Could not send a reset code.');
    }

    return AuthResult.success(
      _message(res.data, 'If that email is registered, a code has been sent.'),
    );
  }

  static Future<AuthResult> resetPassword(
      Ref ref, {
        required String email,
        required String code,
        required String newPassword,
      }) async {
    final res = await ApiClient.post(ref, '/auth/reset_password.php', {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });

    if (!res.success) {
      return AuthResult.failure(res.error ?? 'Could not reset your password.');
    }

    return AuthResult.success(_message(res.data, 'Password updated.'));
  }
}