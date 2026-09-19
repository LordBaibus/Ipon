import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_detail.dart';
import '../services/groups_service.dart';
import 'auth_provider.dart';

class GroupDetailNotifier extends FamilyAsyncNotifier<GroupDetail, int> {
  @override
  Future<GroupDetail> build(int groupId) async {
    final auth = ref.watch(authProvider);

    if (!auth.isSignedIn || auth.token == null) {
      return GroupDetail.empty();
    }

    return GroupsService.fetchGroupDetail(ref, auth.token!, groupId: groupId);
  }

  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    if (!auth.isSignedIn || auth.token == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
          () => GroupsService.fetchGroupDetail(ref, auth.token!, groupId: arg),
    );
  }
}

final groupDetailProvider =
AsyncNotifierProvider.family<GroupDetailNotifier, GroupDetail, int>(
  GroupDetailNotifier.new,
);