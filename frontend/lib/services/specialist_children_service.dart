// lib/services/specialist_children_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SpecialistChildrenService {
  // 🔥 تحديد الـ baseUrl بناءً على المنصة
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/specialist'; // للويب
    } else {
      return 'http://10.0.2.2:5000/api/specialist'; // للموبايل
    }
  }

  // الحصول على التوكن من التخزين المحلي
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      throw Exception('Failed to get token: $e');
    }
  }

  // ============ Functions for Child Completion ============

  // جلب الأطفال المؤهلين للتأكيد (completion-candidates)
  static Future<Map<String, dynamic>> getCompletionCandidates() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found. Please login again.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/completion/completion-candidates'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Only specialists can access this.');
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Specialist is not associated with an institution.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch completion candidates. Status: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // تأكيد انتهاء علاج طفل (confirm-completion)
  static Future<Map<String, dynamic>> confirmChildCompletion({
    required int childId,
    String? notes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found. Please login again.');
      }

      final Map<String, dynamic> requestBody = {
        'child_id': childId,
      };

      if (notes != null && notes.isNotEmpty) {
        requestBody['notes'] = notes;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/completion/confirm-completion'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('You are not authorized to confirm completion for this child.');
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        if (errorData.containsKey('conditions')) {
          throw Exception('Conditions not met: ${_formatConditionsError(errorData['conditions'])}');
        } else {
          throw Exception(errorData['message'] ?? 'Invalid request.');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Child not found.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to confirm completion. Status: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // تنسيق رسالة الخطأ للشروط
  static String _formatConditionsError(Map<String, dynamic> conditions) {
    final List<String> missingConditions = [];

    if (conditions['has_no_active_sessions'] == false) {
      missingConditions.add('has active sessions');
    }
    if (conditions['has_final_evaluation'] == false) {
      missingConditions.add('has no final evaluation');
    }
    if (conditions['has_no_pending_requests'] == false) {
      missingConditions.add('has pending requests');
    }

    return missingConditions.join(', ');
  }

  // جلب حالة الإكمال لطفل محدد (completion-status)
  static Future<Map<String, dynamic>> getChildCompletionStatus(int childId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found. Please login again.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/completion/completion-status/$childId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have access to this child\'s completion status.');
      } else if (response.statusCode == 404) {
        throw Exception('Child not found or no completion data available.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch completion status. Status: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ============ Original Functions ============

  // جلب جميع الأطفال للاخصائي
  static Future<Map<String, dynamic>> getSpecialistChildren() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found. Please login again.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. You are not authorized.');
      } else if (response.statusCode == 404) {
        throw Exception('Specialist not found.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch children. Status: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // جلب تفاصيل طفل محدد
  static Future<Map<String, dynamic>> getChildDetails(int childId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found. Please login again.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children/$childId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have access to this child\'s information.');
      } else if (response.statusCode == 404) {
        throw Exception('Child not found.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch child details. Status: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}