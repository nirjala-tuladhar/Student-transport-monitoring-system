class AppUser {
  final String id;
  final String? email;
  final String role;

  AppUser({
    required this.id,
    this.email,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      email: map['email'],
      // Safely access the role from user_metadata
      role: (map['user_metadata'] as Map<String, dynamic>?)?['role'] as String? ?? 'unknown',
    );
  }
}
