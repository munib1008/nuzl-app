class AppUser {
  AppUser({required this.id, required this.email, required this.fullName, this.role, this.organizationId});
  final String id;
  final String email;
  final String fullName;
  final String? role;
  final String? organizationId;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id']?.toString() ?? '',
        email: j['email'] ?? '',
        fullName: j['full_name'] ?? j['fullName'] ?? '',
        role: j['role'],
        organizationId: j['organization_id']?.toString(),
      );
}
