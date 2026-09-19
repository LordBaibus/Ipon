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

class ExpensePage {
  final List<Expense> expenses;
  final int totalCount;
  final double totalAmount;
  final int limit;
  final int offset;

  const ExpensePage({
    this.expenses = const [],
    this.totalCount = 0,
    this.totalAmount = 0,
    this.limit = 100,
    this.offset = 0,
  });

  factory ExpensePage.fromJson(Map<String, dynamic> json) {
    final raw = json['expenses'];

    return ExpensePage(
      expenses: raw is List
          ? raw
          .whereType<Map>()
          .map((e) => Expense.fromJson(Map<String, dynamic>.from(e)))
          .toList()
          : const [],
      totalCount: int.tryParse('${json['total_count']}') ?? 0,
      totalAmount: double.tryParse('${json['total_amount']}') ?? 0.0,
      limit: int.tryParse('${json['limit']}') ?? 100,
      offset: int.tryParse('${json['offset']}') ?? 0,
    );
  }

  bool get isEmpty => expenses.isEmpty;
  bool get hasMore => (offset + expenses.length) < totalCount;
}

class ExpenseFilters {
  final String scope;
  final int? groupId;
  final int? planId;
  final int? planCategoryId;
  final String? category;
  final String? source;
  final String? dateFrom;
  final String? dateTo;
  final String? search;

  const ExpenseFilters({
    this.scope = 'all',
    this.groupId,
    this.planId,
    this.planCategoryId,
    this.category,
    this.source,
    this.dateFrom,
    this.dateTo,
    this.search,
  });

  ExpenseFilters copyWith({
    String? scope,
    int? groupId,
    int? planId,
    int? planCategoryId,
    String? category,
    String? source,
    String? dateFrom,
    String? dateTo,
    String? search,
    bool clearGroup = false,
    bool clearPlan = false,
    bool clearCategory = false,
    bool clearSource = false,
    bool clearDates = false,
    bool clearSearch = false,
  }) {
    return ExpenseFilters(
      scope: scope ?? this.scope,
      groupId: clearGroup ? null : (groupId ?? this.groupId),
      planId: clearPlan ? null : (planId ?? this.planId),
      planCategoryId: clearPlan ? null : (planCategoryId ?? this.planCategoryId),
      category: clearCategory ? null : (category ?? this.category),
      source: clearSource ? null : (source ?? this.source),
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      search: clearSearch ? null : (search ?? this.search),
    );
  }
  bool get hasActiveFilters =>
      groupId != null ||
          planId != null ||
          planCategoryId != null ||
          category != null ||
          source != null ||
          dateFrom != null ||
          dateTo != null ||
          (search != null && search!.isNotEmpty);

  Map<String, dynamic> toRequestJson() {
    final payload = <String, dynamic>{'scope': scope};

    if (groupId != null) payload['group_id'] = groupId;
    if (planId != null) payload['plan_id'] = planId;
    if (planCategoryId != null) payload['plan_category_id'] = planCategoryId;
    if (category != null && category!.isNotEmpty) payload['category'] = category;
    if (source != null && source!.isNotEmpty) payload['source'] = source;
    if (dateFrom != null && dateFrom!.isNotEmpty) payload['date_from'] = dateFrom;
    if (dateTo != null && dateTo!.isNotEmpty) payload['date_to'] = dateTo;
    if (search != null && search!.isNotEmpty) payload['search'] = search;

    return payload;
  }
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
  static Future<ExpensePage> fetchExpenses(
      Ref ref,
      String token, {
        ExpenseFilters filters = const ExpenseFilters(),
        int limit = 100,
        int offset = 0,
      }) async {
    final payload = filters.toRequestJson()
      ..['token'] = token
      ..['limit'] = limit
      ..['offset'] = offset;

    final res = await ApiClient.post(ref, '/expenses/list.php', payload);

    if (!res.success) {
      throw Exception(res.error ?? 'Could not load your expenses.');
    }

    final data = _dataMap(res.data);
    if (data == null) return const ExpensePage();

    return ExpensePage.fromJson(data);
  }
  static Future<ExpenseActionResult> updateExpense(
      Ref ref, {
        required String token,
        required int expenseId,
        double? amount,
        String? merchant,
        String? category,
        String? expenseDate,
        String? notes,
        int? groupId,
        int? planId,
        int? planCategoryId,
        bool clearGroup = false,
        bool clearPlan = false,
        bool clearPlanCategory = false,
      }) async {
    final payload = <String, dynamic>{
      'token': token,
      'expense_id': expenseId,
    };

    if (amount != null) payload['amount'] = amount;
    if (merchant != null) payload['merchant'] = merchant;
    if (category != null) payload['category'] = category;
    if (expenseDate != null) payload['expense_date'] = expenseDate;
    if (notes != null) payload['notes'] = notes;

    if (clearGroup) {
      payload['group_id'] = null;
    } else if (groupId != null) {
      payload['group_id'] = groupId;
    }

    if (clearPlan) {
      payload['plan_id'] = null;
      payload['plan_category_id'] = null;
    } else {
      if (planId != null) payload['plan_id'] = planId;
      if (clearPlanCategory) {
        payload['plan_category_id'] = null;
      } else if (planCategoryId != null) {
        payload['plan_category_id'] = planCategoryId;
      }
    }

    final res = await ApiClient.post(ref, '/expenses/update.php', payload);

    if (!res.success) {
      return ExpenseActionResult(
        ok: false,
        message: res.error ?? 'Could not update the expense.',
      );
    }

    final data = _dataMap(res.data);
    return ExpenseActionResult(
      ok: true,
      message: _message(res.data, 'Expense updated.'),
      expense: data == null ? null : Expense.fromJson(data),
    );
  }
  static Future<ExpenseActionResult> deleteExpense(
      Ref ref, {
        required String token,
        required int expenseId,
      }) async {
    final res = await ApiClient.post(ref, '/expenses/delete.php', {
      'token': token,
      'expense_id': expenseId,
    });

    if (!res.success) {
      return ExpenseActionResult(
        ok: false,
        message: res.error ?? 'Could not delete the expense.',
      );
    }

    return ExpenseActionResult(
      ok: true,
      message: _message(res.data, 'Expense deleted.'),
    );
  }
}