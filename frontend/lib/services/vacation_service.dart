import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class VacationService {
  // 🔥 تحديد الـ baseUrl بناءً على المنصة
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/vacations'; // للويب
    } else {
      return 'http://10.0.2.2:5000/api/vacations'; // للموبايل
    }
  }

  // الحصول على التوكن من التخزين المحلي
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // إنشاء طلب إجازة جديد
  static Future<Map<String, dynamic>> createVacation({
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          'reason': reason,
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? 'Request submitted',
        'vacation': data['vacation'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // الحصول على طلبات الإجازة الخاصة بالمستخدم
  static Future<List<dynamic>> getMyVacations() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching vacations: $e');
      return [];
    }
  }

  // تحديث طلب إجازة
  static Future<Map<String, dynamic>> updateVacation({
    required int id,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          'reason': reason,
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Request updated',
        'vacation': data['vacation'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // حذف طلب إجازة
  static Future<Map<String, dynamic>> deleteVacation(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Request deleted',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // الحصول على الأيام غير المتاحة (فيها جلسات)
  static Future<List<DateTime>> getUnavailableDates() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/unavailable'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dates = List<String>.from(data['unavailableDates'] ?? []);
        return dates.map((date) => DateTime.parse(date)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching unavailable dates: $e');
      return [];
    }
  }
}