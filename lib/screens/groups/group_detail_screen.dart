import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/group_detail.dart';
import '../../core/models/plan.dart' show formatPeso;
import '../../core/providers/group_detail_provider.dart';
import '../../widgets/primary_glass_button.dart';
import '../dashboard/dashboard_screen.dart' show kAppBarClearance, kChartTrack;
import '../plans/plan_detail_screen.dart';

class GroupDetailScreen extends ConsumerWidget {
  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(groupDetailProvider(groupId));

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        title: const Text('Group'),
        leading: GlassButton(
          icon: const Icon(CupertinoIcons.back),
          label: 'Back',
          width: 40,
          height: 40,
          onTap: () => Navigator.of(context).pop(),
        ),
        actions: [
          GlassButton(
            icon: const Icon(CupertinoIcons.refresh),
            onTap: () => ref.read(groupDetailProvider(groupId).notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Column(
            children: [
              SizedBox(height: kAppBarClearance),
              Expanded(
                child: Center(child: GlassProgressIndicator.circular(size: 28)),
              ),
            ],
          ),
          error: (error, _) => Column(
            children: [
              const SizedBox(height: kAppBarClearance),
              Expanded(
                child: Center(
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
              ),
            ],
          ),
          data: (group) => group.isEmpty
              ? const Column(
            children: [
              SizedBox(height: kAppBarClearance),
              Expanded(
                child: Center(
                  child: Text(
                    'This group could not be found.',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ),
              ),
            ],
          )
              : _GroupDetailBody(group: group),
        ),
      ),
    );
  }
}

class _GroupDetailBody extends StatelessWidget {
  final GroupDetail group;

  const _GroupDetailBody({required this.group});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const SizedBox(height: kAppBarClearance),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.person_2_fill,
                    size: 15,
                    color: CupertinoColors.systemGrey2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    group.memberCount == 1
                        ? '1 member'
                        : '${group.memberCount} members',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                group.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
              if (group.description != null && group.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  group.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: group.inviteCode));
                  GlassToast.show(
                    context,
                    message: 'Invite code copied.',
                    type: GlassToastType.success,
                  );
                },
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.tag,
                      size: 14,
                      color: CupertinoColors.activeGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Invite code: ${group.inviteCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.activeGreen,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      CupertinoIcons.doc_on_doc,
                      size: 12,
                      color: CupertinoColors.activeGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionLabel('Members'),
        GlassGroupedSection(
          children: group.members
              .map((member) => GlassListTile(
            leading: Icon(
              member.isOwner
                  ? CupertinoIcons.star_fill
                  : CupertinoIcons.person_fill,
              color: member.isOwner
                  ? CupertinoColors.systemYellow
                  : CupertinoColors.activeGreen,
            ),
            title: Text(member.isMe ? '${member.fullName} (You)' : member.fullName),
            subtitle: Text(member.isOwner ? 'Owner' : 'Member'),
            trailing: Text(
              formatPeso(member.totalPaid),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ))
              .toList(),
        ),
        const SizedBox(height: 22),
        const _SectionLabel('Plans in this group'),
        if (group.plans.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No plans have been created for this group yet.',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.systemGrey2,
              ),
            ),
          )
        else
          ...group.plans.map(
                (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GroupPlanCard(plan: plan),
            ),
          ),
      ],
    );
  }
}

class _GroupPlanCard extends StatelessWidget {
  final GroupPlanSummary plan;

  const _GroupPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final isOver = plan.isOverspent;
    final statusColor = isOver ? CupertinoColors.systemRed : CupertinoColors.systemGrey2;

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
                Expanded(
                  child: Text(
                    plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  size: 14,
                  color: CupertinoColors.systemGrey2,
                ),
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
                  widthFactor: plan.progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isOver
                          ? CupertinoColors.systemRed
                          : CupertinoColors.activeGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOver
                  ? 'Over budget by ${formatPeso(plan.remaining.abs())} — '
                  '${formatPeso(plan.spentTotal)} spent of ${formatPeso(plan.targetAmount)}'
                  : '${formatPeso(plan.spentTotal)} spent of '
                  '${formatPeso(plan.targetAmount)} · ${formatPeso(plan.remaining)} left',
              style: TextStyle(fontSize: 12, color: statusColor),
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