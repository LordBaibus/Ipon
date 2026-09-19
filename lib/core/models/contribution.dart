class Contribution {
  final int userId;
  final String fullName;
  final String email;
  final double weight;
  final bool isLocked;
  final double shareAmount;
  final double paidAmount;
  const Contribution({
    required this.userId,
    required this.fullName,
    required this.weight,
    required this.isLocked,
    required this.shareAmount,
    this.email = '',
    this.paidAmount = 0,
  });

  factory Contribution.fromJson(Map<String, dynamic> json) {
    return Contribution(
      userId: int.tryParse('${json['user_id']}') ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      weight: double.tryParse('${json['weight']}') ?? 1.0,
      isLocked: json['is_locked'] == true,
      shareAmount: double.tryParse('${json['share_amount']}') ?? 0.0,
      paidAmount: double.tryParse('${json['paid_amount']}') ?? 0.0,
    );
  }

  double get remaining => _round2(shareAmount - paidAmount);
  bool get isSettled => (shareAmount - paidAmount) <= 0.005;
  double get paidProgress {
    if (shareAmount <= 0) return 0;
    return (paidAmount / shareAmount).clamp(0.0, 1.0);
  }

  Contribution copyWith({
    double? weight,
    bool? isLocked,
    double? shareAmount,
    double? paidAmount,
  }) {
    return Contribution(
      userId: userId,
      fullName: fullName,
      email: email,
      weight: weight ?? this.weight,
      isLocked: isLocked ?? this.isLocked,
      shareAmount: shareAmount ?? this.shareAmount,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
  Map<String, dynamic> toRequestJson() => {
    'user_id': userId,
    'weight': weight,
    'is_locked': isLocked,
    'share_amount': shareAmount,
  };

  String get firstName {
    final parts = fullName.trim().split(' ');
    return parts.isEmpty ? fullName : parts.first;
  }
}

class ContributionSplit {
  final int planId;
  final String planName;
  final double targetAmount;
  final List<Contribution> members;
  final double lockedTotal;
  final double assignedTotal;
  final double unallocated;
  final double paidTotal;
  final String? error;

  const ContributionSplit({
    required this.planId,
    required this.targetAmount,
    required this.members,
    this.planName = '',
    this.lockedTotal = 0,
    this.assignedTotal = 0,
    this.unallocated = 0,
    this.paidTotal = 0,
    this.error,
  });

  factory ContributionSplit.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];

    return ContributionSplit(
      planId: int.tryParse('${json['plan_id']}') ?? 0,
      planName: (json['plan_name'] ?? '').toString(),
      targetAmount: double.tryParse('${json['target_amount']}') ?? 0.0,
      lockedTotal: double.tryParse('${json['locked_total']}') ?? 0.0,
      assignedTotal: double.tryParse('${json['assigned_total']}') ?? 0.0,
      unallocated: double.tryParse('${json['unallocated']}') ?? 0.0,
      paidTotal: double.tryParse('${json['paid_total']}') ?? 0.0,
      members: rawMembers is List
          ? rawMembers
          .whereType<Map>()
          .map((m) => Contribution.fromJson(Map<String, dynamic>.from(m)))
          .toList()
          : const [],
    );
  }

  bool get isValid => error == null;
  bool get isFullySettled =>
      members.isNotEmpty && members.every((m) => m.isSettled);
  double get collectionProgress {
    if (targetAmount <= 0) return 0;
    return (paidTotal / targetAmount).clamp(0.0, 1.0);
  }

  ContributionSplit copyWith({
    List<Contribution>? members,
    double? lockedTotal,
    double? assignedTotal,
    double? unallocated,
    String? error,
    bool clearError = false,
  }) {
    return ContributionSplit(
      planId: planId,
      planName: planName,
      targetAmount: targetAmount,
      members: members ?? this.members,
      lockedTotal: lockedTotal ?? this.lockedTotal,
      assignedTotal: assignedTotal ?? this.assignedTotal,
      unallocated: unallocated ?? this.unallocated,
      paidTotal: paidTotal,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

double _round2(double value) => (value * 100).roundToDouble() / 100;
ContributionSplit computeSplitLocally({
  required int planId,
  required String planName,
  required double targetAmount,
  required List<Contribution> members,
  double paidTotal = 0,
}) {
  ContributionSplit failure(String message) {
    return ContributionSplit(
      planId: planId,
      planName: planName,
      targetAmount: targetAmount,
      members: members,
      paidTotal: paidTotal,
      error: message,
    );
  }

  if (targetAmount <= 0) {
    return failure('The plan target must be greater than zero.');
  }

  if (members.isEmpty) {
    return failure('This plan has no members to split between.');
  }
  final locked = <Contribution>[];
  final unlocked = <Contribution>[];
  var lockedTotal = 0.0;

  for (final member in members) {
    if (member.weight < 0) {
      return failure('Weights cannot be negative.');
    }

    if (member.isLocked) {
      if (member.shareAmount < 0) {
        return failure('A fixed amount cannot be negative.');
      }
      lockedTotal += member.shareAmount;
      locked.add(member);
    } else {
      unlocked.add(member);
    }
  }

  lockedTotal = _round2(lockedTotal);

  if (lockedTotal - targetAmount > 0.005) {
    final over = _round2(lockedTotal - targetAmount);
    return failure(
      'The fixed amounts add up to more than the plan target by '
          '${over.toStringAsFixed(2)}. Lower one of them or raise the target.',
    );
  }

  final remaining = _round2(targetAmount - lockedTotal);
  final amounts = <int, double>{};
  if (unlocked.isEmpty) {
    for (final member in locked) {
      amounts[member.userId] = _round2(member.shareAmount);
    }

    final updated = members
        .map((m) => m.copyWith(shareAmount: amounts[m.userId] ?? 0))
        .toList();

    return ContributionSplit(
      planId: planId,
      planName: planName,
      targetAmount: targetAmount,
      members: updated,
      lockedTotal: lockedTotal,
      assignedTotal: lockedTotal,
      unallocated: _round2(targetAmount - lockedTotal),
      paidTotal: paidTotal,
    );
  }
  var totalWeight = 0.0;
  for (final member in unlocked) {
    totalWeight += member.weight;
  }
  final useEqualFallback = totalWeight <= 0;
  if (useEqualFallback) {
    totalWeight = unlocked.length.toDouble();
  }

  var runningTotal = 0.0;
  final lastIndex = unlocked.length - 1;

  for (var i = 0; i < unlocked.length; i++) {
    final member = unlocked[i];
    final weight = useEqualFallback ? 1.0 : member.weight;
    double amount;

    if (i == lastIndex) {
      amount = _round2(remaining - runningTotal);
    } else {
      amount = _round2(remaining * (weight / totalWeight));
      runningTotal += amount;
    }

    amounts[member.userId] = amount;
  }

  for (final member in locked) {
    amounts[member.userId] = _round2(member.shareAmount);
  }

  final updated = members
      .map((m) => m.copyWith(shareAmount: amounts[m.userId] ?? 0))
      .toList();

  return ContributionSplit(
    planId: planId,
    planName: planName,
    targetAmount: targetAmount,
    members: updated,
    lockedTotal: lockedTotal,
    assignedTotal: _round2(lockedTotal + remaining),
    unallocated: 0,
    paidTotal: paidTotal,
  );
}