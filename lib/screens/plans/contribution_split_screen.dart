import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/contribution.dart';
import '../../core/models/plan.dart' show formatPeso;
import '../../core/providers/auth_provider.dart';
import '../../core/providers/contributions_provider.dart';
import '../../widgets/primary_glass_button.dart';

class ContributionSplitScreen extends ConsumerStatefulWidget {
  final int planId;

  const ContributionSplitScreen({super.key, required this.planId});

  @override
  ConsumerState<ContributionSplitScreen> createState() =>
      _ContributionSplitScreenState();
}

class _ContributionSplitScreenState
    extends ConsumerState<ContributionSplitScreen> {
  List<Contribution>? _draft;
  bool _isSaving = false;
  bool _hasChanges = false;
  void _seedDraft(ContributionSplit split) {
    if (_draft != null) return;
    _draft = List<Contribution>.from(split.members);
  }

  ContributionSplit _recompute(ContributionSplit saved) {
    return computeSplitLocally(
      planId: saved.planId,
      planName: saved.planName,
      targetAmount: saved.targetAmount,
      members: _draft ?? saved.members,
      paidTotal: saved.paidTotal,
    );
  }

  void _updateMember(int userId, Contribution updated) {
    setState(() {
      _hasChanges = true;
      final next = List<Contribution>.from(_draft ?? const <Contribution>[]);
      final index = next.indexWhere((m) => m.userId == userId);
      if (index >= 0) next[index] = updated;
      _draft = next;
    });
  }

  void _resetToEqual(ContributionSplit saved) {
    setState(() {
      _hasChanges = true;
      _draft = (_draft ?? saved.members)
          .map((m) => m.copyWith(weight: 1.0, isLocked: false))
          .toList();
    });
  }

  Future<void> _save(ContributionSplit preview) async {
    if (!preview.isValid) return;

    setState(() => _isSaving = true);

    final result = await ref.read(contributionActionsProvider).saveSplit(
      planId: widget.planId,
      members: preview.members,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    GlassToast.show(
      context,
      message: result.message,
      type: result.ok ? GlassToastType.success : GlassToastType.error,
    );

    if (result.ok) {
      setState(() {
        _hasChanges = false;
        _draft = result.split?.members == null
            ? null
            : List<Contribution>.from(result.split!.members);
      });
    }
  }

  void _showPaymentDialog(Contribution member, bool canRecordForOthers) {
    final controller = TextEditingController(
      text: member.paidAmount.toStringAsFixed(2),
    );

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Payment from ${member.firstName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Share: ${formatPeso(member.shareAmount)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: controller,
                  placeholder: '0.00',
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  prefixIcon: const Icon(CupertinoIcons.money_dollar),
                ),
                const SizedBox(height: 18),
                PrimaryGlassButton(
                  label: 'Record Total Paid',
                  icon: CupertinoIcons.check_mark,
                  onPressed: () async {
                    final amount = double.tryParse(controller.text.trim());
                    if (amount == null || amount < 0) return;

                    Navigator.of(dialogContext).pop();

                    final result =
                    await ref.read(contributionActionsProvider).recordPayment(
                      planId: widget.planId,
                      amount: amount,
                      userId: canRecordForOthers ? member.userId : null,
                    );

                    if (!context.mounted) return;
                    GlassToast.show(
                      context,
                      message: result.message,
                      type: result.ok
                          ? GlassToastType.success
                          : GlassToastType.error,
                    );
                  },
                ),
                SubtleGlassLink(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final splitAsync = ref.watch(contributionSplitProvider(widget.planId));
    final currentUserId = ref.watch(currentUserProvider)?.id ?? 0;

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(title: const Text('Contribution Split')),
      body: SafeArea(
        child: splitAsync.when(
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
          data: (saved) {
            _seedDraft(saved);
            final preview = _recompute(saved);
            return _buildBody(saved, preview, currentUserId);
          },
        ),
      ),
    );
  }

  Widget _buildBody(
      ContributionSplit saved,
      ContributionSplit preview,
      int currentUserId,
      ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saved.planName.isEmpty ? 'Plan target' : saved.planName,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatPeso(saved.targetAmount),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.activeGreen,
                ),
              ),
              const SizedBox(height: 14),
              GlassProgressIndicator.linear(
                value: saved.collectionProgress,
                height: 6,
              ),
              const SizedBox(height: 8),
              Text(
                '${formatPeso(saved.paidTotal)} collected of '
                    '${formatPeso(saved.targetAmount)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
            ],
          ),
        ),
        if (!preview.isValid) ...[
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: CupertinoColors.systemRed,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preview.error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'MEMBER SHARES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
            GestureDetector(
              onTap: _isSaving ? null : () => _resetToEqual(saved),
              child: const Text(
                'Reset to equal',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...preview.members.map((member) {
          final isSelf = member.userId == currentUserId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemberSplitCard(
              member: member,
              isSelf: isSelf,
              enabled: !_isSaving,
              onWeightChanged: (weight) => _updateMember(
                member.userId,
                member.copyWith(weight: weight),
              ),
              onLockToggled: (locked) => _updateMember(
                member.userId,
                member.copyWith(isLocked: locked),
              ),
              onFixedAmountChanged: (amount) => _updateMember(
                member.userId,
                member.copyWith(shareAmount: amount),
              ),
              onRecordPayment: () => _showPaymentDialog(member, true),
            ),
          );
        }),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _TotalRow(
                label: 'Assigned',
                value:
                '${formatPeso(preview.assignedTotal)} / ${formatPeso(preview.targetAmount)}',
              ),
              if (preview.unallocated.abs() > 0.005) ...[
                const SizedBox(height: 8),
                _TotalRow(
                  label: 'Still unassigned',
                  value: formatPeso(preview.unallocated),
                  highlight: true,
                ),
              ],
              const SizedBox(height: 8),
              _TotalRow(
                label: 'Collected so far',
                value: formatPeso(saved.paidTotal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryGlassButton(
          label: _hasChanges ? 'Save Split' : 'Saved',
          icon: CupertinoIcons.check_mark,
          isLoading: _isSaving,
          onPressed: (_hasChanges && preview.isValid)
              ? () => _save(preview)
              : null,
        ),
      ],
    );
  }
}

