import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/plan.dart';
import '../../core/providers/plans_provider.dart';
import '../../widgets/primary_glass_button.dart';

class PlanDetailScreen extends ConsumerStatefulWidget {
  final int planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  /// Working copy while editing. Null means "not editing".
  List<PlanCategory>? _draftCategories;
  bool _isSaving = false;

  bool get _isEditing => _draftCategories != null;

  double get _draftTotal {
    var total = 0.0;
    for (final category in _draftCategories ?? const <PlanCategory>[]) {
      total += category.amount;
    }
    return total;
  }

  void _startEditing(Plan plan) {
    setState(() => _draftCategories = List<PlanCategory>.from(plan.categories));
  }

  void _cancelEditing() {
    setState(() => _draftCategories = null);
  }

  Future<void> _saveCategories() async {
    final draft = _draftCategories;
    if (draft == null) return;

    for (final category in draft) {
      if (category.label.trim().isEmpty) {
        GlassToast.show(
          context,
          message: 'Every category needs a name.',
          type: GlassToastType.error,
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final result = await ref.read(plansProvider.notifier).updatePlan(
      planId: widget.planId,
      categories: draft,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    GlassToast.show(
      context,
      message: result.message,
      type: result.ok ? GlassToastType.success : GlassToastType.error,
    );

    if (result.ok) setState(() => _draftCategories = null);
  }

  Future<void> _reapplyTemplate() async {
    setState(() => _isSaving = true);

    final result = await ref.read(plansProvider.notifier).updatePlan(
      planId: widget.planId,
      reapplyTemplate: true,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (result.ok) _draftCategories = null;
    });

    GlassToast.show(
      context,
      message: result.ok
          ? 'Budget reset to the suggested split.'
          : result.message,
      type: result.ok ? GlassToastType.success : GlassToastType.error,
    );
  }

  void _confirmDelete(Plan plan) {
    GlassDialog.show<void>(
      context: context,
      title: 'Delete Plan',
      message: 'Delete "${plan.name}" and its budget? This cannot be undone.',
      barrierDismissible: true,
      actions: [
        GlassDialogAction(
          label: 'Delete',
          isDestructive: true,
          onPressed: () async {
            Navigator.of(context).pop();

            final result =
            await ref.read(plansProvider.notifier).deletePlan(plan.id);

            if (!mounted) return;

            GlassToast.show(
              context,
              message: result.message,
              type: result.ok ? GlassToastType.success : GlassToastType.error,
            );

            if (result.ok) Navigator.of(context).pop();
          },
        ),
        GlassDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planDetailProvider(widget.planId));

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        title: const Text('Plan'),
        actions: [
          if (planAsync.value != null && !_isEditing)
            GlassButton(
              icon: const Icon(CupertinoIcons.ellipsis),
              onTap: () => _showActions(planAsync.value!),
            ),
        ],
      ),
      body: SafeArea(
        child: planAsync.when(
          loading: () => const Center(
            child: GlassProgressIndicator.circular(size: 28),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                error.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
          ),
          data: (plan) => _buildBody(plan),
        ),
      ),
    );
  }

  void _showActions(Plan plan) {
    GlassDialog.show<void>(
      context: context,
      title: plan.name,
      message: plan.notes?.isNotEmpty == true ? plan.notes : null,
      barrierDismissible: true,
      actions: [
        GlassDialogAction(
          label: 'Edit Budget',
          isPrimary: true,
          onPressed: () {
            Navigator.of(context).pop();
            _startEditing(plan);
          },
        ),
        GlassDialogAction(
          label: 'Reset to Suggestion',
          onPressed: () {
            Navigator.of(context).pop();
            _reapplyTemplate();
          },
        ),
        if (plan.isOwner)
          GlassDialogAction(
            label: 'Delete Plan',
            isDestructive: true,
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDelete(plan);
            },
          ),
      ],
    );
  }

  Widget _buildBody(Plan plan) {
    final categories = _draftCategories ?? plan.categories;
    final allocated = _isEditing ? _draftTotal : plan.allocatedTotal;
    final remainingDays = daysUntil(plan.deadline);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    plan.isPersonal
                        ? CupertinoIcons.person
                        : CupertinoIcons.person_2_fill,
                    size: 15,
                    color: CupertinoColors.systemGrey2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    plan.scopeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                formatPeso(plan.targetAmount),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.activeGreen,
                ),
              ),
              const Text(
                'target amount',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
              if (remainingDays != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.calendar,
                      size: 14,
                      color: CupertinoColors.systemGrey2,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      remainingDays >= 0
                          ? 'Due ${plan.deadline} · $remainingDays days left'
                          : 'Deadline ${plan.deadline} has passed',
                      style: TextStyle(
                        fontSize: 12,
                        color: remainingDays >= 0
                            ? CupertinoColors.systemGrey2
                            : CupertinoColors.systemRed,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'BUDGET BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
            if (_isEditing)
              GestureDetector(
                onTap: _isSaving
                    ? null
                    : () => setState(() {
                  _draftCategories = [
                    ...?_draftCategories,
                    const PlanCategory(label: '', amount: 0),
                  ];
                }),
                child: const Text(
                  '+ Add category',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'This plan has no categories yet. Use Edit Budget to add '
                  'them, or Reset to Suggestion to apply the template.',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.systemGrey2,
              ),
            ),
          )
        else
          ...categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _isEditing
                  ? _EditableCategoryRow(
                key: ValueKey('edit-$index'),
                category: category,
                enabled: !_isSaving,
                onChanged: (updated) {
                  setState(() {
                    final next =
                    List<PlanCategory>.from(_draftCategories!);
                    next[index] = updated;
                    _draftCategories = next;
                  });
                },
                onRemove: () {
                  setState(() {
                    final next =
                    List<PlanCategory>.from(_draftCategories!);
                    next.removeAt(index);
                    _draftCategories = next;
                  });
                },
              )
                  : _ReadOnlyCategoryRow(
                category: category,
                target: plan.targetAmount,
              ),
            );
          }),
        const SizedBox(height: 6),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Allocated',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                  Text(
                    '${formatPeso(allocated)} / ${formatPeso(plan.targetAmount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GlassProgressIndicator.linear(
                value: plan.targetAmount <= 0
                    ? 0
                    : (allocated / plan.targetAmount).clamp(0.0, 1.0),
                height: 6,
              ),
            ],
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 20),
          PrimaryGlassButton(
            label: 'Save Budget',
            icon: CupertinoIcons.check_mark,
            isLoading: _isSaving,
            onPressed: _saveCategories,
          ),
          SubtleGlassLink(
            label: 'Cancel',
            onPressed: _isSaving ? null : _cancelEditing,
          ),
        ] else ...[
          const SizedBox(height: 20),
          PrimaryGlassButton(
            label: 'Edit Budget',
            icon: CupertinoIcons.pencil,
            onPressed: () => _startEditing(plan),
          ),
        ],
      ],
    );
  }
}

