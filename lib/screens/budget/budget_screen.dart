import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/budget.dart';
import '../../core/models/group.dart';
import '../../core/models/plan.dart' show formatPeso;
import '../../core/providers/budgets_provider.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/primary_glass_button.dart';
import '../dashboard/dashboard_screen.dart' show kAppBarClearance, kChartTrack;

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  int? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final groups = groupsAsync.value ?? const <Group>[];
    final budgetAsync = ref.watch(budgetProvider(_selectedGroupId));

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        title: const Text('Budget'),
        leading: GlassButton(
          icon: const Icon(CupertinoIcons.back),
          label: 'Back',
          width: 40,
          height: 40,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () =>
                  ref.read(budgetProvider(_selectedGroupId).notifier).refresh(),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: kAppBarClearance),
                  const _SectionLabel('Scope'),
                  GlassGroupedSection(
                    children: [
                      GlassListTile(
                        leading: const Icon(
                          CupertinoIcons.person,
                          color: AppColors.moneyGreen,
                        ),
                        title: const Text('Personal'),
                        subtitle: const Text('Your own spending limit'),
                        trailing: _selectedGroupId == null
                            ? const Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          color: AppColors.moneyGreen,
                        )
                            : null,
                        onTap: () => setState(() => _selectedGroupId = null),
                      ),
                      ...groups.map(
                            (group) => GlassListTile(
                          leading: const Icon(
                            CupertinoIcons.person_2_fill,
                            color: AppColors.moneyGreen,
                          ),
                          title: Text(group.name),
                          subtitle: Text(group.memberLabel),
                          trailing: _selectedGroupId == group.id
                              ? const Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            color: AppColors.moneyGreen,
                          )
                              : null,
                          onTap: () =>
                              setState(() => _selectedGroupId = group.id),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildBudgetSection(budgetAsync),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSection(AsyncValue<Budget> budgetAsync) {
    if (budgetAsync.hasError && !budgetAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Could not load this budget. Pull down to try again.',
          style: AppTextStyles.caption,
        ),
      );
    }

    final value = budgetAsync.value;
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: GlassProgressIndicator.circular(size: 24)),
      );
    }

    return _BudgetContent(
      key: ValueKey(_selectedGroupId),
      budget: value,
      groupId: _selectedGroupId,
    );
  }
}
class _BudgetContent extends ConsumerStatefulWidget {
  final Budget budget;
  final int? groupId;

  const _BudgetContent({super.key, required this.budget, required this.groupId});

  @override
  ConsumerState<_BudgetContent> createState() => _BudgetContentState();
}

