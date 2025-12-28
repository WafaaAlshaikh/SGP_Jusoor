// lib/models/admin_models.dart
class AdminDashboardStats {
  final int totalInstitutions;
  final int pendingInstitutions;
  final int totalUsers;
  final int pendingApprovals;
  final int totalChildren;
  final int totalSessions;
  final double totalDonations;
  final int openReports;
  final Map<String, dynamic> recentActivity;

  AdminDashboardStats({
    required this.totalInstitutions,
    required this.pendingInstitutions,
    required this.totalUsers,
    required this.pendingApprovals,
    required this.totalChildren,
    required this.totalSessions,
    required this.totalDonations,
    required this.openReports,
    required this.recentActivity,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalInstitutions: json['total_institutions'] ?? 0,
      pendingInstitutions: json['pending_institutions'] ?? 0,
      totalUsers: json['total_users'] ?? 0,
      pendingApprovals: json['pending_approvals'] ?? 0,
      totalChildren: json['total_children'] ?? 0,
      totalSessions: json['total_sessions'] ?? 0,
      totalDonations: json['total_donations']?.toDouble() ?? 0.0,
      openReports: json['open_reports'] ?? 0,
      recentActivity: json['recent_activity'] ?? {},
    );
  }
}

class Institution {
  final int institutionId;
  final String name;
  final String? description;
  final String? city;
  final String? region;
  final double? rating;
  final double? locationLat;
  final double? locationLng;
  final String? locationAddress;
  final String? contactEmail;  // غيره لـ nullable
  final String? contactPhone;  // غيره لـ nullable
  final String? approvalStatus;  // غيره لـ nullable
  final List<dynamic> managers;

  Institution({
    required this.institutionId,
    required this.name,
    this.description,
    this.city,
    this.region,
    this.rating,
    this.locationLat,
    this.locationLng,
    this.locationAddress,
    this.contactEmail,        // غير required
    this.contactPhone,        // غير required
    this.approvalStatus,      // غير required
    required this.managers,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      institutionId: json['institution_id'] ?? 0,  // أضف default value
      name: json['name'] ?? '',                    // أضف default value
      description: json['description'],
      city: json['city'],
      region: json['region'],
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
      locationLat: json['location_lat'] != null ? double.tryParse(json['location_lat'].toString()) : null,
      locationLng: json['location_lng'] != null ? double.tryParse(json['location_lng'].toString()) : null,
      locationAddress: json['location_address'],
      contactEmail: json['contact_email'],         // ممكن يكون null
      contactPhone: json['contact_phone'],         // ممكن يكون null
      approvalStatus: json['approval_status'],     // ممكن يكون null
      managers: json['managers'] ?? [],
    );
  }
}


class AdminUser {
  final int userId;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final String status;
  final DateTime? createdAt;

  AdminUser({
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.status,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      userId: json['user_id'] ?? 0,
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}