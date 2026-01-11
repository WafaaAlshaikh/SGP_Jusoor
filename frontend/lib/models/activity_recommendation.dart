import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';

class ActivityRecommendation {
  final int id;
  final int childId;
  final int parentId;
  final String activityType; // motor_skills, social_skills, cognitive_skills, communication_skills, sensory_activities, daily_living_skills
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final String materialsAr;
  final String materialsEn;
  final int durationMinutes;
  final String difficultyLevel; // beginner, intermediate, advanced
  final String targetSkillsAr;
  final String targetSkillsEn;
  final bool isAiGenerated;
  final String? basedOnDocument;
  final dynamic documentAnalysisSummary; // يمكن أن يكون String أو Map
  final String status; // suggested, in_progress, completed, skipped
  final DateTime createdAt;
  final DateTime? completedAt;
  final int? parentRating; // 1-5
  final String? childEngagement; // low, medium, high
  final String? parentNotes;
  final DateTime updatedAt;
  
  // الحقول الجديدة لتتبع التقدم
  final int? progressPercentage; // 0-100
  final DateTime? startedAt;
  final List<String>? childReactions; // List of emojis or reactions
  final bool? isFavorite;
  final int? timesCompleted;
  
  // الحقول المتعلقة بالـ AI
  final double? aiConfidenceScore;
  final String? aiAnalysisSource; // groq_ai, local_ai, etc.
  final Map<String, dynamic>? aiMetadata;

  ActivityRecommendation({
    required this.id,
    required this.childId,
    required this.parentId,
    required this.activityType,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.materialsAr,
    required this.materialsEn,
    required this.durationMinutes,
    required this.difficultyLevel,
    required this.targetSkillsAr,
    required this.targetSkillsEn,
    required this.isAiGenerated,
    this.basedOnDocument,
    this.documentAnalysisSummary,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.parentRating,
    this.childEngagement,
    this.parentNotes,
    required this.updatedAt,
    
    // الحقول الجديدة
    this.progressPercentage,
    this.startedAt,
    this.childReactions,
    this.isFavorite,
    this.timesCompleted,
    
    // الحقول المتعلقة بالـ AI
    this.aiConfidenceScore,
    this.aiAnalysisSource,
    this.aiMetadata,
  });

