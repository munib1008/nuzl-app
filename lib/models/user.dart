class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.role,
    this.organizationId,
    this.deletedAt,
    this.activeRole,
    this.designation,
    this.roles = const [],
  });
  final String id;
  final String email;
  final String fullName;
  final String? role;
  final String? organizationId;

  /// Set when the account is in the 14-day deletion grace window. Null = active.
  final DateTime? deletedAt;

  /// Multi-role (UAT #3): the currently-selected role (server-backed), the
  /// Nuzler designation, and all roles held by the account.
  final String? activeRole;
  final String? designation;
  final List<Map<String, dynamic>> roles; // [{role, status, is_primary}]

  bool get pendingDeletion => deletedAt != null;
  DateTime? get deletionAt => deletedAt?.add(const Duration(days: 14));

  /// Approved roles available to switch to.
  List<String> get approvedRoles =>
      roles.where((r) => '${r['status']}' == 'approved').map((r) => '${r['role']}').toList();

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id']?.toString() ?? '',
        email: j['email'] ?? '',
        fullName: j['full_name'] ?? j['fullName'] ?? '',
        role: j['role'],
        organizationId: j['organization_id']?.toString(),
        deletedAt: DateTime.tryParse('${j['deleted_at'] ?? ''}'),
        activeRole: j['active_role'],
        designation: j['designation'],
        roles: (j['roles'] is List)
            ? (j['roles'] as List).map((e) => Map<String, dynamic>.from(e)).toList()
            : const [],
      );
}
