import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plan.dart';
import 'api_client.dart';

class PlanActionResult {
  final bool ok;
  final String message;

  /// The created or updated plan, when the call succeeded.
  final Plan? plan;

  const PlanActionResult({
    required this.ok,
    required this.message,
    this.plan,
  });
}

class PlansService {
  PlansService._();

  static String _message(dynamic body, String fallback) {
    if (body is Map && body['message'] != null) {
      final text = body['message'].toString();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static Map<String, dynamic>? _dataMap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return null;
  }

  /// Loads the plan templates. [targetAmount] is optional; when given,
  /// the server also returns a peso preview for each template.
  static Future<List<PlanTemplate>> fetchTemplates(
      Ref ref,
      String token, {
        double targetAmount = 0,
      }) async {
    final res = await ApiClient.post(ref, '/plans/templates.php', {
      'token': token,
      'target_amount': targetAmount,
    });

    if (!res.success) {
      throw Exception(res.error ?? 'Could not load plan templates.');
    }

    final body = res.data;
    if (body is! Map || body['data'] is! List) return const <PlanTemplate>[];

    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => PlanTemplate.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// [scope] is 'all', 'personal', or 'group'. Pass [groupId] to limit
  /// the result to a single group.
  static Future<List<Plan>> fetchPlans(
      Ref ref,
      String token, {
        String scope = 'all',
        int? groupId,
      }) async {
    final payload = <String, dynamic>{'token': token, 'scope': scope};
    if (groupId != null) payload['group_id'] = groupId;

    final res = await ApiClient.post(ref, '/plans/list.php', payload);

    if (!res.success) {
      throw Exception(res.error ?? 'Could not load your plans.');
    }

    final body = res.data;
    if (body is! Map || body['data'] is! List) return const <Plan>[];

    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Plan.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// One plan including its categories.
  static Future<Plan> fetchPlanDetail(Ref ref, String token, int planId) async {
    final res = await ApiClient.post(ref, '/plans/detail.php', {
      'token': token,
      'plan_id': planId,
    });

    if (!res.success) {
      throw Exception(res.error ?? 'Could not load that plan.');
    }

    final data = _dataMap(res.data);
    if (data == null) throw Exception('The server returned an unexpected response.');

    return Plan.fromJson(data);
  }

  static Future<PlanActionResult> createPlan(
      Ref ref, {
        required String token,
        required String name,
        required String planType,
        required double targetAmount,
        int? groupId,
        String? deadline,
        String? notes,
        List<PlanCategory>? categories,
      }) async {
    final payload = <String, dynamic>{
      'token': token,
      'name': name,
      'plan_type': planType,
      'target_amount': targetAmount,
    };

    if (groupId != null) payload['group_id'] = groupId;
    if (deadline != null && deadline.isNotEmpty) payload['deadline'] = deadline;
    if (notes != null && notes.isNotEmpty) payload['notes'] = notes;
    if (categories != null && categories.isNotEmpty) {
      payload['categories'] =
          categories.map((c) => c.toRequestJson()).toList();
    }

    final res = await ApiClient.post(ref, '/plans/create.php', payload);

    if (!res.success) {
      return PlanActionResult(
        ok: false,
        message: res.error ?? 'Could not create the plan.',
      );
    }

    final data = _dataMap(res.data);
    return PlanActionResult(
      ok: true,
      message: _message(res.data, 'Plan created.'),
      plan: data == null ? null : Plan.fromJson(data),
    );
  }

  /// Every field except [planId] is optional — omitted fields keep
  /// their current values. Passing [categories] replaces the whole set;
  /// passing [reapplyTemplate] re-splits the target by the template.
  static Future<PlanActionResult> updatePlan(
      Ref ref, {
        required String token,
        required int planId,
        String? name,
        double? targetAmount,
        String? deadline,
        String? notes,
        List<PlanCategory>? categories,
        bool reapplyTemplate = false,
      }) async {
    final payload = <String, dynamic>{'token': token, 'plan_id': planId};

    if (name != null) payload['name'] = name;
    if (targetAmount != null) payload['target_amount'] = targetAmount;
    // An empty string deliberately clears the deadline server-side.
    if (deadline != null) payload['deadline'] = deadline;
    if (notes != null) payload['notes'] = notes;
    if (categories != null) {
      payload['categories'] =
          categories.map((c) => c.toRequestJson()).toList();
    } else if (reapplyTemplate) {
      payload['reapply_template'] = true;
    }

    final res = await ApiClient.post(ref, '/plans/update.php', payload);

    if (!res.success) {
      return PlanActionResult(
        ok: false,
        message: res.error ?? 'Could not update the plan.',
      );
    }

    final data = _dataMap(res.data);
    return PlanActionResult(
      ok: true,
      message: _message(res.data, 'Plan updated.'),
      plan: data == null ? null : Plan.fromJson(data),
    );
  }

  static Future<PlanActionResult> deletePlan(
      Ref ref, {
        required String token,
        required int planId,
      }) async {
    final res = await ApiClient.post(ref, '/plans/delete.php', {
      'token': token,
      'plan_id': planId,
    });

    if (!res.success) {
      return PlanActionResult(
        ok: false,
        message: res.error ?? 'Could not delete the plan.',
      );
    }

    return PlanActionResult(
      ok: true,
      message: _message(res.data, 'Plan deleted.'),
    );
  }
}