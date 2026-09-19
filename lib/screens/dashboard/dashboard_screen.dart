import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/dashboard.dart';
import '../../core/models/plan.dart' show formatPeso;
import '../../core/providers/auth_provider.dart';
import '../../core/providers/dashboard_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/primary_glass_button.dart';
import '../expenses/expense_detail_screen.dart';

const Color kChartAccent = AppColors.moneyGreen;
const Color kChartTrack = Color(0x1AFFFFFF);
const double kAppBarClearance = 56;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _scopes = ['all', 'personal', 'group'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardProvider);
    final scope = ref.watch(dashboardScopeProvider);
    final scopeIndex = _scopes.indexOf(scope).clamp(0, _scopes.length - 1);
    final user = ref.watch(currentUserProvider);

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        title: const Text('Dashboard'),
        actions: [
          GlassButton(
            icon: const Icon(
              CupertinoIcons.refresh,
              color: AppColors.moneyGreen,
            ),
            onTap: () => ref.invalidate(dashboardProvider),
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
                  ref.read(dashboardScopeProvider.notifier).state =
                  _scopes[index];
                },
                segments: const [
                  GlassSegment(label: 'All'),
                  GlassSegment(label: 'Personal'),
                  GlassSegment(label: 'Group'),
                ],
              ),
            ),
            Expanded(
              child: summaryAsync.when(
                loading: () => const Center(
                  child: GlassProgressIndicator.circular(size: 28),
                ),
                error: (error, _) => _DashboardError(
                  message: error.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => ref.invalidate(dashboardProvider),
                ),
                data: (summary) => summary.isEmpty
                    ? const _DashboardEmpty()
                    : _DashboardBody(
                  summary: summary,
                  greetingName: user?.firstName,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DashboardSummary summary;
  final String? greetingName;

  const _DashboardBody({required this.summary, this.greetingName});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greetingName == null
                    ? 'Total spent'
                    : 'Total spent, $greetingName',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 6),
              Text(
                formatPeso(summary.totalSpent),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: AppColors.moneyGreen,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      value: '${summary.expenseCount}',
                      label: summary.expenseCount == 1 ? 'expense' : 'expenses',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      value: '${summary.ocrCount}',
                      label: 'from receipts',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (summary.byCategory.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionLabel('Where the money went'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < summary.byCategory.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == summary.byCategory.length - 1 ? 0 : 14,
                    ),
                    child: _CategoryBar(
                      slice: summary.byCategory[i],
                      maxTotal: summary.byCategory.first.total,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (summary.byMonth.length > 1) ...[
          const SizedBox(height: 22),
          const _SectionLabel('Month by month'),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: _MonthlyTrend(
              points: summary.byMonth,
              peak: summary.peakMonthTotal,
            ),
          ),
        ],
        if (summary.planProgress.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionLabel('Plans against their budget'),
          for (final plan in summary.planProgress)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanMeter(plan: plan),
            ),
        ],
        if (summary.recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel('Recent activity'),
          GlassGroupedSection(
            children: summary.recent
                .map((expense) => GlassListTile(
              leading: Icon(
                expense.isFromReceipt
                    ? CupertinoIcons.doc_text_viewfinder
                    : CupertinoIcons.money_dollar_circle,
                color: AppColors.moneyGreen,
              ),
              title: Text(expense.displayTitle),
              subtitle: Text(
                '${expense.expenseDate} · '
                    '${expense.categoryLabel ?? expense.category}',
              ),
              trailing: Text(
                formatPeso(expense.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) =>
                      ExpenseDetailScreen(expense: expense),
                ),
              ),
            ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
class _StatTile extends StatelessWidget {
  final String value;
  final String label;

  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
class _CategoryBar extends StatelessWidget {
  final CategorySlice slice;
  final double maxTotal;

  const _CategoryBar({required this.slice, required this.maxTotal});

  @override
  Widget build(BuildContext context) {
    final fraction = maxTotal <= 0 ? 0.0 : (slice.total / maxTotal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                slice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatPeso(slice.total),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            color: kChartTrack,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.moneyGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${slice.sharePercent.toStringAsFixed(1)}% of spending'
              '${slice.count > 0 ? " · ${slice.count} ${slice.count == 1 ? "expense" : "expenses"}" : ""}',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
class _MonthlyTrend extends StatelessWidget {
  final List<MonthPoint> points;
  final double peak;

  const _MonthlyTrend({required this.points, required this.peak});

  @override
  Widget build(BuildContext context) {
    // Only the most recent months fit comfortably across a phone.
    final visible =
    points.length <= 8 ? points : points.sublist(points.length - 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < visible.length; i++)
                Expanded(
                  child: Padding(
                    // 2px each side = a 4px gutter between columns.
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _TrendColumn(
                      point: visible[i],
                      peak: peak,
                      showValue: peak > 0 && visible[i].total >= peak,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final point in visible)
              Expanded(
                child: Text(
                  point.shortLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrendColumn extends StatelessWidget {
  final MonthPoint point;
  final double peak;
  final bool showValue;

  const _TrendColumn({
    required this.point,
    required this.peak,
    required this.showValue,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = peak <= 0 ? 0.0 : (point.total / peak).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showValue)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              formatPeso(point.total, withSymbol: false),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: fraction == 0 ? 0.02 : fraction,
            child: Container(
              decoration: BoxDecoration(
                color: fraction == 0 ? kChartTrack : AppColors.moneyGreen,
                // Rounded top only: the column is anchored to its
                // baseline, so the bottom stays square.
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
class _PlanMeter extends StatelessWidget {
  final PlanProgress plan;

  const _PlanMeter({required this.plan});

  @override
  Widget build(BuildContext context) {
    // The status colour never travels alone: an icon and a sentence say
    // the same thing.
    final isOver = plan.isOverspent;
    final statusColor =
    isOver ? AppColors.statusNegative : AppColors.textSecondary;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(plan.scopeLabel, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: kChartTrack,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: plan.progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: isOver
                        ? AppColors.statusNegative
                        : AppColors.moneyGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOver) ...[
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 13,
                  color: AppColors.statusNegative,
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  isOver
                      ? 'Over budget by ${formatPeso(plan.remaining.abs())} — '
                      '${formatPeso(plan.spent)} spent of '
                      '${formatPeso(plan.targetAmount)}'
                      : '${formatPeso(plan.spent)} spent of '
                      '${formatPeso(plan.targetAmount)} · '
                      '${formatPeso(plan.remaining)} left',
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              CupertinoIcons.chart_bar,
              size: 56,
              color: AppColors.moneyGreen,
            ),
            SizedBox(height: 16),
            Text(
              'Nothing to chart yet',
              style: AppTextStyles.screenTitle,
            ),
            SizedBox(height: 8),
            Text(
              'Once you log a few expenses, this is where you will see '
                  'where your money goes and how your plans are tracking.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({required this.message, required this.onRetry});

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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(), style: AppTextStyles.sectionLabel),
    );
  }
}