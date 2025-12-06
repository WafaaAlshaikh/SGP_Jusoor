// lib/models/rating_models.dart
class SessionRating {
  final int id;
  final int sessionId;
  final int specialistId;
  final int parentId;
  final int childId;
  final double rating;
  final String ratingTag;
  final String? comment;
  final String sessionType;
  final DateTime ratedAt;
  final String parentName;
  final String childName;
  final String sessionDate;

  SessionRating({
    required this.id,
    required this.sessionId,
    required this.specialistId,
    required this.parentId,
    required this.childId,
    required this.rating,
    required this.ratingTag,
    this.comment,
    required this.sessionType,
    required this.ratedAt,
    required this.parentName,
    required this.childName,
    required this.sessionDate,
  });

  // في rating_models.dart - أصلحي دالة fromJson
  factory SessionRating.fromJson(Map<String, dynamic> json) {
    print('📊 Parsing rating JSON: $json');

    // معالجة خاصة للأرقام التي تأتي كنصوص
    int safeParseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        try {
          return int.parse(value);
        } catch (e) {
          print('⚠️ Failed to parse int from string: $value');
          return 0;
        }
      }
      return 0;
    }

    double safeParseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          print('⚠️ Failed to parse double from string: $value');
          return 0.0;
        }
      }
      return 0.0;
    }

    // تحليل التاريخ بأمان
    DateTime? safeParseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        if (value is DateTime) return value;
        if (value is String) return DateTime.parse(value);
        return null;
      } catch (e) {
        print(' Failed to parse DateTime: $value');
        return null;
      }
    }

    return SessionRating(
      id: safeParseInt(json['session_rating_id'] ?? json['id']),
      sessionId: safeParseInt(json['session_id']),
      specialistId: safeParseInt(json['specialist_id']),
      parentId: safeParseInt(json['parent_id']),
      childId: safeParseInt(json['child_id']),
      rating: safeParseDouble(json['rating']),
      ratingTag: json['rating_tag']?.toString() ?? '',
      comment: json['comment']?.toString(),
      sessionType: json['session_type']?.toString() ?? '',
      ratedAt: safeParseDateTime(json['rated_at']) ?? DateTime.now(),
      parentName: json['parent_name']?.toString() ?? 'Unknown',
      childName: json['child_name']?.toString() ?? 'Unknown',
      sessionDate: json['session_date']?.toString() ?? '',
    );
  }
}

class InstitutionReview {
  final int id;
  final int institutionId;
  final int parentId;
  final double facilitiesRating;
  final double staffRating;
  final double cleanlinessRating;
  final double accessibilityRating;
  final double overallRating;
  final String? reviewText;
  final bool wouldRecommend;
  final int basedOnVisits;
  final DateTime createdAt;
  final String parentName;
  final String? parentAvatar;
  final String institutionName;

  InstitutionReview({
    required this.id,
    required this.institutionId,
    required this.parentId,
    required this.facilitiesRating,
    required this.staffRating,
    required this.cleanlinessRating,
    required this.accessibilityRating,
    required this.overallRating,
    this.reviewText,
    required this.wouldRecommend,
    required this.basedOnVisits,
    required this.createdAt,
    required this.parentName,
    this.parentAvatar,
    required this.institutionName,
  });

