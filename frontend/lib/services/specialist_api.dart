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

  static Future<Map<String, dynamic>> getAvailableSessionTypes() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/available-session-types'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);
      return data;
    } catch (e) {
      throw Exception('Failed to load session types: $e');
    }
  }

  // ✅ جلب الأوقات المتاحة
  static Future<Map<String, dynamic>> getAvailableSlots(String date) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/available-slots?date=$date'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);
      return data;
    } catch (e) {
      throw Exception('Failed to load available slots: $e');
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

  // ✅ جلب الأطفال المؤهلين (نفس المؤسسة + نفس الحالة)
  static Future<Map<String, dynamic>> getEligibleChildren() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/eligible-children'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load eligible children: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getEligibleChildren: $e');
      rethrow;
    }
  }

 
  // ✅ إضافة جلسات لعدة أطفال
  static Future<Map<String, dynamic>> addSessionsForChildren({
  required List<int> childIds,
  required int sessionTypeId,
  required String date,
  required String time,
  String sessionType = 'Onsite',
  String? notes,
}) async {
  try {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');

    // 🔥 تحقق إضافي في الفرونت اند (اختياري)
    final now = DateTime.now();
    final sessionDateTime = DateTime.parse('${date}T$time');
    
    if (sessionDateTime.isBefore(now)) {
      throw Exception('Cannot schedule session in the past');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/add-sessions'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'child_ids': childIds,
        'session_type_id': sessionTypeId,
        'date': date,
        'time': time,
        'session_type': sessionType,
        'notes': notes,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to add sessions');
    }
  } catch (e) {
    print('❌ Error in addSessionsForChildren: $e');
    rethrow;
  }
}

  // ✅ إضافة نوع جلسة جديد
  static Future<Map<String, dynamic>> addSessionType({
  required String name,
  required int duration,
  required double price,
  required String category,
  List<String>? targetConditions,
}) async {
  try {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    print('🔄 Sending session type request...');
    print('   - Name: $name');
    print('   - Duration: $duration min');
    print('   - Price: $price JOD');
    print('   - Category: $category');
    print('   - Target Conditions: $targetConditions');

    final response = await http.post(
      Uri.parse('$baseUrl/add-session-type'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'duration': duration,
        'price': price,
        'category': category,
        'target_conditions': targetConditions,
      }),
    );

    print('📡 Response status: ${response.statusCode}');
    print('📡 Response body: ${response.body}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      print('✅ Session type request submitted successfully');
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['message'] ?? 'Failed to add session type';
      print('❌ Server error: $errorMessage');
      throw Exception(errorMessage);
    }
  } catch (e) {
    print('❌ Network error in addSessionType: $e');
    
    // 🔥 معالجة أفضل للرسائل العربية
    if (e.toString().contains('خطأ في إضافة نوع الجلسة')) {
      throw Exception('Error adding session type - please try again');
    } else if (e.toString().contains('No authentication token')) {
      throw Exception('Please login again');
    } else {
      throw Exception('Network error: Please check your connection');
    }
  }
}
}