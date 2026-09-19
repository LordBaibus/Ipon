import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard.dart';
import '../services/dashboard_service.dart';
import 'auth_provider.dart';

final dashboardScopeProvider = StateProvider<String>((ref) => 'all');
final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final auth = ref.watch(authProvider);
  final scope = ref.watch(dashboardScopeProvider);

  if (!auth.isSignedIn || auth.token == null) {
    return const DashboardSummary();
  }

  return DashboardService.fetchSummary(ref, auth.token!, scope: scope);
});
final groupBalancesProvider =
FutureProvider.family<GroupBalances, int>((ref, groupId) async {
  final auth = ref.watch(authProvider);

  if (!auth.isSignedIn || auth.token == null) {
    throw Exception('You are not signed in.');
  }

  return DashboardService.fetchBalances(ref, auth.token!, groupId);
});