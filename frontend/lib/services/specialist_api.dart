import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SpecialistService {
  // 🔥 إبقاء الـ URLs كما هي
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/specialist';
    } else {
      return 'http://10.0.2.2:5000/api/specialist';
    }
  }

  // 🔹 1. جلب بيانات الملف الشخصي - إصلاح نهائي للصورة
  static Future<Map<String, dynamic>> getProfileInfo() async {
    try {
      final token = await _getToken();

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 🔥 معالجة خاصة للصورة على الويب
        if (kIsWeb && data['avatar'] != null) {
          String avatarUrl = data['avatar'].toString();

          // إذا كان الرابط يبدأ بـ /uploads نضيف الـ base URL
          if (avatarUrl.startsWith('/uploads/')) {
            data['avatar'] = 'http://localhost:5000$avatarUrl';
          }

          // إذا كان الرابط من نوع relative نجعله absolute
          else if (avatarUrl.startsWith('uploads/')) {
            data['avatar'] = 'http://localhost:5000/$avatarUrl';
          }

          print('🖼️ Processed Avatar URL for web: ${data['avatar']}');
        }

        return data;
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getProfileInfo: $e');
      return {
        'name': 'Specialist',
        'avatar': null,
      };
    }
  }

  // باقي الدوال تبقى كما هي...
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  static Future<int> getUpcomingSessionsCount() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/upcoming-sessions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    return data['upcoming_sessions'] ?? 0;
  }

  static Future<int> getChildrenCount() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/children-count'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    return data['children_count'] ?? 0;
  }
}