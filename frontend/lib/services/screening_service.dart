// services/screening_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/screening_models.dart';

class ScreeningService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api'; // للويب
    } else {
      return 'http://10.0.2.2:5000/api'; // للموبايل
    }
  }

  // ✅ دالة مساعدة لجلب التوكن
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ✅ بدء الاستبيان
  static Future<Map<String, dynamic>> startScreening(int childAge, String? childGender) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      print('🚀 Calling start-screening API...');
      print('📦 Request: child_age=$childAge, child_gender=$childGender');

      final response = await http.post(
        Uri.parse('$baseUrl/screening/start-screening'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode({
          'child_age': childAge,
          'child_gender': childGender,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to start screening: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ API Error: $e');
      throw Exception('Network error: $e');
    }
  }

 static Future<Map<String, dynamic>> processGateway({
  required int childAge,
  required String? childGender,
  required List<ScreeningResponse> responses,
}) async {
  try {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');

    print('🚀 Sending gateway responses...');
    
    // 🔥 تأكد من الـ request body
    final requestBody = {
      'child_age': childAge,
      'child_gender': childGender,
      'responses': responses.map((r) => {
        'question_id': r.questionId,
        'answer': r.answer,
        'category': r.category,
        'risk_score': r.riskScore,
      }).toList(),
    };

    print('📦 Request body: ${json.encode(requestBody)}');

    final response = await http.post(
      Uri.parse('$baseUrl/screening/process-gateway'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: json.encode(requestBody),
    ).timeout(const Duration(seconds: 30)); // 🔥 أضف timeout

    print('📡 Server response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      print('❌ Server error: ${response.body}');
      throw Exception('Server returned ${response.statusCode}');
    }

    final data = json.decode(response.body);
    print('✅ Gateway processing successful');
    print('📋 Received ${data['questions']?.length ?? 0} questions');
    
    return data;
    
  } catch (e) {
    print('❌ Process gateway error: $e');
    print('🔍 Error type: ${e.runtimeType}');
    rethrow; // 🔥 رجع الـ error عشان يتhandle في الـ screen
  }
}
  // ✅ حفظ النتائج النهائية
  static Future<Map<String, dynamic>> saveResults({
    required int childAge,
    required String? childGender,
    required Map<String, dynamic> screeningPlan,
    required List<ScreeningResponse> primaryResponses,
    required List<ScreeningResponse>? secondaryResponses,
    required Map<String, int> finalScores,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$baseUrl/screening/save-results'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode({
          'child_age': childAge,
          'child_gender': childGender,
          'screening_plan': screeningPlan,
          'primary_responses': primaryResponses.map((r) => {
            'question_id': r.questionId,
            'answer': r.answer,
            'risk_score': r.riskScore,
            'category': r.category,
          }).toList(),
          'secondary_responses': secondaryResponses?.map((r) => {
            'question_id': r.questionId,
            'answer': r.answer,
            'risk_score': r.riskScore,
            'category': r.category,
          }).toList(),
          'final_scores': finalScores,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to save results: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ✅ جلب تاريخ الفحوصات السابقة
  static Future<List<dynamic>> getMyScreenings() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/screening/my-screenings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true && data['screenings'] is List) {
          return data['screenings'];
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception(data['error'] ?? 'Failed to load screenings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ✅ اختبار الاتصال بالـ API
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/screening/test-auth'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Connection test failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection test error: $e');
    }
  }
}