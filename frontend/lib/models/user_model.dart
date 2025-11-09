class User {
  final int userId;
  final String fullName;
  final String email;
  final String role;
  final String status;
  final String? token;

  User({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      fullName: json['full_name'],
      email: json['email'],
      role: json['role'],
      status: json['status'],
      token: json['token'],
    );
  }
}
