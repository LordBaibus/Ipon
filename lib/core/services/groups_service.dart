import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group.dart';
import 'api_client.dart';

class GroupActionResult {
  final bool ok;
  final String message;
  final bool requiresTransfer;

  const GroupActionResult({
    required this.ok,
    required this.message,
    this.requiresTransfer = false,
  });
}

class GroupsService {
  GroupsService._();

  static String _message(dynamic body, String fallback) {
    if (body is Map && body['message'] != null) {
      final text = body['message'].toString();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static Future<List<Group>> fetchGroups(Ref ref, String token) async {
    final res = await ApiClient.post(ref, '/groups/list.php', {'token': token});

    if (!res.success) {
      throw Exception(res.error ?? 'Could not load your groups.');
    }

    final body = res.data;
    if (body is! Map || body['data'] is! List) {
      return const <Group>[];
    }

    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Group.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<GroupActionResult> createGroup(
      Ref ref, {
        required String token,
        required String name,
        String description = '',
      }) async {
    final res = await ApiClient.post(ref, '/groups/create.php', {
      'token': token,
      'name': name,
      'description': description,
    });

    if (!res.success) {
      return GroupActionResult(
        ok: false,
        message: res.error ?? 'Could not create the group.',
      );
    }

    return GroupActionResult(
      ok: true,
      message: _message(res.data, 'Group created.'),
    );
  }

  static Future<GroupActionResult> joinGroup(
      Ref ref, {
        required String token,
        required String inviteCode,
      }) async {
    final res = await ApiClient.post(ref, '/groups/join.php', {
      'token': token,
      'invite_code': inviteCode,
    });

    if (!res.success) {
      return GroupActionResult(
        ok: false,
        message: res.error ?? 'Could not join that group.',
      );
    }

    return GroupActionResult(
      ok: true,
      message: _message(res.data, 'Joined the group.'),
    );
  }

  static Future<GroupActionResult> leaveGroup(
      Ref ref, {
        required String token,
        required int groupId,
        int? transferToUserId,
      }) async {
    final payload = <String, dynamic>{'token': token, 'group_id': groupId};
    if (transferToUserId != null) {
      payload['transfer_to_user_id'] = transferToUserId;
    }

    final res = await ApiClient.post(ref, '/groups/leave.php', payload);

    if (!res.success) {
      final message = res.error ?? 'Could not leave the group.';
      final needsTransfer = message.toLowerCase().contains('take over');
      return GroupActionResult(
        ok: false,
        message: message,
        requiresTransfer: needsTransfer,
      );
    }

    return GroupActionResult(
      ok: true,
      message: _message(res.data, 'You have left the group.'),
    );
  }
}