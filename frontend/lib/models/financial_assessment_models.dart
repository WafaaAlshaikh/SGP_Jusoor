// models/financial_assessment_models.dart

// نموذج لتقييم مالي عام
class GeneralFinancialAssessment {
  final String flowId;
  final String type; // 'general' or 'specific'
  final Map<String, dynamic> parentInfo;
  final List<FinancialQuestion> questions;
  final String estimatedTime;
  final String privacyNotice;
  final String purpose;
  final List<String> nextSteps;
  final Map<String, dynamic>? existingAssessment;

  GeneralFinancialAssessment({
    required this.flowId,
    required this.type,
    required this.parentInfo,
    required this.questions,
    required this.estimatedTime,
    required this.privacyNotice,
    required this.purpose,
    required this.nextSteps,
    this.existingAssessment,
  });

  factory GeneralFinancialAssessment.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List)
        .map((q) => FinancialQuestion.fromJson(q))
        .toList();

    return GeneralFinancialAssessment(
      flowId: json['flow_id'] ?? '',
      type: json['type'] ?? 'general',
      parentInfo: json['parent'] ?? {},
      questions: questions,
      estimatedTime: json['estimated_time'] ?? '3-5 minutes',
      privacyNotice: json['privacy_notice'] ?? '',
      purpose: json['purpose'] ?? '',
      nextSteps: List<String>.from(json['next_steps'] ?? []),
      existingAssessment: json['existing_assessment'],
    );
  }
}

// نموذج لسؤال التقييم المالي
class FinancialQuestion {
  final String id;
  final String type; // 'range', 'select', 'number', 'multi_select', 'conditional', 'info'
  final String question;
  final String? description;
  final List<FinancialOption>? options;
  final bool required;
  final String? privacyLevel;
  final Map<String, dynamic>? followUp;
  final String? content; // للمحتوى الإعلامي
  final String? note;

  FinancialQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.description,
    this.options,
    required this.required,
    this.privacyLevel,
    this.followUp,
    this.content,
    this.note,
  });

  factory FinancialQuestion.fromJson(Map<String, dynamic> json) {
    List<FinancialOption>? options;
    if (json['options'] != null) {
      options = (json['options'] as List)
          .map((opt) => FinancialOption.fromJson(opt))
          .toList();
    }

    return FinancialQuestion(
      id: json['id'] ?? '',
      type: json['type'] ?? 'select',
      question: json['question'] ?? '',
      description: json['description'],
      options: options,
      required: json['required'] ?? true,
      privacyLevel: json['privacy_level'],
      followUp: json['follow_up'],
      content: json['content'],
      note: json['note'],
    );
  }
}

// نموذج لخيار التقييم
class FinancialOption {
  final String value;
  final String label;
  final double? scoreWeight;

  FinancialOption({
    required this.value,
    required this.label,
    this.scoreWeight,
  });

  factory FinancialOption.fromJson(Map<String, dynamic> json) {
    return FinancialOption(
      value: json['value'] ?? '',
      label: json['label'] ?? '',
      scoreWeight: json['score_weight'] != null 
          ? double.tryParse(json['score_weight'].toString()) 
          : null,
    );
  }
}

// نموذج لنتيجة التقييم المالي العام
class GeneralAssessmentResult {
  final String assessmentType; // 'general' or 'applied'
  final int financialScore;
  final String financialTier;
  final String tierLabel;
  final double suggestedDiscountPercentage;
  final String tierDescription;
  final int credibilityScore;
  final double credibilityMultiplier;
  final DateTime assessmentDate;
  final DateTime validUntil;
  final String assessmentId;
  
  final Map<String, dynamic> whatThisMeans;
  final List<Map<String, dynamic>> availableChildren;
  final List<Map<String, dynamic>> recommendedInstitutions;
  final List<Map<String, dynamic>> nextActions;
  final Map<String, dynamic> quickStats;

  GeneralAssessmentResult({
    required this.assessmentType,
    required this.financialScore,
    required this.financialTier,
    required this.tierLabel,
    required this.suggestedDiscountPercentage,
    required this.tierDescription,
    required this.credibilityScore,
    required this.credibilityMultiplier,
    required this.assessmentDate,
    required this.validUntil,
    required this.assessmentId,
    required this.whatThisMeans,
    required this.availableChildren,
    required this.recommendedInstitutions,
    required this.nextActions,
    required this.quickStats,
  });

