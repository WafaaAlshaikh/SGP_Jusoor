import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum ReportsScope { user, manager, admin }

class ReportsService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    return 'http://10.0.2.2:5000/api';
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_id');
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static String _scopePath(ReportsScope scope) {
    switch (scope) {
      case ReportsScope.user:
        return 'reports';
      case ReportsScope.manager:
        return 'manager/reports';
      case ReportsScope.admin:
        return 'admin/reports';
    }
  }

  static Future<List<dynamic>> listReports({
    required ReportsScope scope,
    String? status,
    String? priority,
    int page = 1,
    int limit = 50,
  }) async {
    final headers = await _headers();

    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (priority != null && priority.isNotEmpty) params['priority'] = priority;

    final uri = Uri.parse('$_baseUrl/${_scopePath(scope)}').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);

    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body is Map<String, dynamic>) {
      if (body['success'] == true && body['data'] is List) {
        return body['data'] as List;
      }
      throw Exception(body['message'] ?? 'Failed to load reports');
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> getReportDetails({
    required ReportsScope scope,
    required int reportId,
  }) async {
    final headers = await _headers();
    final uri = Uri.parse('$_baseUrl/${_scopePath(scope)}/$reportId');
    final response = await http.get(uri, headers: headers);

    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body is Map<String, dynamic>) {
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      throw Exception(body['message'] ?? 'Failed to load report details');
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> addMessage({
    required ReportsScope scope,
    required int reportId,
    required String message,
  }) async {
    final headers = await _headers();
    final uri = Uri.parse('$_baseUrl/${_scopePath(scope)}/$reportId/messages');

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'message': message}),
    );

    final body = jsonDecode(response.body);
    if ((response.statusCode == 201 || response.statusCode == 200) && body is Map<String, dynamic>) {
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      throw Exception(body['message'] ?? 'Failed to send message');
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> createReport({
    required String title,
    required String description,
    int? institutionId,
    String? category,
    String? targetType,
    String? targetId,
    String priority = 'medium',
  }) async {
    final headers = await _headers();

    final uri = Uri.parse('$_baseUrl/reports');
    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'priority': priority,
      if (institutionId != null) 'institution_id': institutionId,
      if (category != null) 'category': category,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    final body = jsonDecode(response.body);
    if ((response.statusCode == 201 || response.statusCode == 200) && body is Map<String, dynamic>) {
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      throw Exception(body['message'] ?? 'Failed to create report');
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> adminUpdateReport({
    required int reportId,
    String? status,
    String? priority,
    int? assignedAdminId,
  }) async {
    final headers = await _headers();
    final uri = Uri.parse('$_baseUrl/admin/reports/$reportId');

    final payload = <String, dynamic>{
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (assignedAdminId != null) 'assigned_admin_id': assignedAdminId,
    };

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body is Map<String, dynamic>) {
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      throw Exception(body['message'] ?? 'Failed to update report');
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<bool> isMyMessage(Map<String, dynamic> msg) async {
    final myId = await _getUserId();
    final senderIdRaw = msg['sender_id'];
    final senderId = senderIdRaw is num ? senderIdRaw.toInt() : int.tryParse(senderIdRaw?.toString() ?? '');
    if (myId == null || senderId == null) return false;
    return myId == senderId;
  }
}
