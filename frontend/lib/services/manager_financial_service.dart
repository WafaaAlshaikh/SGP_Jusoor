import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerFinancialService {
  static String get _baseUrl {
  if (kIsWeb) {
    return 'http://localhost:5000/api';
  } else {
    return 'http://10.0.2.2:5000/api';
  }
}

  static Future<Map<String, dynamic>> getFinancialRequests({
    String status = 'submitted',
    String priority = 'all',
    int page = 1,
    int limit = 20,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('No authentication token found');
    }

    // backend mounts manager financial routes under /api/manager/financial
    // and managerFinancialRoutes.js defines /financial-requests
    final uri = Uri.parse('$_baseUrl/manager/financial/financial-requests').replace(
      queryParameters: {
        'status': status,
        'priority': priority,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to load financial requests');
    }
  }

  static Future<Map<String, dynamic>> reviewFinancialRequest({
    required int requestId,
    required String action, // 'approve' | 'partial_approve' | 'reject' | 'request_documents'
    int? approvedDiscountPercentage,
    int? approvedSessionsCount,
    String? decisionNotes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('No authentication token found');
    }

    final body = <String, dynamic>{
      'action': action,
      if (approvedDiscountPercentage != null)
        'approved_discount_percentage': approvedDiscountPercentage,
      if (approvedSessionsCount != null)
        'approved_sessions_count': approvedSessionsCount,
      if (decisionNotes != null && decisionNotes.isNotEmpty)
        'decision_notes': decisionNotes,
    };

    final response = await http.post(
      // POST /api/manager/financial/financial-requests/:request_id/review
      Uri.parse('$_baseUrl/manager/financial/financial-requests/$requestId/review'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to review financial request');
    }
  }

  static Future<Map<String, dynamic>> getSessionAidRequests({
    String status = 'under_review',
    int page = 1,
    int limit = 20,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('No authentication token found');
    }

    final uri =
        Uri.parse('$_baseUrl/manager/financial/session-aid-requests').replace(
      queryParameters: {
        'status': status,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to load session aid requests');
    }
  }

  static Future<Map<String, dynamic>> reviewSessionAidRequest({
    required int requestId,
    required String action, // 'approve' | 'partial_approve' | 'reject'
    double? approvedPercentage,
    double? approvedAmount,
    String? decisionNotes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('No authentication token found');
    }

    final body = <String, dynamic>{
      'action': action,
      if (approvedPercentage != null) 'approved_percentage': approvedPercentage,
      if (approvedAmount != null) 'approved_amount': approvedAmount,
      if (decisionNotes != null && decisionNotes.isNotEmpty)
        'decision_notes': decisionNotes,
    };

    final response = await http.post(
      Uri.parse(
          '$_baseUrl/manager/financial/session-aid-requests/$requestId/review'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to review session aid request');
    }
  }
}
