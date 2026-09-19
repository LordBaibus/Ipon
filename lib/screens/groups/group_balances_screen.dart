import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/dashboard.dart';
import '../../core/models/plan.dart' show formatPeso;
import '../../core/providers/dashboard_provider.dart';
import '../../widgets/primary_glass_button.dart';

class GroupBalancesScreen extends ConsumerWidget {
  final int groupId;
  final String groupName;

  const GroupBalancesScreen({
    super.key,
    required this.groupId,
    this.groupName = 'Group',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(groupBalancesProvider(groupId));

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        title: const Text('Balances'),
        actions: [
          GlassButton(
            icon: const Icon(CupertinoIcons.refresh),
            onTap: () => ref.invalidate(groupBalancesProvider(groupId)),
          ),
        ],
      ),
      body: SafeArea(
        child: balancesAsync.when(
          loading: () => const Center(
            child: GlassProgressIndicator.circular(size: 28),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 48,
                    color: CupertinoColors.systemOrange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryGlassButton(
                    label: 'Try Again',
                    icon: CupertinoIcons.refresh,
                    onPressed: () =>
                        ref.invalidate(groupBalancesProvider(groupId)),
                  ),
                ],
              ),
            ),
          ),
          data: (balances) => _BalancesBody(
            balances: balances,
            groupName: groupName,
          ),
        ),
      ),
    );
  }
}

class _BalancesBody extends StatelessWidget {
  final GroupBalances balances;
  final String groupName;

  const _BalancesBody({required this.balances, required this.groupName});

  @override
  Widget build(BuildContext context) {
    final mine = balances.myBalance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$groupName has spent',
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatPeso(balances.totalSpent),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.activeGreen,
                ),
              ),
              if (mine != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      mine.isEven
                          ? CupertinoIcons.checkmark_seal_fill
                          : (mine.isOwed
                          ? CupertinoIcons.arrow_down_left_circle_fill
                          : CupertinoIcons.arrow_up_right_circle_fill),
                      size: 17,
                      color: mine.isEven
                          ? CupertinoColors.activeGreen
                          : (mine.isOwed
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.systemOrange),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mine.isEven
                            ? 'You are settled up.'
                            : (mine.isOwed
                            ? 'You are owed ${formatPeso(mine.net)}.'
                            : 'You owe ${formatPeso(mine.net.abs())}.'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionLabel('How to settle up'),
        if (balances.isSettled)
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: const [
                Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  color: CupertinoColors.activeGreen,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Everyone is square. Nobody owes anybody right now.',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final settlement in balances.settlements)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.arrow_right_circle_fill,
                      size: 18,
                      color: CupertinoColors.activeBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: settlement.fromName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.white,
                              ),
                            ),
                            const TextSpan(
                              text: ' pays ',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey2,
                              ),
                            ),
                            TextSpan(
                              text: settlement.toName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPeso(settlement.amount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              balances.settlements.length == 1
                  ? 'One payment clears every balance in this group.'
                  : '${balances.settlements.length} payments clear every '
                  'balance in this group — the fewest possible.',
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const _SectionLabel('Everyone in the group'),
        for (final member in balances.perMember)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MemberBalanceCard(member: member),
          ),

        const SizedBox(height: 14),
        const Text(
          'Each member owes an equal share of everything the group has '
              'spent. Contributions toward a plan are tracked separately, on '
              'that plan’s own split screen.',
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.systemGrey,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _MemberBalanceCard extends StatelessWidget {
  final MemberBalance member;

  const _MemberBalanceCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = member.isEven
        ? CupertinoColors.systemGrey2
        : (member.isOwed
        ? CupertinoColors.activeGreen
        : CupertinoColors.systemOrange);

    final IconData statusIcon = member.isEven
        ? CupertinoIcons.equal_circle
        : (member.isOwed
        ? CupertinoIcons.arrow_down_left_circle
        : CupertinoIcons.arrow_up_right_circle);

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
                    if (member.isMe)
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
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 5),
              Text(
                member.isEven
                    ? 'settled up'
                    : '${member.statusLabel} ${formatPeso(member.net.abs())}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'paid in',
                  value: formatPeso(member.paid),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'their share',
                  value: formatPeso(member.owed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ],
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