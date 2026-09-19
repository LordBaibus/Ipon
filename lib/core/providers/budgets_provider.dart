import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../services/budgets_service.dart';
import 'auth_provider.dart';

class BudgetNotifier extends FamilyAsyncNotifier<Budget, int?> {
  @override
  Future<Budget> build(int? groupId) async {
    final auth = ref.watch(authProvider);

    if (!auth.isSignedIn || auth.token == null) {
      return Budget.empty(groupId: groupId);
    }

    return BudgetsService.fetchBudget(ref, auth.token!, groupId: groupId);
  }

  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    if (!auth.isSignedIn || auth.token == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
          () => BudgetsService.fetchBudget(ref, auth.token!, groupId: arg),
    );
  }

  Future<BudgetActionResult> save({
    required double limitAmount,
    int cycleStartDay = 1,
  }) async {
    final auth = ref.read(authProvider);
    if (!auth.isSignedIn || auth.token == null) {
      return const BudgetActionResult(
        ok: false,
        message: 'You are not signed in.',
      );
    }

    final result = await BudgetsService.setBudget(
      ref,
      token: auth.token!,
      limitAmount: limitAmount,
      cycleStartDay: cycleStartDay,
      groupId: arg,
    );

    if (result.ok) await refresh();
    return result;
  }
}
final budgetProvider =
AsyncNotifierProvider.family<BudgetNotifier, Budget, int?>(
  BudgetNotifier.new,
);
final personalBudgetProvider = Provider<AsyncValue<Budget>>((ref) {
  return ref.watch(budgetProvider(null));
});