  // في financial_assessment_models.dart

factory GeneralAssessmentResult.fromJson(Map<String, dynamic> json) {
  // دالة مساعدة
  double _safeParseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }
  
  int _safeParseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  final assessmentResults = json['assessment_results'] ?? {};
  
  return GeneralAssessmentResult(
    assessmentType: json['assessment_type'] ?? 'general',
    financialScore: _safeParseInt(assessmentResults['financial_score']),
    financialTier: assessmentResults['financial_tier']?.toString() ?? '',
    tierLabel: assessmentResults['tier_label']?.toString() ?? '',
    suggestedDiscountPercentage: _safeParseDouble(assessmentResults['suggested_discount_percentage']),
    tierDescription: assessmentResults['tier_description']?.toString() ?? '',
    credibilityScore: _safeParseInt(assessmentResults['credibility_score'], 50),
    credibilityMultiplier: _safeParseDouble(assessmentResults['credibility_multiplier'], 1.0),
    assessmentDate: DateTime.parse(assessmentResults['assessment_date']?.toString() ?? DateTime.now().toIso8601String()),
    validUntil: DateTime.parse(assessmentResults['valid_until']?.toString() ?? 
        DateTime.now().add(Duration(days: 30)).toIso8601String()),
    assessmentId: assessmentResults['assessment_id']?.toString() ?? '',
    whatThisMeans: json['what_this_means'] ?? {},
    availableChildren: List<Map<String, dynamic>>.from(json['available_children'] ?? []),
    recommendedInstitutions: List<Map<String, dynamic>>.from(json['recommended_institutions'] ?? []),
    nextActions: List<Map<String, dynamic>>.from(json['next_actions'] ?? []),
    quickStats: json['quick_stats'] ?? {},
  );
}

  String get tierColor {
    switch (financialTier) {
      case 'tier_1_critical':
        return '#EF4444'; // red
      case 'tier_2_high':
        return '#F97316'; // orange
      case 'tier_3_medium':
        return '#F59E0B'; // amber
      case 'tier_4_low':
        return '#10B981'; // emerald
      case 'tier_5_no_assistance':
        return '#6B7280'; // gray
      default:
        return '#6B7280';
    }
  }

  String get discountRangeText {
    switch (financialTier) {
      case 'tier_1_critical':
        return '80-100%';
      case 'tier_2_high':
        return '60-79%';
      case 'tier_3_medium':
        return '40-59%';
      case 'tier_4_low':
        return '20-39%';
      case 'tier_5_no_assistance':
        return '0-19%';
      default:
        return '0%';
    }
  }

  bool get hasValidAssessment {
    return validUntil.isAfter(DateTime.now());
  }

  int get daysRemaining {
    return validUntil.difference(DateTime.now()).inDays;
  }
}

// نموذج لتطبيق التقييم على طفل
class AppliedAssessmentResult {
  final String assessmentType;
  final Map<String, dynamic> parentAssessment;
  final Map<String, dynamic> childInfo;
  final Map<String, dynamic> institutionInfo;
  final Map<String, dynamic> financialAnalysis;
  final List<Map<String, dynamic>> sessionDetails;
  final bool documentsRequired;
  final Map<String, dynamic>? documentsInfo;
  final List<Map<String, dynamic>> nextSteps;

  AppliedAssessmentResult({
    required this.assessmentType,
    required this.parentAssessment,
    required this.childInfo,
    required this.institutionInfo,
    required this.financialAnalysis,
    required this.sessionDetails,
    required this.documentsRequired,
    this.documentsInfo,
    required this.nextSteps,
  });

  factory AppliedAssessmentResult.fromJson(Map<String, dynamic> json) {
    return AppliedAssessmentResult(
      assessmentType: json['assessment_type'] ?? 'applied',
      parentAssessment: json['parent_assessment'] ?? {},
      childInfo: json['child_info'] ?? {},
      institutionInfo: json['institution_info'] ?? {},
      financialAnalysis: json['financial_analysis'] ?? {},
      sessionDetails: List<Map<String, dynamic>>.from(json['session_details'] ?? []),
      documentsRequired: json['documents_required'] ?? false,
      documentsInfo: json['documents_info'],
      nextSteps: List<Map<String, dynamic>>.from(json['next_steps'] ?? []),
    );
  }
}