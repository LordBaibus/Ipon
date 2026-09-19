import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../services/expenses_service.dart';
import 'auth_provider.dart';
import 'plans_provider.dart';

class ExpenseActions {
  final Ref _ref;

  const ExpenseActions(this._ref);

  String? get _token {
    final auth = _ref.read(authProvider);
    return auth.isSignedIn ? auth.token : null;
  }

  Future<ExpenseActionResult> createExpense({
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
    final token = _token;
    if (token == null) {
      return const ExpenseActionResult(
        ok: false,
        message: 'You are not signed in.',
      );
    }

    final result = await ExpensesService.createExpense(
      _ref,
      token: token,
      amount: amount,
      merchant: merchant,
      category: category,
      expenseDate: expenseDate,
      notes: notes,
      source: source,
      groupId: groupId,
      planId: planId,
      planCategoryId: planCategoryId,
    );

    if (result.ok) {
      _invalidateRelated(planId);
    }

    return result;
  }
  void _invalidateRelated(int? planId) {
    if (planId != null) {
      _ref.invalidate(planDetailProvider(planId));
    }
    _ref.read(plansProvider.notifier).refresh();
  }
}

final expenseActionsProvider = Provider<ExpenseActions>((ref) {
  return ExpenseActions(ref);
});

const List<String> kExpenseCategorySuggestions = <String>[
  'Food',
  'Groceries',
  'Transportation',
  'Utilities',
  'Load & Internet',
  'Shopping',
  'Health',
  'School',
  'Entertainment',
  'Other',
];