import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ManagerService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/manager';
    } else {
      return 'http://10.0.2.2:5000/api/manager';
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

  // ✅ جلب أنواع الجلسات المعلقة للموافقة
  static Future<Map<String, dynamic>> getPendingSessionTypes() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/pending-session-types'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load pending session types: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getPendingSessionTypes: $e');
      rethrow;
    }
  }

  // ✅ الموافقة على نوع جلسة
  static Future<Map<String, dynamic>> approveSessionType(int sessionTypeId, {String? notes}) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$baseUrl/approve-session-type/$sessionTypeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'notes': notes}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to approve session type');
      }
    } catch (e) {
      print('❌ Error in approveSessionType: $e');
      rethrow;
    }
  }

  // ✅ رفض نوع جلسة
  static Future<Map<String, dynamic>> rejectSessionType(int sessionTypeId, {String? reason}) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$baseUrl/reject-session-type/$sessionTypeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to reject session type');
      }
    } catch (e) {
      print('❌ Error in rejectSessionType: $e');
      rethrow;
    }
  }
}

