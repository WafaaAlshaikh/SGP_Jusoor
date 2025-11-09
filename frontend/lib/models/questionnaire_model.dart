class Question {
  final int questionId;
  final String category;
  final String questionText;
  final String questionType;
  final List<String> options;
  final double weight;
  final List<String> targetConditions;
  final int minAge;
  final int maxAge;
  final Map<String, dynamic>? nextQuestionLogic;

  Question({
    required this.questionId,
    required this.category,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.weight,
    required this.targetConditions,
    required this.minAge,
    required this.maxAge,
    this.nextQuestionLogic,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      questionId: _parseInt(json['question_id'] ?? json['id'] ?? 0),
      category: json['category']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? json['text']?.toString() ?? '',
      questionType: json['question_type']?.toString() ?? 'Multiple Choice',
      options: _parseOptions(json['options']),
      weight: _parseDouble(json['weight'] ?? 1.0),
      targetConditions: _parseStringList(json['target_conditions']),
      minAge: _parseInt(json['min_age'] ?? 0),
      maxAge: _parseInt(json['max_age'] ?? 18),
      nextQuestionLogic: _parseMap(json['next_question_logic']),
    );
  }

  // دوال مساعدة لتحويل البيانات
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 1.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 1.0;
    return 1.0;
  }

  static List<String> _parseOptions(dynamic options) {
    if (options == null) return [];
    if (options is List) {
      return options.map((item) => item.toString()).toList();
    }
    return [];
  }

  static List<String> _parseStringList(dynamic list) {
    if (list == null) return [];
    if (list is List) {
      return list.map((item) => item.toString()).toList();
    }
    return [];
  }

  static Map<String, dynamic>? _parseMap(dynamic map) {
    if (map == null) return null;
    if (map is Map) {
      return Map<String, dynamic>.from(map);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'category': category,
      'question_text': questionText,
      'question_type': questionType,
      'options': options,
      'weight': weight,
      'target_conditions': targetConditions,
      'min_age': minAge,
      'max_age': maxAge,
      'next_question_logic': nextQuestionLogic,
    };
  }
}