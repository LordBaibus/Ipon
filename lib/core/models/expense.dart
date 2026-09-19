class Expense {
  final int id;
  final int userId;
  final String? payerName;
  final bool isMine;

  final int? groupId;
  final String? groupName;
  final int? planId;
  final String? planName;
  final int? planCategoryId;
  final String? categoryLabel;
  final String? merchant;
  final double amount;
  final String category;
  final String expenseDate;
  final String? notes;
  final String source;

  const Expense({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.expenseDate,
    required this.source,
    this.payerName,
    this.isMine = true,
    this.groupId,
    this.groupName,
    this.planId,
    this.planName,
    this.planCategoryId,
    this.categoryLabel,
    this.merchant,
    this.notes,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: int.tryParse('${json['id']}') ?? 0,
      userId: int.tryParse('${json['user_id']}') ?? 0,
      payerName: json['payer_name']?.toString(),
      isMine: json['is_mine'] == true,
      groupId: json['group_id'] == null ? null : int.tryParse('${json['group_id']}'),
      groupName: json['group_name']?.toString(),
      planId: json['plan_id'] == null ? null : int.tryParse('${json['plan_id']}'),
      planName: json['plan_name']?.toString(),
      planCategoryId: json['plan_category_id'] == null
          ? null
          : int.tryParse('${json['plan_category_id']}'),
      categoryLabel: json['category_label']?.toString(),
      merchant: json['merchant']?.toString(),
      amount: double.tryParse('${json['amount']}') ?? 0.0,
      category: (json['category'] ?? 'Uncategorized').toString(),
      expenseDate: (json['expense_date'] ?? '').toString(),
      notes: json['notes']?.toString(),
      source: (json['source'] ?? 'manual').toString(),
    );
  }
  bool get isPersonal => groupId == null;
  bool get isFromReceipt => source == 'ocr';
  String get displayTitle {
    if (merchant != null && merchant!.trim().isNotEmpty) return merchant!;
    if (categoryLabel != null && categoryLabel!.trim().isNotEmpty) {
      return categoryLabel!;
    }
    return category;
  }
  String? get linkLabel {
    if (planName == null) return null;
    if (categoryLabel == null) return planName;
    return '$planName · $categoryLabel';
  }
}

class ReceiptScanResult {
  final double? amount;
  final String? merchant;
  final String? date;
  final String rawText;
  final bool amountFromTotalLine;

  const ReceiptScanResult({
    this.amount,
    this.merchant,
    this.date,
    this.rawText = '',
    this.amountFromTotalLine = false,
  });

  bool get foundAnything => amount != null || merchant != null || date != null;
  bool get isEmpty => rawText.trim().isEmpty;
}