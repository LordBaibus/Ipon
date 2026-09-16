class Group {
  final int id;
  final String name;
  final String? description;
  final String inviteCode;

  final String role;
  final int memberCount;
  final bool isOwner;

  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.role,
    required this.memberCount,
    required this.isOwner,
    this.description,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      description: json['description'] == null
          ? null
          : json['description'].toString(),
      inviteCode: (json['invite_code'] ?? '').toString(),
      role: (json['role'] ?? 'member').toString(),
      memberCount: int.tryParse('${json['member_count']}') ?? 0,
      isOwner: json['is_owner'] == true,
    );
  }

  String get memberLabel => memberCount == 1 ? '1 member' : '$memberCount members';
}