  factory InstitutionReview.fromJson(Map<String, dynamic> json) {
    return InstitutionReview(
      id: json['institution_review_id'] ?? json['id'] ?? 0,
      institutionId: json['institution_id'] ?? 0,
      parentId: json['parent_id'] ?? 0,
      facilitiesRating: (json['facilities_rating'] as num?)?.toDouble() ?? 0.0,
      staffRating: (json['staff_rating'] as num?)?.toDouble() ?? 0.0,
      cleanlinessRating: (json['cleanliness_rating'] as num?)?.toDouble() ?? 0.0,
      accessibilityRating: (json['accessibility_rating'] as num?)?.toDouble() ?? 0.0,
      overallRating: (json['overall_rating'] as num?)?.toDouble() ?? 0.0,
      reviewText: json['review_text'],
      wouldRecommend: json['would_recommend'] ?? false,
      basedOnVisits: json['based_on_visits'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
      parentName: json['parent_name'] ?? '',
      parentAvatar: json['parent_avatar'],
      institutionName: json['institution_name'] ?? '',
    );
  }
}

class SpecialistFeedback {
  final int id;
  final int specialistId;
  final int parentId;
  final double professionalismScore;
  final double communicationScore;
  final double knowledgeScore;
  final double punctualityScore;
  final String? strengths;
  final String? improvementsNeeded;
  final bool wouldContinue;
  final DateTime submittedAt;
  final String parentName;
  final String specialistName;

  SpecialistFeedback({
    required this.id,
    required this.specialistId,
    required this.parentId,
    required this.professionalismScore,
    required this.communicationScore,
    required this.knowledgeScore,
    required this.punctualityScore,
    this.strengths,
    this.improvementsNeeded,
    required this.wouldContinue,
    required this.submittedAt,
    required this.parentName,
    required this.specialistName,
  });

  factory SpecialistFeedback.fromJson(Map<String, dynamic> json) {
    return SpecialistFeedback(
      id: json['feedback_id'] ?? json['id'] ?? 0,
      specialistId: json['specialist_id'] ?? 0,
      parentId: json['parent_id'] ?? 0,
      professionalismScore: (json['professionalism_score'] as num?)?.toDouble() ?? 0.0,
      communicationScore: (json['communication_score'] as num?)?.toDouble() ?? 0.0,
      knowledgeScore: (json['knowledge_score'] as num?)?.toDouble() ?? 0.0,
      punctualityScore: (json['punctuality_score'] as num?)?.toDouble() ?? 0.0,
      strengths: json['strengths'],
      improvementsNeeded: json['improvements_needed'],
      wouldContinue: json['would_continue'] ?? false,
      submittedAt: DateTime.parse(json['submitted_at'] ?? DateTime.now().toString()),
      parentName: json['parent_name'] ?? '',
      specialistName: json['specialist_name'] ?? '',
    );
  }
}

class RatingStats {
  final double averageRating;
  final int totalRatings;
  final int fiveStarCount;
  final int oneStarCount;
  final Map<int, int> distribution;

  RatingStats({
    required this.averageRating,
    required this.totalRatings,
    required this.fiveStarCount,
    required this.oneStarCount,
    required this.distribution,
  });

  factory RatingStats.fromJson(Map<String, dynamic> json) {
    final distribution = Map<int, int>.from(json['distribution'] ?? {});
    
    return RatingStats(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['total_ratings'] ?? 0,
      fiveStarCount: json['five_star_count'] ?? 0,
      oneStarCount: json['one_star_count'] ?? 0,
      distribution: distribution,
    );
  }
}

class InstitutionReviewStats {
  final double averageRating;
  final int totalReviews;
  final int recommendations;
  final double facilitiesRating;
  final double staffRating;
  final double cleanlinessRating;
  final double accessibilityRating;

  InstitutionReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.recommendations,
    required this.facilitiesRating,
    required this.staffRating,
    required this.cleanlinessRating,
    required this.accessibilityRating,
  });

  factory InstitutionReviewStats.fromJson(Map<String, dynamic> json) {
    return InstitutionReviewStats(
      averageRating: double.parse(json['average_rating']?.toString() ?? '0.0'),
      totalReviews: json['total_reviews'] ?? 0,
      recommendations: json['recommendations'] ?? 0,
      facilitiesRating: double.parse(json['facilities_rating']?.toString() ?? '0.0'),
      staffRating: double.parse(json['staff_rating']?.toString() ?? '0.0'),
      cleanlinessRating: double.parse(json['cleanliness_rating']?.toString() ?? '0.0'),
      accessibilityRating: double.parse(json['accessibility_rating']?.toString() ?? '0.0'),
    );
  }
}