  // Factory method to create from JSON
  factory ActivityRecommendation.fromJson(Map<String, dynamic> json) {
    print('🔄 ActivityRecommendation.fromJson: $json');
    
    // معالجة التواريخ
    DateTime? parseDateTime(dynamic date) {
      if (date == null) return null;
      if (date is String) {
        return DateTime.tryParse(date)?.toLocal();
      }
      return null;
    }
    
    // معالجة documentAnalysisSummary
    dynamic parseDocumentAnalysis(dynamic summary) {
      if (summary == null) return null;
      if (summary is String) {
        try {
          return jsonDecode(summary);
        } catch (e) {
          return summary;
        }
      }
      return summary;
    }
    
    // معالجة childReactions
    List<String>? parseChildReactions(dynamic reactions) {
      if (reactions == null) return null;
      if (reactions is String) {
        try {
          final parsed = jsonDecode(reactions);
          if (parsed is List) {
            return parsed.map((e) => e.toString()).toList();
          }
        } catch (e) {
          return reactions.split(',');
        }
      } else if (reactions is List) {
        return reactions.map((e) => e.toString()).toList();
      }
      return null;
    }
    
    // معالجة aiMetadata
    Map<String, dynamic>? parseAiMetadata(dynamic metadata) {
      if (metadata == null) return null;
      if (metadata is String) {
        try {
          return jsonDecode(metadata);
        } catch (e) {
          return {'raw': metadata};
        }
      } else if (metadata is Map) {
        return Map<String, dynamic>.from(metadata);
      }
      return null;
    }

    return ActivityRecommendation(
      id: json['id'] ?? json['recommendation_id'] ?? 0,
      childId: json['child_id'] as int? ?? 0,
      parentId: json['parent_id'] as int? ?? 0,
      activityType: json['activity_type'] as String? ?? 'cognitive_skills',
      titleAr: json['title_ar'] as String? ?? 'نشاط تفاعلي',
      titleEn: json['title_en'] as String? ?? 'Interactive Activity',
      descriptionAr: json['description_ar'] as String? ?? 'وصف النشاط',
      descriptionEn: json['description_en'] as String? ?? 'Activity description',
      materialsAr: json['materials_ar'] as String? ?? '',
      materialsEn: json['materials_en'] as String? ?? '',
      durationMinutes: json['duration_minutes'] as int? ?? 10,
      difficultyLevel: json['difficulty_level'] as String? ?? 'beginner',
      targetSkillsAr: json['target_skills_ar'] as String? ?? 'تنمية المهارات',
      targetSkillsEn: json['target_skills_en'] as String? ?? 'Skill development',
      isAiGenerated: json['ai_generated'] as bool? ?? json['is_ai_generated'] as bool? ?? true,
      basedOnDocument: json['based_on_document'] as String?,
      documentAnalysisSummary: parseDocumentAnalysis(json['document_analysis_summary']),
      status: json['status'] as String? ?? 'suggested',
      createdAt: parseDateTime(json['created_at']) ?? DateTime.now(),
      completedAt: parseDateTime(json['completed_at']),
      parentRating: json['parent_rating'] as int?,
      childEngagement: json['child_engagement'] as String?,
      parentNotes: json['parent_notes'] as String?,
      updatedAt: parseDateTime(json['updated_at']) ?? DateTime.now(),
      
      // الحقول الجديدة
      progressPercentage: json['progress_percentage'] as int?,
      startedAt: parseDateTime(json['started_at']),
      childReactions: parseChildReactions(json['child_reactions']),
      isFavorite: json['is_favorite'] as bool? ?? false,
      timesCompleted: json['times_completed'] as int? ?? 0,
      
      // الحقول المتعلقة بالـ AI
      aiConfidenceScore: json['ai_confidence_score'] != null 
          ? (json['ai_confidence_score'] is double 
              ? json['ai_confidence_score'] 
              : double.tryParse(json['ai_confidence_score'].toString()))
          : null,
      aiAnalysisSource: json['ai_analysis_source'] as String?,
      aiMetadata: parseAiMetadata(json['ai_metadata']),
    );
  }

