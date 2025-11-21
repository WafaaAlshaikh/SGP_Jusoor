// models/screening_models.dart
class ScreeningSession {
  final String sessionId;
  final int childAgeMonths;
  final String? childGender;
  final String phase; // NEW: initial, detailed, performance
  final Map<String, dynamic> responses;
  final Map<String, dynamic> scores;
  final Map<String, dynamic> results;
  final DateTime? completedAt;

  ScreeningSession({
    required this.sessionId,
    required this.childAgeMonths,
    this.childGender,
    required this.phase,
    required this.responses,
    required this.scores,
    required this.results,
    this.completedAt,
  });

  factory ScreeningSession.fromJson(Map<String, dynamic> json) {
    return ScreeningSession(
      sessionId: json['session_id'],
      childAgeMonths: json['child_age_months'],
      childGender: json['child_gender'],
      phase: json['phase'] ?? json['screening_phase'] ?? 'initial',
      responses: json['responses'] ?? {},
      scores: json['scores'] ?? {},
      results: json['results'] ?? {},
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'child_age_months': childAgeMonths,
      'child_gender': childGender,
      'phase': phase,
      'responses': responses,
      'scores': scores,
      'results': results,
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

class ScreeningQuestion {
  final int id;
  final String text;
  final String type;
  final Map<String, dynamic>? options;
  final bool isCritical;
  final String category;
  final int order;

  ScreeningQuestion({
    required this.id,
    required this.text,
    required this.type,
    this.options,
    required this.isCritical,
    required this.category,
    required this.order,
  });

  factory ScreeningQuestion.fromJson(Map<String, dynamic> json) {
    return ScreeningQuestion(
      id: json['id'],
      text: json['text'],
      type: json['type'],
      options: json['options'],
      isCritical: json['is_critical'] ?? false,
      category: json['category'] ?? 'general',
      order: json['order'] ?? 0,
    );
  }

  List<dynamic> get choices {
    if (options != null && options!['choices'] != null) {
      return options!['choices'];
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'options': options,
      'is_critical': isCritical,
      'category': category,
      'order': order,
    };
  }
}

class ScreeningResults {
  final String? primaryConcern; // NEW
  final String? secondaryConcern; // NEW
  final String confidenceLevel; // NEW
  final Map<String, String> riskLevels; // NEW: {autism: high, adhd: medium, etc}
  final List<String> recommendations;
  final List<String> nextSteps;
  final List<String> redFlags; // NEW
  final List<String> positiveIndicators; // NEW
  final Map<String, dynamic> scores;
  final EnhancedAnalysis? enhancedAnalysis;

  // Keep backward compatibility
  String get autismRisk => riskLevels['autism'] ?? 'low';
  String get adhdRisk => riskLevels['adhd'] ?? riskLevels['adhd_inattention'] ?? 'none';
  String get speechDelay => riskLevels['speech'] ?? 'none';

  ScreeningResults({
    this.primaryConcern,
    this.secondaryConcern,
    required this.confidenceLevel,
    required this.riskLevels,
    required this.recommendations,
    required this.nextSteps,
    required this.redFlags,
    required this.positiveIndicators,
    required this.scores,
    this.enhancedAnalysis,
  });

  factory ScreeningResults.fromJson(Map<String, dynamic> json) {
    // Handle both old and new format
    Map<String, String> riskLevels = {};

    if (json['risk_levels'] != null) {
      // NEW FORMAT
      Map<String, dynamic> riskData = json['risk_levels'];
      riskData.forEach((key, value) {
        riskLevels[key] = value.toString();
      });
    } else {
      // OLD FORMAT (backward compatibility)
      riskLevels = {
        'autism': json['autism_risk'] ?? 'low',
        'adhd': json['adhd_risk'] ?? 'none',
        'speech': json['speech_delay'] ?? 'none',
      };
    }

    EnhancedAnalysis? enhancedAnalysis;
    if (json['enhanced_analysis'] != null) {
      enhancedAnalysis = EnhancedAnalysis.fromJson(json['enhanced_analysis']);
    }

    return ScreeningResults(
      primaryConcern: json['primary_concern'],
      secondaryConcern: json['secondary_concern'],
      confidenceLevel: json['confidence_level'] ?? 'medium',
      riskLevels: riskLevels,
      recommendations: List<String>.from(json['recommendations'] ?? []),
      nextSteps: List<String>.from(json['next_steps'] ?? []),
      redFlags: List<String>.from(json['red_flags'] ?? []),
      positiveIndicators: List<String>.from(json['positive_indicators'] ?? []),
      scores: json['scores'] ?? {},
      enhancedAnalysis: enhancedAnalysis,
    );
  }

  String get overallRisk {
    if (riskLevels.values.any((risk) => risk == 'high')) return 'high';
    if (riskLevels.values.any((risk) => risk == 'medium' || risk == 'significant')) return 'medium';
    return 'low';
  }

  String get primaryConcernLabel {
    if (primaryConcern == null) return 'No concerns detected';

    switch (primaryConcern) {
      case 'autism':
        return 'Autism Spectrum';
      case 'adhd_inattention':
        return 'ADHD - Inattention';
      case 'adhd_hyperactive':
        return 'ADHD - Hyperactivity';
      case 'speech_delay':
        return 'Speech/Language Delay';
      default:
        return primaryConcern!;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_concern': primaryConcern,
      'secondary_concern': secondaryConcern,
      'confidence_level': confidenceLevel,
      'risk_levels': riskLevels,
      'recommendations': recommendations,
      'next_steps': nextSteps,
      'red_flags': redFlags,
      'positive_indicators': positiveIndicators,
      'scores': scores,
      'enhanced_analysis': enhancedAnalysis?.toJson(),
    };
  }
}

class EnhancedAnalysis {
  final bool success;
  final AIAnalysis? aiAnalysis;
  final List<dynamic> recommendedInstitutions;
  final List<String> nextSteps;
  final Map<String, dynamic> screeningSummary;
  final String urgencyLevel;
  final String? error;
  final List<String>? recommendations; // NEW: Added recommendations field

  EnhancedAnalysis({
    required this.success,
    this.aiAnalysis,
    required this.recommendedInstitutions,
    required this.nextSteps,
    required this.screeningSummary,
    required this.urgencyLevel,
    this.error,
    this.recommendations, // NEW
  });

  factory EnhancedAnalysis.fromJson(Map<String, dynamic> json) {
    AIAnalysis? aiAnalysis;
    if (json['ai_analysis'] != null) {
      aiAnalysis = AIAnalysis.fromJson(json['ai_analysis']);
    }

    return EnhancedAnalysis(
      success: json['success'] ?? false,
      aiAnalysis: aiAnalysis,
      recommendedInstitutions: List<dynamic>.from(json['recommended_institutions'] ?? []),
      nextSteps: List<String>.from(json['next_steps'] ?? []),
      screeningSummary: Map<String, dynamic>.from(json['screening_summary'] ?? {}),
      urgencyLevel: json['urgency_level'] ?? 'routine',
      error: json['error'],
      recommendations: List<String>.from(json['recommendations'] ?? []), // NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'ai_analysis': aiAnalysis?.toJson(),
      'recommended_institutions': recommendedInstitutions,
      'next_steps': nextSteps,
      'screening_summary': screeningSummary,
      'urgency_level': urgencyLevel,
      'error': error,
      'recommendations': recommendations, // NEW
    };
  }
}

// NEW: AI Analysis Model
class AIAnalysis {
  final List<SuggestedCondition> suggestedConditions;
  final String riskLevel;
  final List<String> analyzedKeywords;
  final String source;
  final List<String>? recommendations; // NEW: Added recommendations field

  AIAnalysis({
    required this.suggestedConditions,
    required this.riskLevel,
    required this.analyzedKeywords,
    required this.source,
    this.recommendations, // NEW
  });

  factory AIAnalysis.fromJson(Map<String, dynamic> json) {
    return AIAnalysis(
      suggestedConditions: List<SuggestedCondition>.from(
        (json['suggested_conditions'] ?? []).map((x) => SuggestedCondition.fromJson(x))
      ),
      riskLevel: json['risk_level'] ?? 'unknown',
      analyzedKeywords: List<String>.from(json['analyzed_keywords'] ?? []),
      source: json['source'] ?? 'unknown',
      recommendations: List<String>.from(json['recommendations'] ?? []), // NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'suggested_conditions': suggestedConditions.map((e) => e.toJson()).toList(),
      'risk_level': riskLevel,
      'analyzed_keywords': analyzedKeywords,
      'source': source,
      'recommendations': recommendations, // NEW
    };
  }
}

// NEW: Suggested Condition Model
class SuggestedCondition {
  final String name;
  final String confidence;
  final List<String> matchingKeywords;

  SuggestedCondition({
    required this.name,
    required this.confidence,
    required this.matchingKeywords,
  });

  factory SuggestedCondition.fromJson(Map<String, dynamic> json) {
    return SuggestedCondition(
      name: json['name'] ?? '',
      confidence: json['confidence'] ?? '0%',
      matchingKeywords: List<String>.from(json['matching_keywords'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'confidence': confidence,
      'matching_keywords': matchingKeywords,
    };
  }
}