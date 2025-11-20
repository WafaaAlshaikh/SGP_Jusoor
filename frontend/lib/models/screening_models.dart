// models/screening_models.dart
class ScreeningSession {
  final String sessionId;
  final int childAgeMonths;
  final String? childGender;
  final Map<String, dynamic> responses;
  final Map<String, dynamic> scores;
  final Map<String, dynamic> results;
  final DateTime? completedAt;

  ScreeningSession({
    required this.sessionId,
    required this.childAgeMonths,
    this.childGender,
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
  final String autismRisk;
  final String adhdRisk;
  final String speechDelay;
  final List<String> recommendations;
  final List<String> nextSteps;
  final Map<String, dynamic> scores;

  ScreeningResults({
    required this.autismRisk,
    required this.adhdRisk,
    required this.speechDelay,
    required this.recommendations,
    required this.nextSteps,
    required this.scores,
  });

  factory ScreeningResults.fromJson(Map<String, dynamic> json) {
    return ScreeningResults(
      autismRisk: json['autism_risk'] ?? 'low',
      adhdRisk: json['adhd_risk'] ?? 'none',
      speechDelay: json['speech_delay'] ?? 'none',
      recommendations: List<String>.from(json['recommendations'] ?? []),
      nextSteps: List<String>.from(json['next_steps'] ?? []),
      scores: json['scores'] ?? {},
    );
  }

  String get overallRisk {
    if (autismRisk == 'high' || adhdRisk == 'high') return 'high';
    if (autismRisk == 'medium' || adhdRisk == 'medium' || speechDelay == 'significant') return 'medium';
    return 'low';
  }
}