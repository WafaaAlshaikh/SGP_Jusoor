// lib/services/admin_api_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminApiService {
  static String get baseUrl {
    if (kIsWeb) {
      final scheme = (Uri.base.scheme.isEmpty) ? 'http' : Uri.base.scheme;
      final host = (Uri.base.host.isEmpty) ? 'localhost' : Uri.base.host;
      return '$scheme://$host:5000/api/admin';
    } else {
      return 'http://10.0.2.2:5000/api/admin'; // للموبايل
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, dynamic>> getDetailedStats() async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.get(
        Uri.parse('$baseUrl/detailed-stats'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load detailed stats');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Map<String, String> _getHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Dashboard
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.get(
        Uri.parse('$baseUrl/dashboard'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load dashboard stats');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAnalyticsOverview({int rangeDays = 30}) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.get(
        Uri.parse('$baseUrl/analytics/overview').replace(
          queryParameters: {
            'range_days': rangeDays.toString(),
          },
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load analytics overview');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getInstitutionsAnalyticsOverview({
    int rangeDays = 90,
    int limit = 10,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.get(
        Uri.parse('$baseUrl/institutions/analytics/overview').replace(
          queryParameters: {
            'range_days': rangeDays.toString(),
            'limit': limit.toString(),
          },
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load institutions analytics overview');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getInstitutionsAnalyticsHistory({
    int rangeDays = 90,
    String bucket = 'day',
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.get(
        Uri.parse('$baseUrl/institutions/analytics/history').replace(
          queryParameters: {
            'range_days': rangeDays.toString(),
            'bucket': bucket,
          },
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load institutions analytics history');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getInstitutionsAnalyticsTop({
    int rangeDays = 90,
    int limit = 10,
    String metric = 'score',
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.get(
        Uri.parse('$baseUrl/institutions/analytics/top').replace(
          queryParameters: {
            'range_days': rangeDays.toString(),
            'limit': limit.toString(),
            'metric': metric,
          },
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load institutions analytics top');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Institutions
  static Future<Map<String, dynamic>> getInstitutions({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null) queryParams['status'] = status;
      if (search != null) queryParams['search'] = search;

      final response = await http.get(
        Uri.parse('$baseUrl/institutions').replace(
          queryParameters: queryParams,
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load institutions');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createInstitution(Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.post(
        Uri.parse('$baseUrl/institutions'),
        headers: _getHeaders(token),
        body: json.encode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create institution');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateInstitution(int institutionId, Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.put(
        Uri.parse('$baseUrl/institutions/$institutionId'),
        headers: _getHeaders(token),
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update institution');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> suspendInstitution(int institutionId, {String? reason, int? durationDays}) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.post(
        Uri.parse('$baseUrl/institutions/$institutionId/suspend'),
        headers: _getHeaders(token),
        body: json.encode({
          'reason': reason,
          'duration_days': durationDays,
        }),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteInstitution(int institutionId) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.delete(
        Uri.parse('$baseUrl/institutions/$institutionId'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Users
  static Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int limit = 20,
    String? role,
    String? status,
    String? search,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (role != null) queryParams['role'] = role;
      if (status != null) queryParams['status'] = status;
      if (search != null) queryParams['search'] = search;

      final response = await http.get(
        Uri.parse('$baseUrl/users').replace(
          queryParameters: queryParams,
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Reports
  static Future<Map<String, dynamic>> getReports({
    int page = 1,
    int limit = 20,
    String? status,
    String? priority,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null) queryParams['status'] = status;
      if (priority != null) queryParams['priority'] = priority;

      final response = await http.get(
        Uri.parse('$baseUrl/reports').replace(
          queryParameters: queryParams,
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load reports');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Donations
  static Future<Map<String, dynamic>> getDonations({
    int page = 1,
    int limit = 20,
    DateTimeRange? dateRange,
    String? institutionId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (dateRange != null) {
        queryParams['start_date'] = dateRange.start.toIso8601String();
        queryParams['end_date'] = dateRange.end.toIso8601String();
      }
      if (institutionId != null) queryParams['institution_id'] = institutionId;

      final response = await http.get(
        Uri.parse('$baseUrl/donations').replace(
          queryParameters: queryParams,
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load donations');
      }
    } catch (e) {
      rethrow;
    }
  }

  // System Settings
  static Future<Map<String, dynamic>> getSettings({String? category}) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final Map<String, String> queryParams = {};
      if (category != null) queryParams['category'] = category;

      final response = await http.get(
        Uri.parse('$baseUrl/settings').replace(
          queryParameters: queryParams,
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load settings');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.get(
        Uri.parse('$baseUrl/system/health'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load system health');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Audit Logs
  static Future<Map<String, dynamic>> getAuditLogs({
    int page = 1,
    int limit = 50,
    DateTimeRange? dateRange,
    String? adminId,
    String? actionType,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (dateRange != null) {
        queryParams['start_date'] = dateRange.start.toIso8601String();
        queryParams['end_date'] = dateRange.end.toIso8601String();
      }
      if (adminId != null) queryParams['admin_id'] = adminId;
      if (actionType != null) queryParams['action_type'] = actionType;

      final response = await http.get(
        Uri.parse('$baseUrl/audit-logs').replace(
          queryParameters: queryParams,
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load audit logs');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Action Methods
  static Future<bool> approveInstitution(int institutionId, {String? notes}) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.post(
        Uri.parse('$baseUrl/institutions/$institutionId/approve'),
        headers: _getHeaders(token),
        body: json.encode({'notes': notes ?? ''}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> rejectInstitution(int institutionId, {required String reason}) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.post(
        Uri.parse('$baseUrl/institutions/$institutionId/reject'),
        headers: _getHeaders(token),
        body: json.encode({'reason': reason}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> approveUser(int userId) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/approve'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateReportStatus(int reportId, String status, {String? adminNotes}) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await http.put(
        Uri.parse('$baseUrl/reports/$reportId/status'),
        headers: _getHeaders(token),
        body: json.encode({
          'status': status,
          'admin_notes': adminNotes,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}