// lib/services/manager_dashboard_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerDashboardService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api'; // أو الـ URL الخاص بالسيرفر

  // دالة للحصول على التوكن
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // دالة للحصول على الـ Headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // جلب إحصائيات Dashboard
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/DashbordManager/dashboard/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch dashboard stats');
        }
      } else {
        throw Exception('Failed to load dashboard stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      rethrow;
    }
  }

  // دالة للـ Debugging
  static Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/DashbordManager/debug'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load debug info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching debug info: $e');
      rethrow;
    }
  }
}