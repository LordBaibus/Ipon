import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/expense.dart';
import '../../core/models/plan.dart' show formatPeso;
import '../../core/providers/expenses_provider.dart';
import '../../widgets/primary_glass_button.dart';
import '../dashboard/dashboard_screen.dart' show kAppBarClearance;

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  late Expense _expense;

  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _categoryController;
  late final TextEditingController _dateController;
  late final TextEditingController _notesController;

  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;

    _amountController =
        TextEditingController(text: _expense.amount.toStringAsFixed(2));
    _merchantController = TextEditingController(text: _expense.merchant ?? '');
    _categoryController = TextEditingController(text: _expense.category);
    _dateController = TextEditingController(text: _expense.expenseDate);
    _notesController = TextEditingController(text: _expense.notes ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _categoryController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _errorMessage = null;
      _amountController.text = _expense.amount.toStringAsFixed(2);
      _merchantController.text = _expense.merchant ?? '';
      _categoryController.text = _expense.category;
      _dateController.text = _expense.expenseDate;
      _notesController.text = _expense.notes ?? '';
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final amount =
    double.tryParse(_amountController.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Enter an amount greater than zero.');
      return;
    }

    final date = _dateController.text.trim();
    if (date.isEmpty || DateTime.tryParse(date) == null) {
      setState(() => _errorMessage = 'Date must look like 2026-09-16.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final result = await ref.read(expenseActionsProvider).updateExpense(
      expenseId: _expense.id,
      amount: amount,
      merchant: _merchantController.text.trim(),
      category: _categoryController.text.trim(),
      expenseDate: date,
      notes: _notesController.text.trim(),
      // Keeping the existing links; changing them is done from the
      // plan screens, where the available budget lines are in view.
      groupId: _expense.groupId,
      planId: _expense.planId,
      planCategoryId: _expense.planCategoryId,
      previousPlanId: _expense.planId,
      previousGroupId: _expense.groupId,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!result.ok) {
      setState(() => _errorMessage = result.message);
      return;
    }

    setState(() {
      _isEditing = false;
      if (result.expense != null) _expense = result.expense!;
    });

    GlassToast.show(
      context,
      message: result.message,
      type: GlassToastType.success,
    );
  }

  void _confirmDelete() {
    GlassDialog.show<void>(
      context: context,
      title: 'Delete Expense',
      message:
      'Remove ${_expense.displayTitle} (${formatPeso(_expense.amount)})? '
          'This cannot be undone.',
      barrierDismissible: true,
      actions: [
        GlassDialogAction(
          label: 'Delete',
          isDestructive: true,
          onPressed: () async {
            Navigator.of(context).pop();

            final result = await ref.read(expenseActionsProvider).deleteExpense(
              expenseId: _expense.id,
              planId: _expense.planId,
            );

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
    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        title: const Text('Expense'),
        leading: GlassButton(
          icon: const Icon(CupertinoIcons.back),
          label: 'Back',
          width: 40,
          height: 40,
          enabled: !_isSaving,
          onTap: _isSaving ? () {} : () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isEditing && _expense.isMine)
            GlassButton(
              icon: const Icon(CupertinoIcons.pencil),
              onTap: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            const SizedBox(height: kAppBarClearance),
            if (_isEditing) ..._buildEditForm() else ..._buildReadOnly(),

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

            if (_isEditing) ...[
              PrimaryGlassButton(
                label: 'Save Changes',
                icon: CupertinoIcons.check_mark,
                isLoading: _isSaving,
                onPressed: _save,
              ),
              SubtleGlassLink(
                label: 'Cancel',
                onPressed: _isSaving ? null : _cancelEditing,
              ),
            ] else ...[
              PrimaryGlassButton(
                label: 'Delete Expense',
                icon: CupertinoIcons.delete,
                onPressed: _confirmDelete,
              ),
              if (!_expense.isMine)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'This expense was logged by someone else, so only they '
                        'can edit it. The group owner can still delete it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReadOnly() {
    return [
      GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _expense.isFromReceipt
                      ? CupertinoIcons.doc_text_viewfinder
                      : CupertinoIcons.pencil,
                  size: 14,
                  color: CupertinoColors.systemGrey2,
                ),
                const SizedBox(width: 6),
                Text(
                  _expense.isFromReceipt
                      ? 'Scanned from a receipt'
                      : 'Entered by hand',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _expense.displayTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              formatPeso(_expense.amount),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.activeGreen,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      GlassGroupedSection(
        children: [
          _DetailRow(label: 'Date', value: _expense.expenseDate),
          _DetailRow(
            label: 'Category',
            value: _expense.categoryLabel ?? _expense.category,
          ),
          _DetailRow(
            label: 'Belongs to',
            value: _expense.isPersonal
                ? 'Just you'
                : (_expense.groupName ?? 'A group'),
          ),
          if (_expense.planName != null)
            _DetailRow(label: 'Plan', value: _expense.planName!),
          _DetailRow(
            label: 'Paid by',
            value: _expense.isMine ? 'You' : (_expense.payerName ?? 'Unknown'),
          ),
          if (_expense.notes != null && _expense.notes!.isNotEmpty)
            _DetailRow(label: 'Notes', value: _expense.notes!),
        ],
      ),
    ];
  }

  List<Widget> _buildEditForm() {
    return [
      const _SectionLabel('Edit expense'),
      GlassTextField(
        controller: _amountController,
        placeholder: 'Amount',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        enabled: !_isSaving,
        prefixIcon: const Icon(CupertinoIcons.money_dollar),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
      ),
      const SizedBox(height: 10),
      GlassTextField(
        controller: _merchantController,
        placeholder: 'Merchant or description',
        textInputAction: TextInputAction.next,
        enabled: !_isSaving,
        prefixIcon: const Icon(CupertinoIcons.cart),
      ),
      const SizedBox(height: 10),
      GlassTextField(
        controller: _categoryController,
        placeholder: 'Category',
        textInputAction: TextInputAction.next,
        enabled: !_isSaving,
        prefixIcon: const Icon(CupertinoIcons.tag),
      ),
      const SizedBox(height: 10),
      GlassTextField(
        controller: _dateController,
        placeholder: 'Date — YYYY-MM-DD',
        keyboardType: TextInputType.datetime,
        textInputAction: TextInputAction.next,
        enabled: !_isSaving,
        maxLength: 10,
        prefixIcon: const Icon(CupertinoIcons.calendar),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        ],
      ),
      const SizedBox(height: 10),
      GlassTextField(
        controller: _notesController,
        placeholder: 'Notes (optional)',
        textInputAction: TextInputAction.done,
        enabled: !_isSaving,
        prefixIcon: const Icon(CupertinoIcons.text_alignleft),
      ),
      if (_expense.planName != null) ...[
        const SizedBox(height: 12),
        Text(
          'Still counting toward ${_expense.linkLabel}. To move it to a '
              'different plan or budget line, open the plan.',
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ],
    ];
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: CupertinoColors.systemGrey2,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          value,
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.white,
          ),
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