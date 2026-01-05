import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerVacationService {
  static String get _baseUrl {
  if (kIsWeb) {
    return 'http://localhost:5000/api';
  } else {
    return 'http://10.0.2.2:5000/api';
  }
}

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ==================== جلب جميع طلبات الإجازة ====================
  static Future<Map<String, dynamic>> getAllVacationRequests() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/vacation-requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load vacation requests: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Vacation Requests Error: $e');
      rethrow;
    }
  }

  // ==================== جلب تفاصيل طلب إجازة ====================
  static Future<Map<String, dynamic>> getVacationRequestDetails(int requestId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/vacation-requests/$requestId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load vacation request details: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Vacation Details Error: $e');
      rethrow;
    }
  }

  // ==================== تحديث حالة طلب الإجازة ====================
  static Future<Map<String, dynamic>> updateVacationRequestStatus({
    required int requestId,
    required String status,
    String? managerNotes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final Map<String, dynamic> requestBody = {
        'status': status,
      };

      if (managerNotes != null && managerNotes.isNotEmpty) {
        requestBody['manager_notes'] = managerNotes;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/vacation-requests/$requestId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception('Failed to update vacation request: ${responseBody['message']}');
      }
    } catch (e) {
      print('Update Vacation Status Error: $e');
      rethrow;
    }
  }
}