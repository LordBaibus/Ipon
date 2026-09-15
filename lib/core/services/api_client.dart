
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/server_config_provider.dart';

class PingResult {
  final bool ok;
  final String? message;
  const PingResult(this.ok, [this.message]);
}

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final bool isConnectivityIssue;

  const ApiResult.ok(this.data)
      : success = true,
        error = null,
        isConnectivityIssue = false;

  const ApiResult.fail(this.error, {this.isConnectivityIssue = false})
      : success = false,
        data = null;
}

class ApiClient {
  ApiClient._();

  static const _timeout = Duration(seconds: 8);
  static Future<PingResult> pingRaw(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/ping.php');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['success'] == true) {
            return const PingResult(true);
          }
        } catch (_) {
          return const PingResult(
            true,
            'Reached the server, but ping.php did not return the expected JSON.',
          );
        }
        return const PingResult(
          false,
          'Server responded but did not confirm success.',
        );
      }
      return PingResult(false, 'Server returned HTTP ${response.statusCode}.');
    } on SocketException {
      return const PingResult(
        false,
        'Could not reach that address. Check the IP/URL and that both '
            'devices are on the same network (for local testing).',
      );
    } on HttpException {
      return const PingResult(false, 'The server address looks invalid.');
    } on FormatException {
      return const PingResult(false, 'The server address is not a valid URL.');
    } catch (e) {
      return PingResult(false, 'Connection failed: ${e.toString()}');
    }
  }

  static Future<ApiResult<dynamic>> get(Ref ref, String path) async {
    final baseUrl = ref.read(serverConfigProvider).baseUrl;
    return _send(ref, () => http.get(Uri.parse('$baseUrl$path')).timeout(_timeout));
  }

  static Future<ApiResult<dynamic>> post(
      Ref ref,
      String path,
      Map<String, dynamic> body,
      ) async {
    final baseUrl = ref.read(serverConfigProvider).baseUrl;
    return _send(
      ref,
          () => http
          .post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
          .timeout(_timeout),
    );
  }

  static Future<ApiResult<dynamic>> _send(
      Ref ref,
      Future<http.Response> Function() request,
      ) async {
    try {
      final response = await request();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
        return ApiResult.ok(decoded);
      }

      String message = 'Request failed (HTTP ${response.statusCode}).';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {
      }
      return ApiResult.fail(message);
    } on SocketException {
      ref.read(serverConfigProvider.notifier).reportRequestFailure(
        'Lost connection to the server.',
      );
      return const ApiResult.fail(
        'Lost connection to the server.',
        isConnectivityIssue: true,
      );
    } on HttpException {
      ref.read(serverConfigProvider.notifier).reportRequestFailure(
        'The server address is no longer valid.',
      );
      return const ApiResult.fail(
        'The server address is no longer valid.',
        isConnectivityIssue: true,
      );
    } catch (e) {
      final msg = e.toString().contains('TimeoutException')
          ? 'The server took too long to respond.'
          : 'Something went wrong: ${e.toString()}';
      ref.read(serverConfigProvider.notifier).reportRequestFailure(msg);
      return ApiResult.fail(msg, isConnectivityIssue: true);
    }
  }
}