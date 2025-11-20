// services/screening_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ScreeningService {
  static const String baseUrl = 'http://10.0.2.2:5000/api/screening';

  // services/screening_service.dart - تحديث startScreening
  static Future<Map<String, dynamic>> startScreening({
    required int childAgeMonths,
    String? childGender,
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
        }),
      ).timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Response data: $data');

        // تحقق من هيكل الـ response
        if (data['success'] == true) {
          if (data['questions'] is List) {
            print('📋 Questions count: ${(data['questions'] as List).length}');
            return data;
          } else {
            print('❌ Questions field is not a list: ${data['questions']}');
            throw Exception('No questions available for this age group');
          }
        } else {
          print('❌ API returned success: false');
          throw Exception(data['message'] ?? 'Failed to start screening');
        }
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
      final response = await http.post(
        Uri.parse('$baseUrl/answer'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': sessionId,
          'question_id': questionId,
          'answer': answer,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to submit answer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getResults(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/results/$sessionId'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get results: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}