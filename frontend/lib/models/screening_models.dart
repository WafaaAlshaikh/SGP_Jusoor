// models/screening_models.dart
class ScreeningSession {
  final String? sessionId;
  final int childAge;
  final String? childGender;
  final String primaryType;
  
  ScreeningSession({
    this.sessionId,
    required this.childAge,
    this.childGender,
    required this.primaryType,
  });
}

// models/screening_models.dart
class ScreeningQuestion {
  final int id;
  final String questionText;
  final String questionType;
  final Map<String, dynamic>? options;
  final String category;
  final bool isGateway;
  final int order;
  final int riskScore;
  
  ScreeningQuestion({
    required this.id,
    required this.questionText,
    required this.questionType,
    this.options,
    required this.category,
    required this.isGateway,
    required this.order,
    required this.riskScore,
  });

  factory ScreeningQuestion.fromJson(Map<String, dynamic> json) {
    return ScreeningQuestion(
      id: json['id'] ?? 0,
      questionText: json['question_text'] ?? '',
      questionType: json['question_type'] ?? 'yes_no',
      options: json['options'],
      category: json['category'] ?? '',
      isGateway: _parseBool(json['is_gateway']), // 🔧 أصلح هنا
      order: json['order'] ?? 0,
      riskScore: json['risk_score'] ?? 0,
    );
  }

  // 🔧 دالة مساعدة لتحويل أي قيمة لـ boolean
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) {
      return value == 1;
    }
    return false;
  }
}


// models/screening_models.dart
class ScreeningResponse {
  final int questionId;
  final bool answer; // تأكد إنه bool
  final int riskScore;
  final String category;
  
  ScreeningResponse({
    required this.questionId,
    required this.answer,
    required this.riskScore,
    required this.category,
  });

  // إذا كنت تحتاج fromJson
  factory ScreeningResponse.fromJson(Map<String, dynamic> json) {
    return ScreeningResponse(
      questionId: json['question_id'] ?? 0,
      answer: _parseBool(json['answer']), // 🔧 أصلح هنا
      riskScore: json['risk_score'] ?? 0,
      category: json['category'] ?? '',
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) {
      return value == 1;
    }
    return false;
  }
}

class ScreeningResult {
  final Map<String, String> riskLevels;
  final Map<String, int> scores;
  final List<String> recommendations;
  final List<String> nextSteps;
  final String screeningId;
  
  ScreeningResult({
    required this.riskLevels,
    required this.scores,
    required this.recommendations,
    required this.nextSteps,
    required this.screeningId,
  });
}