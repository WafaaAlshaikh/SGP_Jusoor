import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerSessionTypeService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ==================== Get Pending Session Types ====================
  static Future<Map<String, dynamic>> getPendingSessionTypes() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/session-types/pending'),
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
      print('Get Pending Session Types Error: $e');
      rethrow;
    }
  }

  // ==================== Update Session Type Approval ====================
  static Future<Map<String, dynamic>> updateSessionTypeApproval({
    required int sessionTypeId,
    required String approvalStatus,
    double? price,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final Map<String, dynamic> requestBody = {
        'approval_status': approvalStatus,
      };

      if (price != null) {
        requestBody['price'] = price;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/session-types/$sessionTypeId/approval'),
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
        throw Exception('Failed to update session type: ${responseBody['message']}');
      }
    } catch (e) {
      print('Update Session Type Approval Error: $e');
      rethrow;
    }
  }

  // ==================== Add New Session Type ====================
  static Future<Map<String, dynamic>> addSessionType({
    required String name,
    required int duration,
    required double price,
    required String category,
    required String specialistSpecialization,
    String? targetConditions,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final Map<String, dynamic> requestBody = {
        'name': name,
        'duration': duration,
        'price': price,
        'category': category,
        'specialist_specialization': specialistSpecialization,
      };

      if (targetConditions != null && targetConditions.isNotEmpty) {
        requestBody['target_conditions'] = targetConditions;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/manager/session-types'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return responseBody;
      } else {
        throw Exception('Failed to add session type: ${responseBody['message']}');
      }
    } catch (e) {
      print('Add Session Type Error: $e');
      rethrow;
    }
  }
  // ==================== Edit Session Type ====================
  static Future<Map<String, dynamic>> editSessionType({
    required int sessionTypeId,
    required String name,
    required int duration,
    required double price,
    required String category,
    required String specialistSpecialization,
    String? targetConditions,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final Map<String, dynamic> requestBody = {
        'name': name,
        'duration': duration,
        'price': price,
        'category': category,
        'specialist_specialization': specialistSpecialization,
      };

      if (targetConditions != null) {
        requestBody['target_conditions'] = targetConditions;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/session-types/$sessionTypeId'),
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
        throw Exception('Failed to edit session type: ${responseBody['message']}');
      }
    } catch (e) {
      print('Edit Session Type Error: $e');
      rethrow;
    }
  }

// ==================== Delete Session Type ====================
  static Future<Map<String, dynamic>> deleteSessionType({
    required int sessionTypeId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/manager/session-types/$sessionTypeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception('Failed to delete session type: ${responseBody['message']}');
      }
    } catch (e) {
      print('Delete Session Type Error: $e');
      rethrow;
    }
  }
  // ==================== Get All Session Types ====================
  static Future<Map<String, dynamic>> getAllSessionTypes() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/session-types'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load session types: ${response.statusCode}');
      }
    } catch (e) {
      print('Get All Session Types Error: $e');
      rethrow;
    }
  }
}