class GroupMember {
  final int userId;
  final String fullName;
  final String email;
  final String role;
  final bool isOwner;
  final bool isMe;
  final String? joinedAt;
  final double totalPaid;

  const GroupMember({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isOwner,
    required this.isMe,
    required this.totalPaid,
    this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: int.tryParse('${json['user_id']}') ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'member').toString(),
      isOwner: json['is_owner'] == true,
      isMe: json['is_me'] == true,
      joinedAt: json['joined_at']?.toString(),
      totalPaid: double.tryParse('${json['total_paid']}') ?? 0,
    );
  }
}
class GroupPlanSummary {
  final int id;
  final String name;
  final String planType;
  final double targetAmount;
  final double spentTotal;
  final double remaining;
  final double progress;
  final String? deadline;
  final String? notes;
  final bool isOwner;

  const GroupPlanSummary({
    required this.id,
    required this.name,
    required this.planType,
    required this.targetAmount,
    required this.spentTotal,
    required this.remaining,
    required this.progress,
    required this.isOwner,
    this.deadline,
    this.notes,
  });

  bool get isOverspent => spentTotal > targetAmount;

  factory GroupPlanSummary.fromJson(Map<String, dynamic> json) {
    return GroupPlanSummary(
      id: int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      planType: (json['plan_type'] ?? '').toString(),
      targetAmount: double.tryParse('${json['target_amount']}') ?? 0,
      spentTotal: double.tryParse('${json['spent_total']}') ?? 0,
      remaining: double.tryParse('${json['remaining']}') ?? 0,
      progress: double.tryParse('${json['progress']}') ?? 0,
      deadline: json['deadline']?.toString(),
      notes: json['notes']?.toString(),
      isOwner: json['is_owner'] == true,
    );
  }
}

class GroupDetail {
  final int id;
  final String name;
  final String? description;
  final String inviteCode;
  final bool isOwner;
  final int memberCount;
  final String? createdAt;
  final List<GroupMember> members;
  final List<GroupPlanSummary> plans;

  const GroupDetail({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.isOwner,
    required this.memberCount,
    this.description,
    this.createdAt,
    this.members = const [],
    this.plans = const [],
  });

  factory GroupDetail.empty() => const GroupDetail(
    id: 0,
    name: '',
    inviteCode: '',
    isOwner: false,
    memberCount: 0,
  );

  bool get isEmpty => id == 0;

  factory GroupDetail.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'];
    final plansJson = json['plans'];

    return GroupDetail(
      id: int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      inviteCode: (json['invite_code'] ?? '').toString(),
      isOwner: json['is_owner'] == true,
      memberCount: int.tryParse('${json['member_count']}') ?? 0,
      createdAt: json['created_at']?.toString(),
      members: membersJson is List
          ? membersJson
          .whereType<Map>()
          .map((m) => GroupMember.fromJson(Map<String, dynamic>.from(m)))
          .toList()
          : const [],
      plans: plansJson is List
          ? plansJson
          .whereType<Map>()
          .map((p) => GroupPlanSummary.fromJson(Map<String, dynamic>.from(p)))
          .toList()
          : const [],
    );
  }
}