import 'expense.dart';

class CategorySlice {
  final String label;
  final double total;
  final int count;
  final double sharePercent;

  const CategorySlice({
    required this.label,
    required this.total,
    this.count = 0,
    this.sharePercent = 0,
  });

  factory CategorySlice.fromJson(Map<String, dynamic> json) {
    return CategorySlice(
      label: (json['label'] ?? 'Uncategorized').toString(),
      total: double.tryParse('${json['total']}') ?? 0.0,
      count: int.tryParse('${json['count']}') ?? 0,
      sharePercent: double.tryParse('${json['share_percent']}') ?? 0.0,
    );
  }
}
class MonthPoint {
  final String month;
  final double total;

  const MonthPoint({required this.month, required this.total});

  factory MonthPoint.fromJson(Map<String, dynamic> json) {
    return MonthPoint(
      month: (json['month'] ?? '').toString(),
      total: double.tryParse('${json['total']}') ?? 0.0,
    );
  }
  String get shortLabel {
    final parts = month.split('-');
    if (parts.length != 2) return month;

    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final index = (int.tryParse(parts[1]) ?? 0) - 1;
    if (index < 0 || index >= names.length) return month;
    return names[index];
  }
  String get fullLabel {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    return '$shortLabel ${parts[0]}';
  }
}
class PlanProgress {
  final int planId;
  final String name;
  final String? groupName;
  final bool isPersonal;
  final double targetAmount;
  final double allocated;
  final double spent;
  final double remaining;
  final double spentPercent;
  final bool isOverspent;

  const PlanProgress({
    required this.planId,
    required this.name,
    required this.targetAmount,
    required this.allocated,
    required this.spent,
    required this.remaining,
    required this.spentPercent,
    required this.isOverspent,
    this.groupName,
    this.isPersonal = true,
  });

  factory PlanProgress.fromJson(Map<String, dynamic> json) {
    return PlanProgress(
      planId: int.tryParse('${json['plan_id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      groupName: json['group_name']?.toString(),
      isPersonal: json['is_personal'] == true,
      targetAmount: double.tryParse('${json['target_amount']}') ?? 0.0,
      allocated: double.tryParse('${json['allocated']}') ?? 0.0,
      spent: double.tryParse('${json['spent']}') ?? 0.0,
      remaining: double.tryParse('${json['remaining']}') ?? 0.0,
      spentPercent: double.tryParse('${json['spent_percent']}') ?? 0.0,
      isOverspent: json['is_overspent'] == true,
    );
  }
  double get progress => (spentPercent / 100).clamp(0.0, 1.0);

  String get scopeLabel => isPersonal ? 'Personal' : (groupName ?? 'Group');
}
class DashboardSummary {
  final double totalSpent;
  final int expenseCount;
  final int ocrCount;

  final List<CategorySlice> byCategory;
  final List<MonthPoint> byMonth;
  final List<PlanProgress> planProgress;
  final List<Expense> recent;

  const DashboardSummary({
    this.totalSpent = 0,
    this.expenseCount = 0,
    this.ocrCount = 0,
    this.byCategory = const [],
    this.byMonth = const [],
    this.planProgress = const [],
    this.recent = const [],
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(String key, T Function(Map<String, dynamic>) build) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => build(Map<String, dynamic>.from(item)))
          .toList();
    }

    return DashboardSummary(
      totalSpent: double.tryParse('${json['total_spent']}') ?? 0.0,
      expenseCount: int.tryParse('${json['expense_count']}') ?? 0,
      ocrCount: int.tryParse('${json['ocr_count']}') ?? 0,
      byCategory: listOf('by_category', CategorySlice.fromJson),
      byMonth: listOf('by_month', MonthPoint.fromJson),
      planProgress: listOf('plan_progress', PlanProgress.fromJson),
      recent: listOf('recent', Expense.fromJson),
    );
  }

  bool get isEmpty => expenseCount == 0;
  CategorySlice? get topCategory =>
      byCategory.isEmpty ? null : byCategory.first;
  double get peakMonthTotal {
    var peak = 0.0;
    for (final point in byMonth) {
      if (point.total > peak) peak = point.total;
    }
    return peak;
  }
}
class MemberBalance {
  final int userId;
  final String fullName;
  final double paid;
  final double owed;
  final double net;
  final bool isMe;

  const MemberBalance({
    required this.userId,
    required this.fullName,
    required this.paid,
    required this.owed,
    required this.net,
    this.isMe = false,
  });

  factory MemberBalance.fromJson(Map<String, dynamic> json) {
    return MemberBalance(
      userId: int.tryParse('${json['user_id']}') ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      paid: double.tryParse('${json['paid']}') ?? 0.0,
      owed: double.tryParse('${json['owed']}') ?? 0.0,
      net: double.tryParse('${json['net']}') ?? 0.0,
      isMe: json['is_me'] == true,
    );
  }
  bool get isOwed => net > 0.005;
  bool get owesMoney => net < -0.005;
  bool get isEven => !isOwed && !owesMoney;
  String get statusLabel {
    if (isOwed) return 'is owed';
    if (owesMoney) return 'owes';
    return 'settled up';
  }

  String get firstName {
    final parts = fullName.trim().split(' ');
    return parts.isEmpty ? fullName : parts.first;
  }
}
class Settlement {
  final int fromUserId;
  final String fromName;
  final int toUserId;
  final String toName;
  final double amount;

  const Settlement({
    required this.fromUserId,
    required this.fromName,
    required this.toUserId,
    required this.toName,
    required this.amount,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      fromUserId: int.tryParse('${json['from_user_id']}') ?? 0,
      fromName: (json['from_name'] ?? '').toString(),
      toUserId: int.tryParse('${json['to_user_id']}') ?? 0,
      toName: (json['to_name'] ?? '').toString(),
      amount: double.tryParse('${json['amount']}') ?? 0.0,
    );
  }
}
class GroupBalances {
  final int groupId;
  final double totalSpent;
  final List<MemberBalance> perMember;
  final List<Settlement> settlements;
  final bool isSettled;

  const GroupBalances({
    required this.groupId,
    this.totalSpent = 0,
    this.perMember = const [],
    this.settlements = const [],
    this.isSettled = true,
  });

  factory GroupBalances.fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(String key, T Function(Map<String, dynamic>) build) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => build(Map<String, dynamic>.from(item)))
          .toList();
    }

    return GroupBalances(
      groupId: int.tryParse('${json['group_id']}') ?? 0,
      totalSpent: double.tryParse('${json['total_spent']}') ?? 0.0,
      perMember: listOf('per_member', MemberBalance.fromJson),
      settlements: listOf('settlements', Settlement.fromJson),
      isSettled: json['is_settled'] == true,
    );
  }
  MemberBalance? get myBalance {
    for (final member in perMember) {
      if (member.isMe) return member;
    }
    return null;
  }
}