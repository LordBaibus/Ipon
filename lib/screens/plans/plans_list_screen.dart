import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/plan.dart';
import '../../core/providers/plans_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/primary_glass_button.dart';
import '../dashboard/dashboard_screen.dart' show kAppBarClearance;
import 'plan_create_screen.dart';
import 'plan_detail_screen.dart';

class PlansListScreen extends ConsumerWidget {
  const PlansListScreen({super.key});

  static const _scopes = ['all', 'personal', 'group'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);
    final scope = ref.watch(planScopeProvider);
    final scopeIndex = _scopes.indexOf(scope).clamp(0, _scopes.length - 1);

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        title: const Text('Plans'),
        actions: [
          GlassButton(
            icon: const Icon(
              CupertinoIcons.add,
              color: AppColors.moneyGreen,
            ),
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const PlanCreateScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: kAppBarClearance),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: GlassSegmentedControl(
                selectedIndex: scopeIndex,
                onSegmentSelected: (index) {
                  ref.read(planScopeProvider.notifier).state = _scopes[index];
                },
                segments: const [
                  GlassSegment(label: 'All'),
                  GlassSegment(label: 'Personal'),
                  GlassSegment(label: 'Group'),
                ],
              ),
            ),
            Expanded(
              child: plansAsync.when(
                loading: () => const Center(
                  child: GlassProgressIndicator.circular(size: 28),
                ),
                error: (error, _) => _PlansErrorState(
                  message: error.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => ref.read(plansProvider.notifier).refresh(),
                ),
                data: (plans) => plans.isEmpty
                    ? _PlansEmptyState(scope: scope)
                    : _PlansList(plans: plans),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlansList extends StatelessWidget {
  final List<Plan> plans;

  const _PlansList({required this.plans});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PlanCard(plan: plan),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final remainingDays = daysUntil(plan.deadline);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => PlanDetailScreen(planId: plan.id),
        ),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  plan.isPersonal
                      ? CupertinoIcons.person
                      : CupertinoIcons.person_2_fill,
                  size: 16,
                  color: plan.isPersonal
                      ? AppColors.textSecondary
                      : AppColors.moneyGreen,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(plan.scopeLabel, style: AppTextStyles.caption),
                ),
                if (remainingDays != null)
                  Text(
                    remainingDays >= 0
                        ? '$remainingDays days left'
                        : 'Past deadline',
                    style: TextStyle(
                      fontSize: 12,
                      color: remainingDays >= 0
                          ? AppColors.textSecondary
                          : AppColors.statusNegative,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPeso(plan.targetAmount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.moneyGreen,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text('target', style: AppTextStyles.caption),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlassProgressIndicator.linear(
              value: plan.allocationProgress,
              height: 6,
            ),
            const SizedBox(height: 6),
            Text(
              plan.isFullyAllocated
                  ? 'Fully budgeted across ${plan.categories.length} categories'
                  : plan.isOverAllocated
                  ? 'Over budget by ${formatPeso(plan.unallocated.abs())}'
                  : '${formatPeso(plan.unallocated)} still unbudgeted',
              style: TextStyle(
                fontSize: 12,
                color: plan.isOverAllocated
                    ? AppColors.statusWarning
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlansEmptyState extends StatelessWidget {
  final String scope;

  const _PlansEmptyState({required this.scope});

  @override
  Widget build(BuildContext context) {
    final message = scope == 'personal'
        ? 'You have no personal plans yet. Create one to start saving toward a goal of your own.'
        : scope == 'group'
        ? 'None of your groups have a plan yet. Create one to budget a trip or project together.'
        : 'No plans yet. Create one to set a target amount and let Ipon suggest how to budget it.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.chart_pie,
              size: 56,
              color: AppColors.moneyGreen,
            ),
            const SizedBox(height: 16),
            const Text('Nothing to show', style: AppTextStyles.screenTitle),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 24),
            PrimaryGlassButton(
              label: 'Create a Plan',
              icon: CupertinoIcons.add,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const PlanCreateScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlansErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PlansErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: AppColors.statusWarning,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.caption),
            const SizedBox(height: 20),
            PrimaryGlassButton(
              label: 'Try Again',
              icon: CupertinoIcons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}