class _BudgetContentState extends ConsumerState<_BudgetContent> {
  bool _isEditing = false;
  late final TextEditingController _limitController;
  late final TextEditingController _cycleDayController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(
      text: widget.budget.hasBudget
          ? widget.budget.limitAmount.toStringAsFixed(2)
          : '',
    );
    _cycleDayController = TextEditingController(
      text: widget.budget.hasBudget ? '${widget.budget.cycleStartDay}' : '1',
    );
    _isEditing = !widget.budget.hasBudget;
  }

  @override
  void dispose() {
    _limitController.dispose();
    _cycleDayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final limit = double.tryParse(_limitController.text.replaceAll(',', '').trim());
    if (limit == null || limit <= 0) {
      setState(() => _errorMessage = 'Enter a spending limit greater than zero.');
      return;
    }

    final cycleDay = int.tryParse(_cycleDayController.text.trim()) ?? 1;
    if (cycleDay < 1 || cycleDay > 31) {
      setState(() => _errorMessage = 'Cycle start day must be between 1 and 31.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final result = await ref.read(budgetProvider(widget.groupId).notifier).save(
      limitAmount: limit,
      cycleStartDay: cycleDay,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!result.ok) {
      setState(() => _errorMessage = result.message);
      return;
    }

    setState(() => _isEditing = false);
    GlassToast.show(
      context,
      message: result.message,
      type: GlassToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildForm();
    }
    return _buildPacing();
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          widget.budget.hasBudget ? 'Edit limit' : 'Set a spending limit',
        ),
        GlassTextField(
          controller: _limitController,
          placeholder: 'Spending limit (e.g. 10000)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          enabled: !_isSaving,
          prefixIcon: const Icon(
            CupertinoIcons.money_dollar,
            color: AppColors.moneyGreen,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        const SizedBox(height: 10),
        GlassTextField(
          controller: _cycleDayController,
          placeholder: 'Cycle start day (1 = calendar month)',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          enabled: !_isSaving,
          maxLength: 2,
          prefixIcon: const Icon(
            CupertinoIcons.calendar,
            color: AppColors.moneyGreen,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Your cycle runs for about 30 days starting on this day of the '
              'month. Leave it at 1 to follow the calendar month.',
          style: AppTextStyles.caption,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                color: AppColors.statusNegative,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.statusNegative,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        PrimaryGlassButton(
          label: widget.budget.hasBudget ? 'Save Changes' : 'Set Budget',
          icon: CupertinoIcons.check_mark,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
        if (widget.budget.hasBudget) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _isSaving ? null : () => setState(() => _isEditing = false),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Cancel',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPacing() {
    final pacing = widget.budget.pacing;
    if (pacing == null) {
      return _buildForm();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('This cycle')),
            GestureDetector(
              onTap: () => setState(() => _isEditing = true),
              child: const Text(
                'Edit limit',
                style: TextStyle(fontSize: 13, color: AppColors.moneyGreen),
              ),
            ),
          ],
        ),
        _HeroCard(pacing: pacing),
        const SizedBox(height: 18),
        const _SectionLabel('Pacing breakdown'),
        _PacingRow(label: 'Today', window: pacing.today),
        const SizedBox(height: 8),
        _PacingRow(label: 'Last 7 days', window: pacing.last7Days),
        const SizedBox(height: 8),
        _PacingRow(label: 'Last 15 days', window: pacing.last15Days),
        const SizedBox(height: 8),
        _PacingRow(label: 'This cycle so far', window: pacing.cycleToDate),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final BudgetPacing pacing;

  const _HeroCard({required this.pacing});

  @override
  Widget build(BuildContext context) {
    final overBy = pacing.projectedOver;
    final isProjectedOver = overBy > 0.01;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Spent so far', style: AppTextStyles.caption),
              Text(
                '${pacing.daysElapsed}/${pacing.cycleLength} days',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatPeso(pacing.spentTotal)} / ${formatPeso(pacing.limitAmount)}',
            style: AppTextStyles.heroValue,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: kChartTrack,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pacing.limitAmount > 0
                    ? (pacing.spentTotal / pacing.limitAmount).clamp(0.0, 1.0)
                    : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: pacing.isOverLimit
                        ? AppColors.statusNegative
                        : AppColors.moneyGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isProjectedOver
                    ? CupertinoIcons.exclamationmark_triangle_fill
                    : CupertinoIcons.checkmark_seal_fill,
                size: 16,
                color: isProjectedOver
                    ? AppColors.statusWarning
                    : AppColors.moneyGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isProjectedOver
                      ? 'At this pace, you will go over by ${formatPeso(overBy)} by the end of the cycle.'
                      : 'At this pace, you will stay within your limit this cycle.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PacingRow extends StatelessWidget {
  final String label;
  final BudgetPacingWindow window;

  const _PacingRow({required this.label, required this.window});

  @override
  Widget build(BuildContext context) {
    final color = window.isOver
        ? AppColors.statusNegative
        : (window.isUnder ? AppColors.moneyGreen : AppColors.textSecondary);

    final percentLabel = window.isOver
        ? '${window.percentVsPace.abs().toStringAsFixed(0)}% over pace'
        : window.isUnder
        ? '${window.percentVsPace.abs().toStringAsFixed(0)}% under pace'
        : 'On pace';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${formatPeso(window.actual)} of ${formatPeso(window.expected)} expected',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Text(
            percentLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: AppTextStyles.sectionLabel),
    );
  }
}