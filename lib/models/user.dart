class AppUser {
  AppUser({required this.id, required this.email, required this.fullName, this.role});
  final String id;
  final String email;
  final String fullName;
  final String? role;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id']?.toString() ?? '',
        email: j['email'] ?? '',
        fullName: j['full_name'] ?? j['fullName'] ?? '',
        role: j['role'],
      );
}
