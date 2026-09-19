import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/expense.dart';
import '../../core/models/group.dart';
import '../../core/models/plan.dart';
import '../../core/providers/expenses_provider.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/providers/plans_provider.dart';
import '../../core/services/ocr_service.dart';
import '../../widgets/primary_glass_button.dart';

class ExpenseCreateScreen extends ConsumerStatefulWidget {
  final int? initialPlanId;

  const ExpenseCreateScreen({super.key, this.initialPlanId});

  @override
  ConsumerState<ExpenseCreateScreen> createState() =>
      _ExpenseCreateScreenState();
}

class _ExpenseCreateScreenState extends ConsumerState<ExpenseCreateScreen> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _categoryController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  int? _groupId;
  int? _planId;
  int? _planCategoryId;
  bool _isSaving = false;
  bool _isScanning = false;
  String? _errorMessage;
  ReceiptScanResult? _scanResult;

  @override
  void initState() {
    super.initState();
    _planId = widget.initialPlanId;
    // Default to today, in the YYYY-MM-DD the API expects.
    final now = DateTime.now();
    _dateController.text =
    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
  void _chooseImageSource() {
    GlassDialog.show<void>(
      context: context,
      title: 'Scan Receipt',
      message: 'The photo is read on your phone and never uploaded.',
      barrierDismissible: true,
      actions: [
        GlassDialogAction(
          label: 'Take a Photo',
          isPrimary: true,
          onPressed: () {
            Navigator.of(context).pop();
            _scanReceipt(ImageSource.camera);
          },
        ),
        GlassDialogAction(
          label: 'Choose from Gallery',
          onPressed: () {
            Navigator.of(context).pop();
            _scanReceipt(ImageSource.gallery);
          },
        ),
        GlassDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _scanReceipt(ImageSource source) async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 90);

      if (file == null) {
        // The user backed out of the camera — not an error.
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      final result = await OcrService.scanReceipt(file.path);

      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _scanResult = result;

        if (result.amount != null) {
          _amountController.text = result.amount!.toStringAsFixed(2);
        }
        if (result.merchant != null && result.merchant!.isNotEmpty) {
          _merchantController.text = result.merchant!;
        }
        if (result.date != null) {
          _dateController.text = result.date!;
        }
      });

      GlassToast.show(
        context,
        message: result.foundAnything
            ? 'Receipt read. Check the values before saving.'
            : 'Could not read that receipt. Enter the details by hand.',
        type: result.foundAnything
            ? GlassToastType.success
            : GlassToastType.warning,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = 'Could not open the camera or photo library.';
      });
    }
  }

  void _showRawText() {
    final raw = _scanResult?.rawText ?? '';
    if (raw.isEmpty) return;

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'What the scan read',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Text(
                      raw,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryGlassButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim());
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

    final result = await ref.read(expenseActionsProvider).createExpense(
      amount: amount,
      merchant: _merchantController.text,
      category: _categoryController.text,
      expenseDate: date,
      notes: _notesController.text,
      source: _scanResult != null ? 'ocr' : 'manual',
      groupId: _groupId,
      planId: _planId,
      planCategoryId: _planCategoryId,
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
    Navigator.of(context).pop(result.expense);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final plans = ref.watch(plansProvider).value ?? const <Plan>[];
    final planDetail =
    _planId == null ? null : ref.watch(planDetailProvider(_planId!)).value;
    final categories = planDetail?.categories ?? const <PlanCategory>[];

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(title: const Text('Add Expense')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            PrimaryGlassButton(
              label: _isScanning ? 'Reading receipt…' : 'Scan Receipt',
              icon: CupertinoIcons.camera,
              isLoading: _isScanning,
              onPressed: _isSaving ? null : _chooseImageSource,
            ),
            const SizedBox(height: 8),
            const Text(
              'Reads the receipt on your phone. The photo is never uploaded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: CupertinoColors.systemGrey,
              ),
            ),

            if (_scanResult != null) ...[
              const SizedBox(height: 12),
              _ScanSummary(
                result: _scanResult!,
                onShowRawText: _showRawText,
              ),
            ],
            const SizedBox(height: 22),
            const _Label('Expense details'),
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
              placeholder: 'Merchant or description (optional)',
              textInputAction: TextInputAction.next,
              enabled: !_isSaving,
              prefixIcon: const Icon(CupertinoIcons.cart),
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
            const SizedBox(height: 22),
            const _Label('Category'),
            GlassTextField(
              controller: _categoryController,
              placeholder: 'e.g. Groceries',
              enabled: !_isSaving,
              prefixIcon: const Icon(CupertinoIcons.tag),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kExpenseCategorySuggestions
                  .map((suggestion) => _CategoryChip(
                label: suggestion,
                selected: _categoryController.text.trim().toLowerCase() ==
                    suggestion.toLowerCase(),
                onTap: _isSaving
                    ? null
                    : () => setState(
                      () => _categoryController.text = suggestion,
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 22),
            const _Label('Who is this for?'),
            GlassGroupedSection(
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.person),
                  title: const Text('Just me'),
                  subtitle: const Text('A personal expense'),
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
            const SizedBox(height: 22),
            const _Label('Count toward a plan (optional)'),
            GlassGroupedSection(
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.minus_circle),
                  title: const Text('Not linked to a plan'),
                  trailing: _planId == null
                      ? const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: CupertinoColors.activeGreen,
                  )
                      : null,
                  onTap: _isSaving
                      ? null
                      : () => setState(() {
                    _planId = null;
                    _planCategoryId = null;
                  }),
                ),
                ...plans.map(
                      (plan) => GlassListTile(
                    leading: Icon(
                      plan.isPersonal
                          ? CupertinoIcons.person
                          : CupertinoIcons.person_2_fill,
                    ),
                    title: Text(plan.name),
                    subtitle: Text(plan.scopeLabel),
                    trailing: _planId == plan.id
                        ? const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: CupertinoColors.activeGreen,
                    )
                        : null,
                    onTap: _isSaving
                        ? null
                        : () => setState(() {
                      _planId = plan.id;
                      // The old category belongs to a different
                      // plan, so it cannot carry over.
                      _planCategoryId = null;
                      // A group plan implies its own group.
                      if (!plan.isPersonal) _groupId = plan.groupId;
                    }),
                  ),
                ),
              ],
            ),
            if (_planId != null && categories.isNotEmpty) ...[
              const SizedBox(height: 22),
              const _Label('Budget line (optional)'),
              GlassGroupedSection(
                children: categories
                    .map((category) => GlassListTile(
                  title: Text(category.label),
                  subtitle: Text(formatPeso(category.amount)),
                  trailing: _planCategoryId == category.id
                      ? const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: CupertinoColors.activeGreen,
                  )
                      : null,
                  onTap: _isSaving
                      ? null
                      : () => setState(
                        () => _planCategoryId =
                    _planCategoryId == category.id
                        ? null
                        : category.id,
                  ),
                ))
                    .toList(),
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
              label: 'Save Expense',
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
class _ScanSummary extends StatelessWidget {
  final ReceiptScanResult result;
  final VoidCallback onShowRawText;

  const _ScanSummary({required this.result, required this.onShowRawText});

  @override
  Widget build(BuildContext context) {
    final guessed = result.amount != null && !result.amountFromTotalLine;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.foundAnything
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.exclamationmark_triangle_fill,
                size: 18,
                color: result.foundAnything
                    ? CupertinoColors.activeGreen
                    : CupertinoColors.systemOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.foundAnything
                      ? 'Filled in from your receipt'
                      : 'Nothing readable found',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onShowRawText,
                child: const Text(
                  'View text',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ),
            ],
          ),
          if (guessed) ...[
            const SizedBox(height: 8),
            const Text(
              'No line was labelled as a total, so the largest amount on '
                  'the receipt was used. Double-check it.',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemOrange,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected
                ? CupertinoColors.activeGreen
                : CupertinoColors.white,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

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