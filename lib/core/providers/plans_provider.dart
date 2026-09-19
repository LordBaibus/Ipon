import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plan.dart';
import '../services/plans_service.dart';
import 'auth_provider.dart';

final planScopeProvider = StateProvider<String>((ref) => 'all');
final planTemplatesProvider = FutureProvider<List<PlanTemplate>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isSignedIn || auth.token == null) return const <PlanTemplate>[];

  return PlansService.fetchTemplates(ref, auth.token!);
});

class PlansNotifier extends AsyncNotifier<List<Plan>> {
  @override
  Future<List<Plan>> build() async {
    // Rebuilds when the session changes or the scope filter changes.
    final auth = ref.watch(authProvider);
    final scope = ref.watch(planScopeProvider);

    if (!auth.isSignedIn || auth.token == null) return const <Plan>[];

    return PlansService.fetchPlans(ref, auth.token!, scope: scope);
  }

  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    final scope = ref.read(planScopeProvider);
    if (!auth.isSignedIn || auth.token == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
          () => PlansService.fetchPlans(ref, auth.token!, scope: scope),
    );
  }

  Future<PlanActionResult> createPlan({
    required String name,
    required String planType,
    required double targetAmount,
    int? groupId,
    String? deadline,
    String? notes,
    List<PlanCategory>? categories,
  }) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) {
      return const PlanActionResult(ok: false, message: 'You are not signed in.');
    }

    final result = await PlansService.createPlan(
      ref,
      token: auth.token!,
      name: name,
      planType: planType,
      targetAmount: targetAmount,
      groupId: groupId,
      deadline: deadline,
      notes: notes,
      categories: categories,
    );

    if (result.ok) await refresh();
    return result;
  }

  Future<PlanActionResult> updatePlan({
    required int planId,
    String? name,
    double? targetAmount,
    String? deadline,
    String? notes,
    List<PlanCategory>? categories,
    bool reapplyTemplate = false,
  }) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) {
      return const PlanActionResult(ok: false, message: 'You are not signed in.');
    }

    final result = await PlansService.updatePlan(
      ref,
      token: auth.token!,
      planId: planId,
      name: name,
      targetAmount: targetAmount,
      deadline: deadline,
      notes: notes,
      categories: categories,
      reapplyTemplate: reapplyTemplate,
    );

    if (result.ok) {
      ref.invalidate(planDetailProvider(planId));
      await refresh();
    }
    return result;
  }

  Future<PlanActionResult> deletePlan(int planId) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) {
      return const PlanActionResult(ok: false, message: 'You are not signed in.');
    }

    final result = await PlansService.deletePlan(
      ref,
      token: auth.token!,
      planId: planId,
    );

    if (result.ok) await refresh();
    return result;
  }
}

final plansProvider =
AsyncNotifierProvider<PlansNotifier, List<Plan>>(PlansNotifier.new);

final planDetailProvider =
FutureProvider.family<Plan, int>((ref, planId) async {
  final auth = ref.watch(authProvider);
  if (!auth.isSignedIn || auth.token == null) {
    throw Exception('You are not signed in.');
  }

  return PlansService.fetchPlanDetail(ref, auth.token!, planId);
});