class _MemberSplitCard extends StatefulWidget {
  final Contribution member;
  final bool isSelf;
  final bool enabled;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<bool> onLockToggled;
  final ValueChanged<double> onFixedAmountChanged;
  final VoidCallback onRecordPayment;

  const _MemberSplitCard({
    required this.member,
    required this.isSelf,
    required this.enabled,
    required this.onWeightChanged,
    required this.onLockToggled,
    required this.onFixedAmountChanged,
    required this.onRecordPayment,
  });

  @override
  State<_MemberSplitCard> createState() => _MemberSplitCardState();
}

class _MemberSplitCardState extends State<_MemberSplitCard> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.member.shareAmount.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(covariant _MemberSplitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.member.isLocked) {
      final current = double.tryParse(_amountController.text) ?? -1;
      if ((current - widget.member.shareAmount).abs() > 0.005) {
        _amountController.text = widget.member.shareAmount.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                    if (widget.isSelf)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          '(you)',
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.systemGrey2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                formatPeso(member.shareAmount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.activeGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          if (!member.isLocked) ...[
            Row(
              children: [
                const Text(
                  'Weight',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${member.weight.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ],
            ),
            GlassSlider(
              value: member.weight.clamp(0.5, 5.0),
              min: 0.5,
              max: 5.0,
              divisions: 9,
              onChanged: widget.enabled
                  ? (value) => widget.onWeightChanged(value)
                  : (_) {},
            ),
          ] else ...[
            Row(
              children: [
                const Text(
                  'Fixed amount',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassTextField(
                    controller: _amountController,
                    placeholder: '0.00',
                    enabled: widget.enabled,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (value) => widget.onFixedAmountChanged(
                      double.tryParse(value) ?? 0.0,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Fix this amount',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
              GlassSwitch(
                value: member.isLocked,
                onChanged: widget.enabled
                    ? (value) => widget.onLockToggled(value)
                    : (_) {},
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassProgressIndicator.linear(
            value: member.paidProgress,
            height: 5,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  member.isSettled
                      ? 'Fully paid'
                      : '${formatPeso(member.paidAmount)} paid · '
                      '${formatPeso(member.remaining)} to go',
                  style: TextStyle(
                    fontSize: 12,
                    color: member.isSettled
                        ? CupertinoColors.activeGreen
                        : CupertinoColors.systemGrey2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.enabled ? widget.onRecordPayment : null,
                child: const Text(
                  'Record payment',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.activeBlue,
                    fontWeight: FontWeight.w600,
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

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _TotalRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.systemGrey2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: highlight
                ? CupertinoColors.systemOrange
                : CupertinoColors.white,
          ),
        ),
      ],
    );
  }
}