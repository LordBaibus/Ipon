import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/group.dart';
import '../../core/models/plan.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/providers/plans_provider.dart';
import '../../widgets/primary_glass_button.dart';

class PlanCreateScreen extends ConsumerStatefulWidget {
  const PlanCreateScreen({super.key});

  @override
  ConsumerState<PlanCreateScreen> createState() => _PlanCreateScreenState();
}

class _PlanCreateScreenState extends ConsumerState<PlanCreateScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _deadlineController = TextEditingController();

  String _planType = 'trip';
  int? _groupId;
  bool _isSaving = false;
  String? _errorMessage;
  List<PlanCategory> _categories = const [];
  bool _categoriesEdited = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  double get _targetAmount {
    final cleaned = _targetController.text.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  double get _allocatedTotal {
    var total = 0.0;
    for (final category in _categories) {
      total += category.amount;
    }
    return total;
  }
  void _recalculatePreview(List<PlanTemplate> templates) {
    if (_categoriesEdited) return;
    PlanTemplate? template;
    for (final candidate in templates) {
      if (candidate.key == _planType) {
        template = candidate;
        break;
      }
    }

    if (template == null) {
      setState(() => _categories = const []);
      return;
    }

    final chosen = template;
    setState(() => _categories = chosen.allocate(_targetAmount));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Give your plan a name.');
      return;
    }
    if (_targetAmount <= 0) {
      setState(() => _errorMessage = 'Enter a target amount greater than zero.');
      return;
    }

    final deadline = _deadlineController.text.trim();
    if (deadline.isNotEmpty && DateTime.tryParse(deadline) == null) {
      setState(() => _errorMessage = 'Deadline must look like 2026-12-20.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final result = await ref.read(plansProvider.notifier).createPlan(
      name: name,
      planType: _planType,
      targetAmount: _targetAmount,
      groupId: _groupId,
      deadline: deadline.isEmpty ? null : deadline,
      categories: _categoriesEdited ? _categories : null,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!result.ok) {
      setState(() => _errorMessage = result.message);
      return;
    }

    GlassToast.show(
      context,
      message: result.message,
      type: GlassToastType.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(planTemplatesProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final templates = templatesAsync.value ?? const <PlanTemplate>[];
    final groups = groupsAsync.value ?? const <Group>[];

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(title: const Text('New Plan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            const _SectionLabel('Plan details'),
            GlassTextField(
              controller: _nameController,
              placeholder: 'Plan name (e.g. Baguio Trip)',
              textInputAction: TextInputAction.next,
              enabled: !_isSaving,
              prefixIcon: const Icon(CupertinoIcons.textformat),
            ),
            const SizedBox(height: 10),
            GlassTextField(
              controller: _targetController,
              placeholder: 'Target amount',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              enabled: !_isSaving,
              prefixIcon: const Icon(CupertinoIcons.money_dollar),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => _recalculatePreview(templates),
            ),
            const SizedBox(height: 10),
            GlassTextField(
              controller: _deadlineController,
              placeholder: 'Deadline (optional) — YYYY-MM-DD',
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.done,
              enabled: !_isSaving,
              maxLength: 10,
              prefixIcon: const Icon(CupertinoIcons.calendar),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              ],
            ),

            const SizedBox(height: 22),
            const _SectionLabel('Who is this for?'),
            GlassGroupedSection(
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.person),
                  title: const Text('Just me'),
                  subtitle: const Text('A personal savings plan'),
                  trailing: _groupId == null
                      ? const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: CupertinoColors.activeGreen,
                  )
                      : null,
                  onTap: _isSaving ? null : () => setState(() => _groupId = null),
                ),
                ...groups.map(
                      (group) => GlassListTile(
                    leading: const Icon(CupertinoIcons.person_2_fill),
                    title: Text(group.name),
                    subtitle: Text(group.memberLabel),
                    trailing: _groupId == group.id
                        ? const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: CupertinoColors.activeGreen,
                    )
                        : null,
                    onTap: _isSaving
                        ? null
                        : () => setState(() => _groupId = group.id),
                  ),
                ),
              ],
            ),
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'You are not in any group yet. Personal plans work on '
                      'their own — join or create a group from the Groups tab '
                      'if you want to budget with other people.',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
              ),

            const SizedBox(height: 22),
            const _SectionLabel('Plan type'),
            if (templatesAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: GlassProgressIndicator.circular(size: 22)),
              )
            else
              GlassGroupedSection(
                children: templates
                    .map((template) => GlassListTile(
                  title: Text(template.label),
                  subtitle: Text(template.description),
                  trailing: _planType == template.key
                      ? const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: CupertinoColors.activeGreen,
                  )
                      : null,
                  onTap: _isSaving
                      ? null
                      : () {
                    setState(() {
                      _planType = template.key;
                      // Switching type restarts the
                      // suggestion from scratch.
                      _categoriesEdited = false;
                    });
                    _recalculatePreview(templates);
                  },
                ))
                    .toList(),
              ),

            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(child: _SectionLabel('Suggested budget')),
                if (_categoriesEdited)
                  GestureDetector(
                    onTap: () {
                      setState(() => _categoriesEdited = false);
                      _recalculatePreview(templates);
                    },
                    child: const Text(
                      'Reset to suggestion',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_targetAmount <= 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Enter a target amount to see the suggested split.',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
              )
            else if (_categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'This plan type starts with no categories. You can add '
                      'them after creating the plan.',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
              )
            else ...[
                ..._categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CategoryAmountRow(
                      category: category,
                      target: _targetAmount,
                      enabled: !_isSaving,
                      onAmountChanged: (value) {
                        setState(() {
                          _categoriesEdited = true;
                          _categories = List<PlanCategory>.from(_categories);
                          _categories[index] =
                              category.copyWith(amount: value);
                        });
                      },
                    ),
                  );
                }),
                const SizedBox(height: 6),
                _AllocationSummary(
                  target: _targetAmount,
                  allocated: _allocatedTotal,
                ),
              ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_circle,
                    color: CupertinoColors.systemRed,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 22),
            PrimaryGlassButton(
              label: 'Create Plan',
              icon: CupertinoIcons.check_mark,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryAmountRow extends StatefulWidget {
  final PlanCategory category;
  final double target;
  final bool enabled;
  final ValueChanged<double> onAmountChanged;

  const _CategoryAmountRow({
    required this.category,
    required this.target,
    required this.enabled,
    required this.onAmountChanged,
  });

  @override
  State<_CategoryAmountRow> createState() => _CategoryAmountRowState();
}

class _CategoryAmountRowState extends State<_CategoryAmountRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.category.amount.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(covariant _CategoryAmountRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.category.amount.toStringAsFixed(2);
    final current = double.tryParse(_controller.text) ?? -1;
    if ((current - widget.category.amount).abs() > 0.001) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = widget.category.percentOf(widget.target);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
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
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: GlassTextField(
              controller: _controller,
              placeholder: '0.00',
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (value) {
                final parsed = double.tryParse(value) ?? 0.0;
                widget.onAmountChanged(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationSummary extends StatelessWidget {
  final double target;
  final double allocated;

  const _AllocationSummary({required this.target, required this.allocated});

  @override
  Widget build(BuildContext context) {
    final difference = target - allocated;
    final isBalanced = difference.abs() < 0.01;
    final isOver = difference < -0.01;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Allocated',
                style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey2),
              ),
              Text(
                '${formatPeso(allocated)} / ${formatPeso(target)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isBalanced
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.exclamationmark_circle,
                size: 16,
                color: isBalanced
                    ? CupertinoColors.activeGreen
                    : (isOver
                    ? CupertinoColors.systemRed
                    : CupertinoColors.systemOrange),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isBalanced
                      ? 'Everything is budgeted.'
                      : isOver
                      ? 'Over the target by ${formatPeso(difference.abs())}.'
                      : '${formatPeso(difference)} not yet budgeted.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isBalanced
                        ? CupertinoColors.activeGreen
                        : (isOver
                        ? CupertinoColors.systemRed
                        : CupertinoColors.systemOrange),
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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }
}