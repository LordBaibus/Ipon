import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/models/group.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/primary_glass_button.dart';
import '../dashboard/dashboard_screen.dart' show kAppBarClearance;
import 'group_detail_screen.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: GlassAppBar(
        title: const Text('Groups'),
        actions: [
          GlassButton(
            icon: const Icon(
              CupertinoIcons.add,
              color: AppColors.moneyGreen,
            ),
            onTap: () => _showAddOptions(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: kAppBarClearance),
            Expanded(
              child: groupsAsync.when(
                loading: () => const Center(
                  child: GlassProgressIndicator.circular(size: 28),
                ),
                error: (error, _) => _ErrorState(
                  message: error.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => ref.read(groupsProvider.notifier).refresh(),
                ),
                data: (groups) => groups.isEmpty
                    ? _EmptyState(
                  onCreate: () => _showCreateSheet(context, ref),
                  onJoin: () => _showJoinSheet(context, ref),
                )
                    : _GroupsList(groups: groups),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The '+' button's entry point: choose between creating a new group
  /// or joining one with an invite code. Without this, "Join a Group"
  /// was only reachable from the empty state, so it disappeared the
  /// moment the user had at least one group.
  void _showAddOptions(BuildContext context, WidgetRef ref) {
    GlassDialog.show<void>(
      context: context,
      title: 'Add a Group',
      barrierDismissible: true,
      actions: [
        GlassDialogAction(
          label: 'Create a Group',
          isPrimary: true,
          onPressed: () {
            Navigator.of(context).pop();
            _showCreateSheet(context, ref);
          },
        ),
        GlassDialogAction(
          label: 'I Have an Invite Code',
          onPressed: () {
            Navigator.of(context).pop();
            _showJoinSheet(context, ref);
          },
        ),
        GlassDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

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
                const Text(
                  'New Group',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: nameController,
                  placeholder: 'Group name',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                GlassTextField(
                  controller: descriptionController,
                  placeholder: 'Description (optional)',
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 18),
                PrimaryGlassButton(
                  label: 'Create',
                  icon: CupertinoIcons.check_mark,
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    Navigator.of(dialogContext).pop();

                    final result =
                    await ref.read(groupsProvider.notifier).createGroup(
                      name: name,
                      description: descriptionController.text.trim(),
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
  void _showJoinSheet(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();

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
                const Text(
                  'Join a Group',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ask a member for the 8-character invite code.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: codeController,
                  placeholder: 'INVITE CODE',
                  maxLength: 8,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  ],
                  prefixIcon: const Icon(
                    CupertinoIcons.person_2,
                    color: AppColors.moneyGreen,
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryGlassButton(
                  label: 'Join',
                  icon: CupertinoIcons.person_add,
                  onPressed: () async {
                    final code = codeController.text.trim();
                    if (code.isEmpty) return;

                    Navigator.of(dialogContext).pop();

                    final result =
                    await ref.read(groupsProvider.notifier).joinGroup(
                      inviteCode: code,
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
}
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _GroupsList extends ConsumerWidget {
  final List<Group> groups;

  const _GroupsList({required this.groups});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        GlassGroupedSection(
          children: groups
              .map((group) => GlassListTile(
            leading: Icon(
              group.isOwner
                  ? CupertinoIcons.star_fill
                  : CupertinoIcons.person_2_fill,
              color: group.isOwner
                  ? AppColors.statusWarning
                  : AppColors.moneyGreen,
            ),
            title: Text(group.name),
            subtitle: Text(
              '${group.memberLabel} · Code: ${group.inviteCode}',
            ),
            // The row itself opens the group's detail screen (members +
            // plans); the ellipsis is its own tap target for the quick
            // actions (copy invite code, leave), so neither gesture
            // steals the other.
            trailing: GestureDetector(
              onTap: () => _showGroupActions(context, ref, group),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  CupertinoIcons.ellipsis,
                  size: 18,
                ),
              ),
            ),
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => GroupDetailScreen(groupId: group.id),
              ),
            ),
          ))
              .toList(),
        ),
      ],
    );
  }

  void _showGroupActions(BuildContext context, WidgetRef ref, Group group) {
    GlassDialog.show<void>(
      context: context,
      title: group.name,
      message: group.description?.isNotEmpty == true
          ? '${group.description}\n\n${group.memberLabel} · Invite code: ${group.inviteCode}'
          : '${group.memberLabel} · Invite code: ${group.inviteCode}',
      barrierDismissible: true,
      actions: [
        GlassDialogAction(
          label: 'Copy Invite Code',
          isPrimary: true,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: group.inviteCode));
            Navigator.of(context).pop();
            GlassToast.show(
              context,
              message: 'Invite code copied.',
              type: GlassToastType.success,
            );
          },
        ),
        GlassDialogAction(
          label: 'Leave Group',
          isDestructive: true,
          onPressed: () async {
            Navigator.of(context).pop();

            final result = await ref
                .read(groupsProvider.notifier)
                .leaveGroup(groupId: group.id);

            if (!context.mounted) return;
            GlassToast.show(
              context,
              message: result.message,
              type: result.ok ? GlassToastType.success : GlassToastType.error,
            );
          },
        ),
        GlassDialogAction(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _EmptyState({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.person_2,
              size: 56,
              color: AppColors.moneyGreen,
            ),
            const SizedBox(height: 16),
            const Text('No groups yet', style: AppTextStyles.screenTitle),
            const SizedBox(height: 8),
            const Text(
              'Groups are optional. You can track your own plans and '
                  'expenses on your own, or make a group to split costs '
                  'with family, housemates, or your barkada.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 24),
            PrimaryGlassButton(
              label: 'Create a Group',
              icon: CupertinoIcons.add,
              onPressed: onCreate,
            ),
            SubtleGlassLink(
              label: 'I have an invite code',
              onPressed: onJoin,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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