import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard.dart';
import 'api_client.dart';

class DashboardService {
  DashboardService._();

  static Map<String, dynamic>? _dataMap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return null;
  }
  static Future<DashboardSummary> fetchSummary(
      Ref ref,
      String token, {
        String scope = 'all',
        int? groupId,
        String? dateFrom,
        String? dateTo,
      }) async {
    final payload = <String, dynamic>{'token': token, 'scope': scope};
    if (groupId != null) payload['group_id'] = groupId;
    if (dateFrom != null && dateFrom.isNotEmpty) payload['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) payload['date_to'] = dateTo;

    final res = await ApiClient.post(ref, '/dashboard/summary.php', payload);

    if (!res.success) {
      throw Exception(res.error ?? 'Could not load your dashboard.');
    }

    final data = _dataMap(res.data);
    if (data == null) {
      throw Exception('The server returned an unexpected response.');
    }

    return DashboardSummary.fromJson(data);
  }
  static Future<GroupBalances> fetchBalances(
      Ref ref,
      String token,
      int groupId,
      ) async {
    final res = await ApiClient.post(ref, '/dashboard/balances.php', {
      'token': token,
      'group_id': groupId,
    });

    if (!res.success) {
      throw Exception(res.error ?? 'Could not load the group balances.');
    }

    final data = _dataMap(res.data);
    if (data == null) {
      throw Exception('The server returned an unexpected response.');
    }

    return GroupBalances.fromJson(data);
  }
}