  // Convert to JSON for sending to backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'parent_id': parentId,
      'activity_type': activityType,
      'title_ar': titleAr,
      'title_en': titleEn,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'materials_ar': materialsAr,
      'materials_en': materialsEn,
      'duration_minutes': durationMinutes,
      'difficulty_level': difficultyLevel,
      'target_skills_ar': targetSkillsAr,
      'target_skills_en': targetSkillsEn,
      'ai_generated': isAiGenerated,
      'based_on_document': basedOnDocument,
      'document_analysis_summary': documentAnalysisSummary is Map 
          ? jsonEncode(documentAnalysisSummary)
          : documentAnalysisSummary?.toString(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'parent_rating': parentRating,
      'child_engagement': childEngagement,
      'parent_notes': parentNotes,
      'updated_at': updatedAt.toIso8601String(),
      
      // الحقول الجديدة
      'progress_percentage': progressPercentage,
      'started_at': startedAt?.toIso8601String(),
      'child_reactions': childReactions != null 
          ? jsonEncode(childReactions)
          : null,
      'is_favorite': isFavorite,
      'times_completed': timesCompleted,
      
      // الحقول المتعلقة بالـ AI
      'ai_confidence_score': aiConfidenceScore,
      'ai_analysis_source': aiAnalysisSource,
      'ai_metadata': aiMetadata != null ? jsonEncode(aiMetadata) : null,
    };
  }

  // ============ Helper Methods ============

  String get displayTitle {
    // يمكنك إضافة منطق للغة هنا بناءً على إعدادات المستخدم
    return titleAr.isNotEmpty ? titleAr : titleEn;
  }

  String get displayDescription {
    return descriptionAr.isNotEmpty ? descriptionAr : descriptionEn;
  }

  String get displayMaterials {
    return materialsAr.isNotEmpty ? materialsAr : materialsEn;
  }

  String get displayTargetSkills {
    return targetSkillsAr.isNotEmpty ? targetSkillsAr : targetSkillsEn;
  }

  // Get activity type display name
  String get activityTypeDisplay {
    const Map<String, String> typeNames = {
      'motor_skills': 'المهارات الحركية',
      'social_skills': 'المهارات الاجتماعية',
      'cognitive_skills': 'المهارات الإدراكية',
      'communication_skills': 'مهارات التواصل',
      'sensory_activities': 'الأنشطة الحسية',
      'daily_living_skills': 'مهارات الحياة اليومية',
    };
    return typeNames[activityType] ?? 'نشاط';
  }

  String get activityTypeDisplayEn {
    const Map<String, String> typeNames = {
      'motor_skills': 'Motor Skills',
      'social_skills': 'Social Skills',
      'cognitive_skills': 'Cognitive Skills',
      'communication_skills': 'Communication Skills',
      'sensory_activities': 'Sensory Activities',
      'daily_living_skills': 'Daily Living Skills',
    };
    return typeNames[activityType] ?? 'Activity';
  }

  // Get icon for activity type
  String get activityTypeIcon {
    const Map<String, String> typeIcons = {
      'motor_skills': '🏃‍♂️',
      'social_skills': '👥',
      'cognitive_skills': '🧠',
      'communication_skills': '💬',
      'sensory_activities': '🎨',
      'daily_living_skills': '🏠',
    };
    return typeIcons[activityType] ?? '🎮';
  }

  IconData get activityTypeMaterialIcon {
    const Map<String, IconData> typeIcons = {
      'motor_skills': Icons.directions_run,
      'social_skills': Icons.people,
      'cognitive_skills': Icons.psychology,
      'communication_skills': Icons.chat,
      'sensory_activities': Icons.brush,
      'daily_living_skills': Icons.home,
    };
    return typeIcons[activityType] ?? Icons.gamepad;
  }

  // Get color for activity type
  Color get activityTypeColor {
    const Map<String, Color> typeColors = {
      'motor_skills': Color(0xFF2196F3), // Blue
      'social_skills': Color(0xFF4CAF50), // Green
      'cognitive_skills': Color(0xFFFF9800), // Orange
      'communication_skills': Color(0xFF9C27B0), // Purple
      'sensory_activities': Color(0xFFE91E63), // Pink
      'daily_living_skills': Color(0xFF009688), // Teal
    };
    return typeColors[activityType] ?? Color(0xFF607D8B); // Blue Grey
  }

  // Check if activity is completed
  bool get isCompleted => status == 'completed';

  // Check if activity is in progress
  bool get isInProgress => status == 'in_progress';

  // Check if activity is suggested
  bool get isSuggested => status == 'suggested';

  // Get status display text
  String get statusDisplay {
    const Map<String, String> statusNames = {
      'suggested': 'مقترح',
      'in_progress': 'قيد التنفيذ',
      'completed': 'مكتمل',
      'skipped': 'تم التخطي',
    };
    return statusNames[status] ?? status;
  }

  String get statusDisplayEn {
    const Map<String, String> statusNames = {
      'suggested': 'Suggested',
      'in_progress': 'In Progress',
      'completed': 'Completed',
      'skipped': 'Skipped',
    };
    return statusNames[status] ?? status;
  }

  // Get difficulty display text
  String get difficultyDisplay {
    const Map<String, String> difficultyNames = {
      'beginner': 'مبتدئ',
      'intermediate': 'متوسط',
      'advanced': 'متقدم',
    };
    return difficultyNames[difficultyLevel] ?? difficultyLevel;
  }

  String get difficultyDisplayEn {
    const Map<String, String> difficultyNames = {
      'beginner': 'Beginner',
      'intermediate': 'Intermediate',
      'advanced': 'Advanced',
    };
    return difficultyNames[difficultyLevel] ?? difficultyLevel;
  }

  // Get child engagement display text
  String get childEngagementDisplay {
    if (childEngagement == null) return 'غير محدد';
    
    const Map<String, String> engagementNames = {
      'low': 'منخفض',
      'medium': 'متوسط',
      'high': 'مرتفع',
    };
    return engagementNames[childEngagement!] ?? childEngagement!;
  }

  String get childEngagementDisplayEn {
    if (childEngagement == null) return 'Not specified';
    
    const Map<String, String> engagementNames = {
      'low': 'Low',
      'medium': 'Medium',
      'high': 'High',
    };
    return engagementNames[childEngagement!] ?? childEngagement!;
  }

  // Format duration for display
  String get durationDisplay {
    if (durationMinutes < 60) {
      return '$durationMinutes دقيقة';
    } else {
      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;
      if (minutes == 0) {
        return '$hours ساعة';
      } else {
        return '$hours ساعة و $minutes دقيقة';
      }
    }
  }

  String get durationDisplayEn {
    if (durationMinutes < 60) {
      return '$durationMinutes minutes';
    } else {
      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;
      if (minutes == 0) {
        return '$hours hour${hours > 1 ? "s" : ""}';
      } else {
        return '$hours hour${hours > 1 ? "s" : ""} $minutes minutes';
      }
    }
  }

  // Get completion date display
  String get completionDateDisplay {
    if (completedAt == null) return 'لم يكتمل بعد';
    
    final now = DateTime.now();
    final difference = now.difference(completedAt!);
    
    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'قبل ${difference.inDays} أيام';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'قبل $weeks أسابيع';
    } else {
      return '${completedAt!.day}/${completedAt!.month}/${completedAt!.year}';
    }
  }

  String get completionDateDisplayEn {
    if (completedAt == null) return 'Not completed yet';
    
    final now = DateTime.now();
    final difference = now.difference(completedAt!);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? "s" : ""} ago';
    } else {
      return '${completedAt!.month}/${completedAt!.day}/${completedAt!.year}';
    }
  }

  // Get creation date display
  String get creationDateDisplay {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'قبل ${difference.inDays} أيام';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'قبل $weeks أسابيع';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  String get creationDateDisplayEn {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? "s" : ""} ago';
    } else {
      return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
    }
  }

  // Get rating stars
  List<bool> get ratingStars {
    if (parentRating == null) return List.filled(5, false);
    return List.generate(5, (index) => index < parentRating!);
  }

  // Get rating display text
  String get ratingDisplay {
    if (parentRating == null) return 'لم يتم التقييم';
    return '$parentRating/5';
  }

  String get ratingDisplayEn {
    if (parentRating == null) return 'Not rated';
    return '$parentRating/5';
  }

  // Get AI confidence display
  String get aiConfidenceDisplay {
    if (aiConfidenceScore == null) return 'غير متوفر';
    return '${(aiConfidenceScore! * 100).toStringAsFixed(1)}%';
  }

  String get aiConfidenceDisplayEn {
    if (aiConfidenceScore == null) return 'Not available';
    return '${(aiConfidenceScore! * 100).toStringAsFixed(1)}%';
  }

  // Get progress percentage
  int get calculatedProgress {
    if (progressPercentage != null) return progressPercentage!;
    if (isCompleted) return 100;
    if (isInProgress) return 50;
    return 0;
  }

  // Get child reactions emojis
  String get childReactionsEmojis {
    if (childReactions == null || childReactions!.isEmpty) return '😊';
    return childReactions!.join(' ');
  }

  // Check if activity was started
  bool get wasStarted => startedAt != null;

  // Get time since started
  String get timeSinceStarted {
    if (startedAt == null) return 'لم يبدأ بعد';
    
    final now = DateTime.now();
    final difference = now.difference(startedAt!);
    
    if (difference.inMinutes < 60) {
      return 'بدأ منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'بدأ منذ ${difference.inHours} ساعة';
    } else {
      return 'بدأ منذ ${difference.inDays} يوم';
    }
  }

  String get timeSinceStartedEn {
    if (startedAt == null) return 'Not started yet';
    
    final now = DateTime.now();
    final difference = now.difference(startedAt!);
    
    if (difference.inMinutes < 60) {
      return 'Started ${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return 'Started ${difference.inHours} hours ago';
    } else {
      return 'Started ${difference.inDays} days ago';
    }
  }

  // Get completion count text
  String get completionCountText {
    if (timesCompleted == null || timesCompleted == 0) return 'لم يكمل بعد';
    if (timesCompleted == 1) return 'مكتمل مرة واحدة';
    return 'مكتمل $timesCompleted مرات';
  }

  String get completionCountTextEn {
    if (timesCompleted == null || timesCompleted == 0) return 'Not completed yet';
    if (timesCompleted == 1) return 'Completed once';
    return 'Completed $timesCompleted times';
  }

  // Get document analysis summary text
  String get documentAnalysisText {
    if (documentAnalysisSummary == null) return 'لا يوجد تحليل للمستند';
    
    if (documentAnalysisSummary is Map) {
      final summary = documentAnalysisSummary as Map<String, dynamic>;
      
      // محاولة استخراج معلومات مفيدة
      final condition = summary['primary_condition'];
      if (condition is Map) {
        final name = condition['name_ar'] ?? condition['name_en'];
        if (name != null) return 'بناءً على تشخيص: $name';
      }
      
      final age = summary['child_age'];
      if (age != null) return 'مخصص لعمر: $age سنوات';
      
      return 'مبنية على تحليل المستند';
    }
    
    return documentAnalysisSummary.toString();
  }

  String get documentAnalysisTextEn {
    if (documentAnalysisSummary == null) return 'No document analysis';
    
    if (documentAnalysisSummary is Map) {
      final summary = documentAnalysisSummary as Map<String, dynamic>;
      
      final condition = summary['primary_condition'];
      if (condition is Map) {
        final name = condition['name_en'] ?? condition['name_ar'];
        if (name != null) return 'Based on diagnosis: $name';
      }
      
      final age = summary['child_age'];
      if (age != null) return 'Customized for age: $age years';
      
      return 'Based on document analysis';
    }
    
    return documentAnalysisSummary.toString();
  }

  // Clone with updated status
  ActivityRecommendation copyWith({
    int? id,
    int? childId,
    int? parentId,
    String? activityType,
    String? titleAr,
    String? titleEn,
    String? descriptionAr,
    String? descriptionEn,
    String? materialsAr,
    String? materialsEn,
    int? durationMinutes,
    String? difficultyLevel,
    String? targetSkillsAr,
    String? targetSkillsEn,
    bool? isAiGenerated,
    String? basedOnDocument,
    dynamic documentAnalysisSummary,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
    int? parentRating,
    String? childEngagement,
    String? parentNotes,
    DateTime? updatedAt,
    int? progressPercentage,
    DateTime? startedAt,
    List<String>? childReactions,
    bool? isFavorite,
    int? timesCompleted,
    double? aiConfidenceScore,
    String? aiAnalysisSource,
    Map<String, dynamic>? aiMetadata,
  }) {
    return ActivityRecommendation(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      parentId: parentId ?? this.parentId,
      activityType: activityType ?? this.activityType,
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      materialsAr: materialsAr ?? this.materialsAr,
      materialsEn: materialsEn ?? this.materialsEn,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      targetSkillsAr: targetSkillsAr ?? this.targetSkillsAr,
      targetSkillsEn: targetSkillsEn ?? this.targetSkillsEn,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      basedOnDocument: basedOnDocument ?? this.basedOnDocument,
      documentAnalysisSummary: documentAnalysisSummary ?? this.documentAnalysisSummary,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      parentRating: parentRating ?? this.parentRating,
      childEngagement: childEngagement ?? this.childEngagement,
      parentNotes: parentNotes ?? this.parentNotes,
      updatedAt: updatedAt ?? this.updatedAt,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      startedAt: startedAt ?? this.startedAt,
      childReactions: childReactions ?? this.childReactions,
      isFavorite: isFavorite ?? this.isFavorite,
      timesCompleted: timesCompleted ?? this.timesCompleted,
      aiConfidenceScore: aiConfidenceScore ?? this.aiConfidenceScore,
      aiAnalysisSource: aiAnalysisSource ?? this.aiAnalysisSource,
      aiMetadata: aiMetadata ?? this.aiMetadata,
    );
  }

  @override
  String toString() {
    return 'ActivityRecommendation{id: $id, titleAr: $titleAr, status: $status, type: $activityType}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityRecommendation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // Helper for building display card
  Widget buildCard({bool showActions = true, VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activityTypeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      activityTypeMaterialIcon,
                      color: activityTypeColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          activityTypeDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            color: activityTypeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isFavorite == true)
                    Icon(Icons.favorite, color: Colors.red, size: 20),
                ],
              ),
              
              SizedBox(height: 12),
              
              Text(
                displayDescription,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 12),
              
              // Progress bar
              LinearProgressIndicator(
                value: calculatedProgress / 100,
                backgroundColor: Colors.grey[200],
                color: activityTypeColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              
              SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        durationDisplay,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusDisplay,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'suggested':
        return Colors.blue;
      case 'skipped':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}