class BudgetPacingWindow {
  final double actual;
  final double expected;
  final double percentVsPace;
  final String status;

  const BudgetPacingWindow({
    this.actual = 0,
    this.expected = 0,
    this.percentVsPace = 0,
    this.status = 'on_pace',
  });

  factory BudgetPacingWindow.fromJson(Map<String, dynamic> json) {
    return BudgetPacingWindow(
      actual: double.tryParse('${json['actual']}') ?? 0,
      expected: double.tryParse('${json['expected']}') ?? 0,
      percentVsPace: double.tryParse('${json['percent_vs_pace']}') ?? 0,
      status: (json['status'] ?? 'on_pace').toString(),
    );
  }

  bool get isOver => status == 'over';
  bool get isUnder => status == 'under';
}

class BudgetPacing {
  final double limitAmount;
  final double dailyPace;
  final String cycleStart;
  final String cycleEnd;
  final int cycleLength;
  final int daysElapsed;
  final int daysRemaining;
  final double spentTotal;
  final double remaining;
  final bool isOverLimit;
  final double projectedTotal;
  final double projectedOver;
  final BudgetPacingWindow today;
  final BudgetPacingWindow last7Days;
  final BudgetPacingWindow last15Days;
  final BudgetPacingWindow cycleToDate;

  const BudgetPacing({
    this.limitAmount = 0,
    this.dailyPace = 0,
    this.cycleStart = '',
    this.cycleEnd = '',
    this.cycleLength = 30,
    this.daysElapsed = 0,
    this.daysRemaining = 0,
    this.spentTotal = 0,
    this.remaining = 0,
    this.isOverLimit = false,
    this.projectedTotal = 0,
    this.projectedOver = 0,
    this.today = const BudgetPacingWindow(),
    this.last7Days = const BudgetPacingWindow(),
    this.last15Days = const BudgetPacingWindow(),
    this.cycleToDate = const BudgetPacingWindow(),
  });

  factory BudgetPacing.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] is Map
        ? Map<String, dynamic>.from(json['breakdown'] as Map)
        : <String, dynamic>{};

    BudgetPacingWindow window(String key) {
      final raw = breakdown[key];
      return raw is Map
          ? BudgetPacingWindow.fromJson(Map<String, dynamic>.from(raw))
          : const BudgetPacingWindow();
    }

    return BudgetPacing(
      limitAmount: double.tryParse('${json['limit_amount']}') ?? 0,
      dailyPace: double.tryParse('${json['daily_pace']}') ?? 0,
      cycleStart: (json['cycle_start'] ?? '').toString(),
      cycleEnd: (json['cycle_end'] ?? '').toString(),
      cycleLength: int.tryParse('${json['cycle_length']}') ?? 30,
      daysElapsed: int.tryParse('${json['days_elapsed']}') ?? 0,
      daysRemaining: int.tryParse('${json['days_remaining']}') ?? 0,
      spentTotal: double.tryParse('${json['spent_total']}') ?? 0,
      remaining: double.tryParse('${json['remaining']}') ?? 0,
      isOverLimit: json['is_over_limit'] == true,
      projectedTotal: double.tryParse('${json['projected_total']}') ?? 0,
      projectedOver: double.tryParse('${json['projected_over']}') ?? 0,
      today: window('today'),
      last7Days: window('last_7_days'),
      last15Days: window('last_15_days'),
      cycleToDate: window('cycle_to_date'),
    );
  }
}
class Budget {
  final int? id;
  final int? groupId;
  final double limitAmount;
  final int cycleStartDay;
  final String? updatedAt;
  final BudgetPacing? pacing;

  const Budget({
    this.id,
    this.groupId,
    this.limitAmount = 0,
    this.cycleStartDay = 1,
    this.updatedAt,
    this.pacing,
  });
  bool get hasBudget => id != null;

  bool get isPersonal => groupId == null;

  factory Budget.empty({int? groupId}) => Budget(groupId: groupId);

  factory Budget.fromJson(Map<String, dynamic> json) {
    if (json['has_budget'] == false) {
      final gid = json['group_id'];
      return Budget.empty(
        groupId: gid == null ? null : int.tryParse('$gid'),
      );
    }

    final pacingJson = json['pacing'];

    return Budget(
      id: int.tryParse('${json['id']}'),
      groupId: json['group_id'] == null ? null : int.tryParse('${json['group_id']}'),
      limitAmount: double.tryParse('${json['limit_amount']}') ?? 0,
      cycleStartDay: int.tryParse('${json['cycle_start_day']}') ?? 1,
      updatedAt: json['updated_at']?.toString(),
      pacing: pacingJson is Map
          ? BudgetPacing.fromJson(Map<String, dynamic>.from(pacingJson))
          : null,
    );
  }
}