class _ReadOnlyCategoryRow extends StatelessWidget {
  final PlanCategory category;
  final double target;

  const _ReadOnlyCategoryRow({required this.category, required this.target});

  @override
  Widget build(BuildContext context) {
    final percent = category.percentOf(target);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${percent.toStringAsFixed(1)}% of target',
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPeso(category.amount),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.activeGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableCategoryRow extends StatefulWidget {
  final PlanCategory category;
  final bool enabled;
  final ValueChanged<PlanCategory> onChanged;
  final VoidCallback onRemove;

  const _EditableCategoryRow({
    super.key,
    required this.category,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_EditableCategoryRow> createState() => _EditableCategoryRowState();
}

class _EditableCategoryRowState extends State<_EditableCategoryRow> {
  late final TextEditingController _labelController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.category.label);
    _amountController = TextEditingController(
      text: widget.category.amount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: GlassTextField(
              controller: _labelController,
              placeholder: 'Category name',
              enabled: widget.enabled,
              onChanged: (value) => widget.onChanged(
                widget.category.copyWith(label: value),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: GlassTextField(
              controller: _amountController,
              placeholder: '0.00',
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (value) => widget.onChanged(
                widget.category.copyWith(amount: double.tryParse(value) ?? 0.0),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.enabled ? widget.onRemove : null,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                CupertinoIcons.minus_circle,
                size: 20,
                color: CupertinoColors.systemRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}