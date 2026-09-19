import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import 'api_client.dart';

class BudgetActionResult {
  final bool ok;
  final String message;
  final Budget? budget;

  const BudgetActionResult({
    required this.ok,
    required this.message,
    this.budget,
  });
}

class BudgetsService {
  BudgetsService._();

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
  static Future<Budget> fetchBudget(
      Ref ref,
      String token, {
        int? groupId,
      }) async {
    final payload = <String, dynamic>{'token': token};
    if (groupId != null) payload['group_id'] = groupId;

    final res = await ApiClient.post(ref, '/budgets/get.php', payload);

    if (!res.success) {
      throw Exception(res.error ?? 'Could not load your budget.');
    }

    final data = _dataMap(res.data);
    if (data == null) return Budget.empty(groupId: groupId);

    return Budget.fromJson(data);
  }
  static Future<BudgetActionResult> setBudget(
      Ref ref, {
        required String token,
        required double limitAmount,
        int cycleStartDay = 1,
        int? groupId,
      }) async {
    final payload = <String, dynamic>{
      'token': token,
      'limit_amount': limitAmount,
      'cycle_start_day': cycleStartDay,
    };
    if (groupId != null) payload['group_id'] = groupId;

    final res = await ApiClient.post(ref, '/budgets/set.php', payload);

    if (!res.success) {
      return BudgetActionResult(
        ok: false,
        message: res.error ?? 'Could not save the budget.',
      );
    }

    final data = _dataMap(res.data);
    return BudgetActionResult(
      ok: true,
      message: _message(res.data, 'Budget saved.'),
      budget: data == null ? null : Budget.fromJson(data),
    );
  }
}