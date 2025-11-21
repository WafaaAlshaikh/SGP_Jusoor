// services/screening_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ScreeningService {
  static const String baseUrl = 'http://10.0.2.2:5000/api/screening';

  static Future<Map<String, dynamic>> startScreening({
    required int childAgeMonths,
    String? childGender,
    String? previousDiagnosis,
  }) async {
    try {
      print('🚀 Sending request to start screening...');
      print('📦 Data: age=$childAgeMonths, gender=$childGender');

      final response = await http.post(
        Uri.parse('$baseUrl/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'child_age_months': childAgeMonths,
          'child_gender': childGender,
          'previous_diagnosis': previousDiagnosis,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Screening started successfully');
        return data;
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        throw Exception('Failed to start screening: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Network error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> submitAnswer({
    required String sessionId,
    required int questionId,
    required dynamic answer,
  }) async {
    try {
      print('📨 Submitting answer - Session: $sessionId, Question: $questionId, Answer: $answer');

      final response = await http.post(
        Uri.parse('$baseUrl/answer'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': sessionId,
          'question_id': questionId,
          'answer': answer,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to submit answer: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Submit answer error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getResults(String sessionId) async {
    try {
      print('📊 Getting results for session: $sessionId');

      final response = await http.get(
        Uri.parse('$baseUrl/results/$sessionId'),
      ).timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to get results: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Get results error: $e');
      throw Exception('Network error: $e');
    }
  }

  // دالة جديدة للحصول على التقدم
  static int calculateProgress(String stage, int answeredCount) {
    switch (stage) {
      case 'initial_screening':
        return 20;
      case 'detailed_autism':
      case 'detailed_speech':
      case 'detailed_adhd_inattention':
      case 'detailed_adhd_hyperactive':
        return 60;
      case 'completed':
        return 100;
      default:
        return (answeredCount * 5).clamp(0, 100);
    }
  }

  static Future<Map<String, dynamic>> getEnhancedRecommendations(String sessionId) async {
    try {
      print('🤖 Getting enhanced recommendations for session: $sessionId');

      final response = await http.get(
        Uri.parse('$baseUrl/$sessionId/enhanced-recommendations'),
      ).timeout(const Duration(seconds: 30));

      print('📡 Enhanced response status: ${response.statusCode}');
      print('📄 Enhanced response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to get enhanced recommendations: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Get enhanced recommendations error: $e');
      throw Exception('Network error: $e');
    }
  }
}
