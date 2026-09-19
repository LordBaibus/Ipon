import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/expenses_service.dart';
import 'auth_provider.dart';
import 'plans_provider.dart';

final expenseFiltersProvider =
StateProvider<ExpenseFilters>((ref) => const ExpenseFilters());

class ExpenseLedgerNotifier extends AsyncNotifier<ExpensePage> {
  @override
  Future<ExpensePage> build() async {
    final auth = ref.watch(authProvider);
    final filters = ref.watch(expenseFiltersProvider);

    if (!auth.isSignedIn || auth.token == null) {
      return const ExpensePage();
    }

    return ExpensesService.fetchExpenses(ref, auth.token!, filters: filters);
  }

  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    final filters = ref.read(expenseFiltersProvider);
    if (!auth.isSignedIn || auth.token == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
          () => ExpensesService.fetchExpenses(ref, auth.token!, filters: filters),
    );
  }
}

final expenseLedgerProvider =
AsyncNotifierProvider<ExpenseLedgerNotifier, ExpensePage>(
  ExpenseLedgerNotifier.new,
);
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

    if (result.ok) await _invalidateRelated(planId);
    return result;
  }

  Future<ExpenseActionResult> updateExpense({
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
    int? previousPlanId,
  }) async {
    final token = _token;
    if (token == null) {
      return const ExpenseActionResult(
        ok: false,
        message: 'You are not signed in.',
      );
    }

    final result = await ExpensesService.updateExpense(
      _ref,
      token: token,
      expenseId: expenseId,
      amount: amount,
      merchant: merchant,
      category: category,
      expenseDate: expenseDate,
      notes: notes,
      groupId: groupId,
      planId: planId,
      planCategoryId: planCategoryId,
      clearGroup: clearGroup,
      clearPlan: clearPlan,
      clearPlanCategory: clearPlanCategory,
    );

    if (result.ok) {
      if (previousPlanId != null && previousPlanId != planId) {
        _ref.invalidate(planDetailProvider(previousPlanId));
      }
      await _invalidateRelated(planId ?? previousPlanId);
    }

    return result;
  }

  Future<ExpenseActionResult> deleteExpense({
    required int expenseId,
    int? planId,
  }) async {
    final token = _token;
    if (token == null) {
      return const ExpenseActionResult(
        ok: false,
        message: 'You are not signed in.',
      );
    }

    final result = await ExpensesService.deleteExpense(
      _ref,
      token: token,
      expenseId: expenseId,
    );

    if (result.ok) await _invalidateRelated(planId);
    return result;
  }
  Future<void> _invalidateRelated(int? planId) async {
    if (planId != null) {
      _ref.invalidate(planDetailProvider(planId));
    }
    // The plans list shows per-plan totals, and the dashboard shows
    // spending across everything.
    _ref.read(plansProvider.notifier).refresh();
    await _ref.read(expenseLedgerProvider.notifier).refresh();
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