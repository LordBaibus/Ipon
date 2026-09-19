import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import 'api_client.dart';

class ExpenseActionResult {
  final bool ok;
  final String message;
  final Expense? expense;

  const ExpenseActionResult({
    required this.ok,
    required this.message,
    this.expense,
  });
}

class ExpensesService {
  ExpensesService._();

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
  static Future<ExpenseActionResult> createExpense(
      Ref ref, {
        required String token,
        required double amount,
        String? merchant,
        String? category,
        String? expenseDate,
        String? notes,
        String source = 'manual',
        int? groupId,
        int? planId,
        int? planCategoryId,
      }) async {
    final payload = <String, dynamic>{
      'token': token,
      'amount': amount,
      'source': source,
    };

    if (merchant != null && merchant.trim().isNotEmpty) {
      payload['merchant'] = merchant.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      payload['category'] = category.trim();
    }
    if (expenseDate != null && expenseDate.isNotEmpty) {
      payload['expense_date'] = expenseDate;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }
    if (groupId != null) payload['group_id'] = groupId;
    if (planId != null) payload['plan_id'] = planId;
    if (planCategoryId != null) payload['plan_category_id'] = planCategoryId;

    final res = await ApiClient.post(ref, '/expenses/create.php', payload);

    if (!res.success) {
      return ExpenseActionResult(
        ok: false,
        message: res.error ?? 'Could not save the expense.',
      );
    }

    final data = _dataMap(res.data);
    return ExpenseActionResult(
      ok: true,
      message: _message(res.data, 'Expense saved.'),
      expense: data == null ? null : Expense.fromJson(data),
    );
  }
}