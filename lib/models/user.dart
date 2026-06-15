class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.role,
    this.organizationId,
    this.deletedAt,
  });
  final String id;
  final String email;
  final String fullName;
  final String? role;
  final String? organizationId;

  /// Set when the account is in the 14-day deletion grace window. Null = active.
  final DateTime? deletedAt;

  bool get pendingDeletion => deletedAt != null;

  /// 14 days after [deletedAt] — when the account is permanently deleted.
  DateTime? get deletionAt => deletedAt?.add(const Duration(days: 14));

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id']?.toString() ?? '',
        email: j['email'] ?? '',
        fullName: j['full_name'] ?? j['fullName'] ?? '',
        role: j['role'],
        organizationId: j['organization_id']?.toString(),
        deletedAt: DateTime.tryParse('${j['deleted_at'] ?? ''}'),
      );
}
