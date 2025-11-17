import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ParentService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/parent';
    } else {
      return 'http://10.0.2.2:5000/api/parent';
    }
  }

  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  // ✅ جلب الجلسات الجديدة المعلقة للموافقة
  static Future<Map<String, dynamic>> getNewPendingSessions() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      // استخدام route الصحيح - موجود في specialistSessionRoutes لكن للـ parent
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/specialist/pending-new-sessions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load pending sessions: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getNewPendingSessions: $e');
      rethrow;
    }
  }

  // ✅ موافقة أو رفض الجلسة
  static Future<Map<String, dynamic>> approveNewSession(
    int sessionId,
    bool approve,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      // استخدام route الصحيح - موجود في specialistSessionRoutes لكن للـ parent
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/specialist/sessions/$sessionId/approve-new'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'approve': approve}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to process approval');
      }
    } catch (e) {
      print('❌ Error in approveNewSession: $e');
      rethrow;
    }
  }
}

