import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group.dart';
import '../services/groups_service.dart';
import 'auth_provider.dart';

class GroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
    final auth = ref.watch(authProvider);
    if (!auth.isSignedIn || auth.token == null) {
      return const <Group>[];
    }

    return GroupsService.fetchGroups(ref, auth.token!);
  }

  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    if (!auth.isSignedIn || auth.token == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
          () => GroupsService.fetchGroups(ref, auth.token!),
    );
  }

  Future<GroupActionResult> createGroup({
    required String name,
    String description = '',
  }) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) {
      return const GroupActionResult(ok: false, message: 'You are not signed in.');
    }

    final result = await GroupsService.createGroup(
      ref,
      token: auth.token!,
      name: name,
      description: description,
    );

    if (result.ok) await refresh();
    return result;
  }

  Future<GroupActionResult> joinGroup({required String inviteCode}) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) {
      return const GroupActionResult(ok: false, message: 'You are not signed in.');
    }

    final result = await GroupsService.joinGroup(
      ref,
      token: auth.token!,
      inviteCode: inviteCode,
    );

    if (result.ok) await refresh();
    return result;
  }

  Future<GroupActionResult> leaveGroup({
    required int groupId,
    int? transferToUserId,
  }) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) {
      return const GroupActionResult(ok: false, message: 'You are not signed in.');
    }

    final result = await GroupsService.leaveGroup(
      ref,
      token: auth.token!,
      groupId: groupId,
      transferToUserId: transferToUserId,
    );

    if (result.ok) await refresh();
    return result;
  }
}

final groupsProvider =
AsyncNotifierProvider<GroupsNotifier, List<Group>>(GroupsNotifier.new);