import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/expense.dart';
import '../../core/models/group.dart';
import '../../core/models/plan.dart' show formatPeso;
import '../../core/providers/expenses_provider.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/services/expenses_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/primary_glass_button.dart';
import '../dashboard/dashboard_screen.dart' show kAppBarClearance;
import 'expense_create_screen.dart';
import 'expense_detail_screen.dart';

class ExpensesListScreen extends ConsumerStatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  ConsumerState<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends ConsumerState<ExpensesListScreen> {
  static const _scopes = ['all', 'personal', 'group'];

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setScope(int index) {
    final filters = ref.read(expenseFiltersProvider);
    ref.read(expenseFiltersProvider.notifier).state =
        filters.copyWith(scope: _scopes[index]);
  }

  void _applySearch(String value) {
    final filters = ref.read(expenseFiltersProvider);
    final trimmed = value.trim();

    ref.read(expenseFiltersProvider.notifier).state = trimmed.isEmpty
        ? filters.copyWith(clearSearch: true)
        : filters.copyWith(search: trimmed);
  }

  void _clearFilters() {
    final filters = ref.read(expenseFiltersProvider);
    _searchController.clear();
    ref.read(expenseFiltersProvider.notifier).state = ExpenseFilters(
      scope: filters.scope,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(expenseLedgerProvider);
    final filters = ref.watch(expenseFiltersProvider);
    final scopeIndex = _scopes.indexOf(filters.scope).clamp(0, _scopes.length - 1);

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        title: const Text('Expenses'),
        actions: [
          GlassButton(
            icon: const Icon(
              CupertinoIcons.slider_horizontal_3,
              color: AppColors.moneyGreen,
            ),
            onTap: () => _showFilterSheet(context, filters),
          ),
          GlassButton(
            icon: const Icon(
              CupertinoIcons.add,
              color: AppColors.moneyGreen,
            ),
            onTap: () async {
              await Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const ExpenseCreateScreen()),
              );
              if (mounted) ref.read(expenseLedgerProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: kAppBarClearance),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  GlassSegmentedControl(
                    selectedIndex: scopeIndex,
                    onSegmentSelected: _setScope,
                    segments: const [
                      GlassSegment(label: 'All'),
                      GlassSegment(label: 'Personal'),
                      GlassSegment(label: 'Group'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _searchController,
                    placeholder: 'Search merchant, notes, or category',
                    prefixIcon: const Icon(
                      CupertinoIcons.search,
                      color: AppColors.moneyGreen,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _applySearch,
                  ),
                ],
              ),
            ),

            if (filters.hasActiveFilters)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.line_horizontal_3_decrease,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Filters are narrowing this list',
                        style: AppTextStyles.caption,
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.moneyGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ledgerAsync.when(
                loading: () => const Center(
                  child: GlassProgressIndicator.circular(size: 28),
                ),
                error: (error, _) => _LedgerError(
                  message: error.toString().replaceFirst('Exception: ', ''),
                  onRetry: () =>
                      ref.read(expenseLedgerProvider.notifier).refresh(),
                ),
                data: (page) => page.isEmpty
                    ? _LedgerEmpty(hasFilters: filters.hasActiveFilters)
                    : _LedgerBody(page: page),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, ExpenseFilters filters) {
    final groups = ref.read(groupsProvider).value ?? const <Group>[];

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filter Expenses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const _FilterLabel('Entry type'),
                  GlassGroupedSection(
                    children: [
                      _filterRow(
                        label: 'Any',
                        selected: filters.source == null,
                        onTap: () => _setSource(dialogContext, null),
                      ),
                      _filterRow(
                        label: 'Typed by hand',
                        selected: filters.source == 'manual',
                        onTap: () => _setSource(dialogContext, 'manual'),
                      ),
                      _filterRow(
                        label: 'Scanned from a receipt',
                        selected: filters.source == 'ocr',
                        onTap: () => _setSource(dialogContext, 'ocr'),
                      ),
                    ],
                  ),

                  if (groups.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _FilterLabel('Group'),
                    GlassGroupedSection(
                      children: [
                        _filterRow(
                          label: 'Any group',
                          selected: filters.groupId == null,
                          onTap: () => _setGroup(dialogContext, null),
                        ),
                        ...groups.map(
                              (group) => _filterRow(
                            label: group.name,
                            selected: filters.groupId == group.id,
                            onTap: () => _setGroup(dialogContext, group.id),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),
                  PrimaryGlassButton(
                    label: 'Done',
                    icon: CupertinoIcons.check_mark,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                  SubtleGlassLink(
                    label: 'Clear all filters',
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _clearFilters();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GlassListTile(
      title: Text(label),
      trailing: selected
          ? const Icon(
        CupertinoIcons.checkmark_circle_fill,
        color: AppColors.moneyGreen,
      )
          : null,
      onTap: onTap,
    );
  }

  void _setSource(BuildContext dialogContext, String? source) {
    final filters = ref.read(expenseFiltersProvider);
    ref.read(expenseFiltersProvider.notifier).state = source == null
        ? filters.copyWith(clearSource: true)
        : filters.copyWith(source: source);
    Navigator.of(dialogContext).pop();
  }

  void _setGroup(BuildContext dialogContext, int? groupId) {
    final filters = ref.read(expenseFiltersProvider);
    ref.read(expenseFiltersProvider.notifier).state = groupId == null
        ? filters.copyWith(clearGroup: true)
        : filters.copyWith(groupId: groupId);
    Navigator.of(dialogContext).pop();
  }
}

class _LedgerBody extends StatelessWidget {
  final ExpensePage page;

  const _LedgerBody({required this.page});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      // One extra row for the total header at the top.
      itemCount: page.expenses.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LedgerTotal(page: page),
          );
        }

        final expense = page.expenses[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ExpenseRow(expense: expense),
        );
      },
    );
  }
}
class _LedgerTotal extends StatelessWidget {
  final ExpensePage page;

  const _LedgerTotal({required this.page});

  @override
  Widget build(BuildContext context) {
    final shown = page.expenses.length;
    final countLabel = shown < page.totalCount
        ? 'showing $shown of ${page.totalCount}'
        : '${page.totalCount} ${page.totalCount == 1 ? "expense" : "expenses"}';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            formatPeso(page.totalAmount),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.moneyGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(countLabel, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final Expense expense;

  const _ExpenseRow({required this.expense});

  @override
  Widget build(BuildContext context) {
    final link = expense.linkLabel;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => ExpenseDetailScreen(expense: expense),
        ),
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expense.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (expense.isFromReceipt)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            CupertinoIcons.doc_text_viewfinder,
                            size: 13,
                            color: AppColors.moneyGreen,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    link ?? expense.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expense.isPersonal
                        ? expense.expenseDate
                        : '${expense.expenseDate} · '
                        '${expense.isMine ? "you paid" : "${expense.payerName ?? "someone"} paid"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatPeso(expense.amount),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerEmpty extends StatelessWidget {
  final bool hasFilters;

  const _LedgerEmpty({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.square_list,
              size: 56,
              color: AppColors.moneyGreen,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'Nothing matches' : 'No expenses yet',
              style: AppTextStyles.screenTitle,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try widening the filters, or clear them to see everything.'
                  : 'Add your first expense by typing it in, or scan a receipt '
                  'and let Ipon read it for you.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 24),
            PrimaryGlassButton(
              label: 'Add Expense',
              icon: CupertinoIcons.add,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const ExpenseCreateScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LedgerError({required this.message, required this.onRetry});

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

class _FilterLabel extends StatelessWidget {
  final String text;

  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: AppTextStyles.sectionLabel),
    );
  }
}