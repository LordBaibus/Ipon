import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contribution.dart';
import '../services/contributions_service.dart';
import 'auth_provider.dart';
import 'plans_provider.dart';

final contributionSplitProvider =
FutureProvider.family<ContributionSplit, int>((ref, planId) async {
  final auth = ref.watch(authProvider);
  if (!auth.isSignedIn || auth.token == null) {
    throw Exception('You are not signed in.');
  }

  return ContributionsService.fetchSplit(ref, auth.token!, planId);
});
class ContributionActions {
  final Ref _ref;

  const ContributionActions(this._ref);

  String? get _token {
    final auth = _ref.read(authProvider);
    return auth.isSignedIn ? auth.token : null;
  }
  Future<ContributionActionResult> saveSplit({
    required int planId,
    required List<Contribution> members,
  }) async {
    final token = _token;
    if (token == null) {
      return const ContributionActionResult(
        ok: false,
        message: 'You are not signed in.',
      );
    }

    final result = await ContributionsService.saveSplit(
      _ref,
      token: token,
      planId: planId,
      members: members,
    );

    if (result.ok) {
      _ref.invalidate(contributionSplitProvider(planId));
    }

    return result;
  }
  Future<ContributionActionResult> previewSplit({
    required int planId,
    required List<Contribution> members,
  }) async {
    final token = _token;
    if (token == null) {
      return const ContributionActionResult(
        ok: false,
        message: 'You are not signed in.',
      );
    }

    return ContributionsService.previewSplit(
      _ref,
      token: token,
      planId: planId,
      members: members,
    );
  }
  Future<ContributionActionResult> recordPayment({
    required int planId,
    required double amount,
    int? userId,
    String mode = 'set',
  }) async {
    final token = _token;
    if (token == null) {
      return const ContributionActionResult(
        ok: false,
        message: 'You are not signed in.',
      );
    }

    final result = await ContributionsService.recordPayment(
      _ref,
      token: token,
      planId: planId,
      amount: amount,
      userId: userId,
      mode: mode,
    );

    if (result.ok) {
      _ref.invalidate(contributionSplitProvider(planId));
      _ref.invalidate(planDetailProvider(planId));
    }

    return result;
  }
}

final contributionActionsProvider = Provider<ContributionActions>((ref) {
  return ContributionActions(ref);
});