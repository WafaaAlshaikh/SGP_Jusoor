class AdminDashboardStats {
  final int totalUsers;
  final int totalInstitutions;
  final int totalChildren;
  final int totalSessions;
  final Map<String, dynamic> usersByRole;
  final Map<String, dynamic> institutionStats;
  final Map<String, dynamic> childrenStats;
  final Map<String, dynamic> sessionStats;

  AdminDashboardStats({
    required this.totalUsers,
    required this.totalInstitutions,
    required this.totalChildren,
    required this.totalSessions,
    required this.usersByRole,
    required this.institutionStats,
    required this.childrenStats,
    required this.sessionStats,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalUsers: json['users']['total'] ?? 0,
      totalInstitutions: json['institutions']['total'] ?? 0,
      totalChildren: json['children']['total'] ?? 0,
      totalSessions: json['sessions']['total'] ?? 0,
      usersByRole: Map<String, dynamic>.from(json['users']['byRole'] ?? {}),
      institutionStats: Map<String, dynamic>.from(json['institutions'] ?? {}),
      childrenStats: Map<String, dynamic>.from(json['children'] ?? {}),
      sessionStats: Map<String, dynamic>.from(json['sessions'] ?? {}),
    );
  }
}

class Institution {
  final int institutionId;
  final String name;
  final String? description;
  final String city;
  final String? region;
  final String approvalStatus;
  final double? rating;
  final DateTime createdAt;

  Institution({
    required this.institutionId,
    required this.name,
    this.description,
    required this.city,
    this.region,
    required this.approvalStatus,
    this.rating,
    required this.createdAt,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      institutionId: json['institution_id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      city: json['city'] ?? '',
      region: json['region'],
      approvalStatus: json['approval_status'] ?? 'Pending',
      rating: json['rating'] != null ? double.parse(json['rating'].toString()) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class User {
  final int userId;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final String status;
  final DateTime createdAt;

  User({
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] ?? 0,
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'Parent',
      status: json['status'] ?? 'Pending',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}