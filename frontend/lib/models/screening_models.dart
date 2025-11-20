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
}