import 'dart:math' as math;

class PlanCategory {
  final int? id;
  final String label;
  final double amount;
  final int sortOrder;

  const PlanCategory({
    this.id,
    required this.label,
    required this.amount,
    this.sortOrder = 0,
  });

  factory PlanCategory.fromJson(Map<String, dynamic> json) {
    return PlanCategory(
      id: json['id'] == null ? null : int.tryParse('${json['id']}'),
      label: (json['label'] ?? '').toString(),
      amount: double.tryParse('${json['amount']}') ?? 0.0,
      sortOrder: int.tryParse('${json['sort_order']}') ?? 0,
    );
  }

  Map<String, dynamic> toRequestJson() => {
    'label': label,
    'amount': amount,
  };

  PlanCategory copyWith({String? label, double? amount, int? sortOrder}) {
    return PlanCategory(
      id: id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  double percentOf(double target) {
    if (target <= 0) return 0;
    return (amount / target) * 100;
  }
}

class Plan {
  final int id;
  final String name;
  final String planType;
  final double targetAmount;
  final double allocatedTotal;
  final double unallocated;
  final int? groupId;
  final String? groupName;
  final bool isOwner;
  final String? deadline;
  final String? notes;
  final List<PlanCategory> categories;

  const Plan({
    required this.id,
    required this.name,
    required this.planType,
    required this.targetAmount,
    required this.allocatedTotal,
    required this.unallocated,
    required this.isOwner,
    this.groupId,
    this.groupName,
    this.deadline,
    this.notes,
    this.categories = const [],
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];

    return Plan(
      id: int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      planType: (json['plan_type'] ?? 'custom').toString(),
      targetAmount: double.tryParse('${json['target_amount']}') ?? 0.0,
      allocatedTotal: double.tryParse('${json['allocated_total']}') ?? 0.0,
      unallocated: double.tryParse('${json['unallocated']}') ?? 0.0,
      groupId: json['group_id'] == null
          ? null
          : int.tryParse('${json['group_id']}'),
      groupName: json['group_name']?.toString(),
      isOwner: json['is_owner'] == true,
      deadline: json['deadline']?.toString(),
      notes: json['notes']?.toString(),
      categories: rawCategories is List
          ? rawCategories
          .whereType<Map>()
          .map((c) => PlanCategory.fromJson(Map<String, dynamic>.from(c)))
          .toList()
          : const [],
    );
  }

  bool get isPersonal => groupId == null;
  double get allocationProgress {
    if (targetAmount <= 0) return 0;
    return (allocatedTotal / targetAmount).clamp(0.0, 1.0);
  }

  bool get isFullyAllocated => unallocated.abs() < 0.01;
  bool get isOverAllocated => unallocated < -0.01;
  String get scopeLabel => isPersonal ? 'Personal' : (groupName ?? 'Group');
}

class PlanTemplateCategory {
  final String label;
  final double percent;

  const PlanTemplateCategory({required this.label, required this.percent});

  factory PlanTemplateCategory.fromJson(Map<String, dynamic> json) {
    return PlanTemplateCategory(
      label: (json['label'] ?? '').toString(),
      percent: double.tryParse('${json['percent']}') ?? 0.0,
    );
  }
}

class PlanTemplate {
  final String key;
  final String label;
  final String description;
  final List<PlanTemplateCategory> categories;

  const PlanTemplate({
    required this.key,
    required this.label,
    required this.description,
    this.categories = const [],
  });

  factory PlanTemplate.fromJson(Map<String, dynamic> json) {
    final raw = json['categories'];
    return PlanTemplate(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      categories: raw is List
          ? raw
          .whereType<Map>()
          .map((c) =>
          PlanTemplateCategory.fromJson(Map<String, dynamic>.from(c)))
          .toList()
          : const [],
    );
  }

  bool get isCustom => categories.isEmpty;
  List<PlanCategory> allocate(double target) {
    if (categories.isEmpty || target <= 0) return const [];

    final result = <PlanCategory>[];
    var runningTotal = 0.0;
    final lastIndex = categories.length - 1;

    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      double amount;

      if (i == lastIndex) {
        amount = _round2(target - runningTotal);
      } else {
        amount = _round2(target * category.percent / 100.0);
        runningTotal += amount;
      }

      result.add(PlanCategory(
        label: category.label,
        amount: amount,
        sortOrder: i,
      ));
    }

    return result;
  }

  static double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

String formatPeso(double amount, {bool withSymbol = true}) {
  final negative = amount < 0;
  final absolute = amount.abs();
  final whole = absolute.floor();
  final cents = ((absolute - whole) * 100).round().toString().padLeft(2, '0');

  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  final sign = negative ? '-' : '';
  final symbol = withSymbol ? '\u20B1' : '';
  return '$sign$symbol${buffer.toString()}.$cents';
}

int? daysUntil(String? deadline) {
  if (deadline == null || deadline.isEmpty) return null;
  final parsed = DateTime.tryParse(deadline);
  if (parsed == null) return null;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(parsed.year, parsed.month, parsed.day);
  return math.max(target.difference(today).inDays, -99999);
}