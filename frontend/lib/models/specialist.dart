import 'package:flutter/material.dart';

class Specialist {
  final int specialistId;
  final String fullName;
  final String email;
  final String specialization;
  final String? phone;
  final String? profilePicture;
  final String approvalStatus;
  final String? averageRating;
  final int? totalRatings;
  final String? ratingBadge;
  final int? yearsExperience;
  final double? salary;

  Specialist({
    required this.specialistId,
    required this.fullName,
    required this.email,
    required this.specialization,
    this.phone,
    this.profilePicture,
    required this.approvalStatus,
    this.averageRating,
    this.totalRatings,
    this.ratingBadge,
    this.yearsExperience,
    this.salary,
  });

  factory Specialist.fromJson(Map<String, dynamic> json) {
    return Specialist(
      specialistId: json['specialist_id'] ?? json['id'] ?? 0,
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      specialization: json['specialization'] ?? '',
      phone: json['phone'],
      profilePicture: json['profile_picture'],
      approvalStatus: json['approval_status']?.toString().toLowerCase() ?? 'pending',
      averageRating: json['average_rating']?.toString(),
      totalRatings: json['total_ratings'] ?? 0,
      ratingBadge: json['rating_badge'],
      yearsExperience: json['years_experience'],
      salary: json['salary']?.toDouble(),
    );
  }

  // الحصول على لون الحالة
  Color get statusColor {
    switch (approvalStatus.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  // الحصول على نص الحالة
  String get statusText {
    switch (approvalStatus.toLowerCase()) {
      case 'approved':
        return 'مفعل';
      case 'pending':
        return 'قيد المراجعة';
      case 'rejected':
        return 'مرفوض';
      case 'archived':
        return 'مؤرشف';
      default:
        return approvalStatus;
    }
  }
}

class SpecialistReport {
  final Specialist specialistInfo;
  final InstitutionInfo institutionInfo;
  final List<dynamic> schedules;
  final SpecialistStatistics statistics;
  final List<dynamic> upcomingSessions;
  final List<dynamic> recentCompletedSessions;
  final List<dynamic> recentCancelledSessions;
  final List<dynamic> recentRatings;
  final List<dynamic> monthlyAnalytics;

  SpecialistReport({
    required this.specialistInfo,
    required this.institutionInfo,
    required this.schedules,
    required this.statistics,
    required this.upcomingSessions,
    required this.recentCompletedSessions,
    required this.recentCancelledSessions,
    required this.recentRatings,
    required this.monthlyAnalytics,
  });

  factory SpecialistReport.fromJson(Map<String, dynamic> json) {
    return SpecialistReport(
      specialistInfo: Specialist.fromJson(json['specialist_info']),
      institutionInfo: InstitutionInfo.fromJson(json['institution_info']),
      schedules: json['schedules'] ?? [],
      statistics: SpecialistStatistics.fromJson(json['statistics']),
      upcomingSessions: json['upcoming_sessions'] ?? [],
      recentCompletedSessions: json['recent_completed_sessions'] ?? [],
      recentCancelledSessions: json['recent_cancelled_sessions'] ?? [],
      recentRatings: json['recent_ratings'] ?? [],
      monthlyAnalytics: json['monthly_analytics'] ?? [],
    );
  }
}

class InstitutionInfo {
  final int institutionId;
  final String institutionName;

  InstitutionInfo({
    required this.institutionId,
    required this.institutionName,
  });

  factory InstitutionInfo.fromJson(Map<String, dynamic> json) {
    return InstitutionInfo(
      institutionId: json['institution_id'] ?? 0,
      institutionName: json['institution_name'] ?? '',
    );
  }
}

class SpecialistStatistics {
  final SessionsSummary sessionsSummary;
  final RatingsSummary ratingsSummary;
  final VacationsSummary vacationsSummary;
  final ChildAttendance childAttendance;

  SpecialistStatistics({
    required this.sessionsSummary,
    required this.ratingsSummary,
    required this.vacationsSummary,
    required this.childAttendance,
  });

  factory SpecialistStatistics.fromJson(Map<String, dynamic> json) {
    return SpecialistStatistics(
      sessionsSummary: SessionsSummary.fromJson(json['sessions_summary']),
      ratingsSummary: RatingsSummary.fromJson(json['ratings_summary']),
      vacationsSummary: VacationsSummary.fromJson(json['vacations_summary']),
      childAttendance: ChildAttendance.fromJson(json['child_attendance']),
    );
  }
}

class SessionsSummary {
  final int totalSessions;
  final int upcomingSessions;
  final int completedSessions;
  final int cancelledSessions;
  final Map<String, dynamic> sessionsByStatus;

  SessionsSummary({
    required this.totalSessions,
    required this.upcomingSessions,
    required this.completedSessions,
    required this.cancelledSessions,
    required this.sessionsByStatus,
  });

  factory SessionsSummary.fromJson(Map<String, dynamic> json) {
    return SessionsSummary(
      totalSessions: json['total_sessions'] ?? 0,
      upcomingSessions: json['upcoming_sessions'] ?? 0,
      completedSessions: json['completed_sessions'] ?? 0,
      cancelledSessions: json['cancelled_sessions'] ?? 0,
      sessionsByStatus: Map<String, dynamic>.from(json['sessions_by_status'] ?? {}),
    );
  }
}

class RatingsSummary {
  final int totalRatings;
  final double averageRating;
  final Map<String, int> ratingDistribution;

  RatingsSummary({
    required this.totalRatings,
    required this.averageRating,
    required this.ratingDistribution,
  });

  factory RatingsSummary.fromJson(Map<String, dynamic> json) {
    final distribution = Map<String, int>.from(json['rating_distribution'] ?? {});

    return RatingsSummary(
      totalRatings: json['total_ratings'] ?? 0,
      averageRating: double.tryParse(json['average_rating']?.toString() ?? '0') ?? 0.0,
      ratingDistribution: distribution,
    );
  }
}

class VacationsSummary {
  final int totalRequests;
  final Map<String, int> vacationStats;
  final int approvedVacationDays;
  final int currentVacationsCount;
  final int upcomingVacationsCount;

  VacationsSummary({
    required this.totalRequests,
    required this.vacationStats,
    required this.approvedVacationDays,
    required this.currentVacationsCount,
    required this.upcomingVacationsCount,
  });

  factory VacationsSummary.fromJson(Map<String, dynamic> json) {
    return VacationsSummary(
      totalRequests: json['total_requests'] ?? 0,
      vacationStats: Map<String, int>.from(json['vacation_stats'] ?? {}),
      approvedVacationDays: json['approved_vacation_days'] ?? 0,
      currentVacationsCount: json['current_vacations_count'] ?? 0,
      upcomingVacationsCount: json['upcoming_vacations_count'] ?? 0,
    );
  }
}

class ChildAttendance {
  final int totalSessions;
  final int childAbsentCount;
  final int attendedSessions;
  final double attendanceRate;

  ChildAttendance({
    required this.totalSessions,
    required this.childAbsentCount,
    required this.attendedSessions,
    required this.attendanceRate,
  });

  factory ChildAttendance.fromJson(Map<String, dynamic> json) {
    return ChildAttendance(
      totalSessions: json['total_sessions'] ?? 0,
      childAbsentCount: int.tryParse(json['child_absent_count']?.toString() ?? '0') ?? 0,
      attendedSessions: int.tryParse(json['attended_sessions']?.toString() ?? '0') ?? 0,
      attendanceRate: double.tryParse(json['attendance_rate']?.toString() ?? '0') ?? 0.0,
    );
  }
}