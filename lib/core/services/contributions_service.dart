import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contribution.dart';
import 'api_client.dart';

class ContributionActionResult {
  final bool ok;
  final String message;
  final ContributionSplit? split;

  const ContributionActionResult({
    required this.ok,
    required this.message,
    this.split,
  });
}

class ContributionsService {
  ContributionsService._();

  static String _message(dynamic body, String fallback) {
    if (body is Map && body['message'] != null) {
      final text = body['message'].toString();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static Map<String, dynamic>? _dataMap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return null;
  }
  static Future<ContributionSplit> fetchSplit(
      Ref ref,
      String token,
      int planId,
      ) async {
    final res = await ApiClient.post(ref, '/contributions/list.php', {
      'token': token,
      'plan_id': planId,
    });

    if (!res.success) {
      throw Exception(res.error ?? 'Could not load the contribution split.');
    }

    final data = _dataMap(res.data);
    if (data == null) {
      throw Exception('The server returned an unexpected response.');
    }

    return ContributionSplit.fromJson(data);
  }
  static Future<ContributionActionResult> previewSplit(
      Ref ref, {
        required String token,
        required int planId,
        required List<Contribution> members,
      }) async {
    final res = await ApiClient.post(ref, '/contributions/preview.php', {
      'token': token,
      'plan_id': planId,
      'members': members.map((m) => m.toRequestJson()).toList(),
    });

    if (!res.success) {
      return ContributionActionResult(
        ok: false,
        message: res.error ?? 'That split is not valid.',
      );
    }

    final data = _dataMap(res.data);
    return ContributionActionResult(
      ok: true,
      message: '',
      split: data == null ? null : ContributionSplit.fromJson(data),
    );
  }
  static Future<ContributionActionResult> saveSplit(
      Ref ref, {
        required String token,
        required int planId,
        required List<Contribution> members,
      }) async {
    final res = await ApiClient.post(ref, '/contributions/set.php', {
      'token': token,
      'plan_id': planId,
      'members': members.map((m) => m.toRequestJson()).toList(),
    });

    if (!res.success) {
      return ContributionActionResult(
        ok: false,
        message: res.error ?? 'Could not save the split.',
      );
    }

    final data = _dataMap(res.data);
    return ContributionActionResult(
      ok: true,
      message: _message(res.data, 'Split saved.'),
      split: data == null ? null : ContributionSplit.fromJson(data),
    );
  }
  static Future<ContributionActionResult> recordPayment(
      Ref ref, {
        required String token,
        required int planId,
        required double amount,
        int? userId,
        String mode = 'set',
      }) async {
    final payload = <String, dynamic>{
      'token': token,
      'plan_id': planId,
      'amount': amount,
      'mode': mode,
    };
    if (userId != null) payload['user_id'] = userId;

    final res =
    await ApiClient.post(ref, '/contributions/record_payment.php', payload);

    if (!res.success) {
      return ContributionActionResult(
        ok: false,
        message: res.error ?? 'Could not record the payment.',
      );
    }

    final data = _dataMap(res.data);
    return ContributionActionResult(
      ok: true,
      message: _message(res.data, 'Payment recorded.'),
      split: data == null ? null : ContributionSplit.fromJson(data),
    );
  }
}