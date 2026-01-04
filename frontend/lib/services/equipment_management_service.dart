import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EquipmentManagementService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/auth/api/equipment-management';
    } else {
      return 'http://10.0.2.2:5000/api/auth/api/equipment-management';
    }
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Missing auth token');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
  }

  static String _safeBodySnippet(String body) {
    if (body.length <= 800) return body;
    return '${body.substring(0, 800)}...';
  }

  static Future<List<dynamic>> suggestNeeds({required String notes}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/needs/suggest'),
      headers: await _headers(),
      body: json.encode({'notes': notes}),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final suggestions = data['data']?['suggestions'];
      if (suggestions is List) return suggestions;
      return [];
    }

    throw Exception(data['message'] ?? 'Failed to get AI equipment needs suggestions');
  }

  static Future<Map<String, dynamic>> confirmNeeds({
    required int childId,
    int? evaluationId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/needs/confirm'),
      headers: await _headers(),
      body: json.encode({
        'child_id': childId,
        'created_from_evaluation_id': evaluationId,
        'items': items,
      }),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      return data;
    }

    throw Exception(data['message'] ?? 'Failed to confirm AI equipment needs');
  }

  static Future<List<dynamic>> getNeedsForChild({required int childId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/specialist/needs?child_id=$childId'),
      headers: await _headers(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final needs = data['data'];
      if (needs is List) return needs;
      return [];
    }

    throw Exception(data['message'] ?? 'Failed to load equipment needs');
  }

  static Future<List<dynamic>> getParentAllocations({int? childId, String? status}) async {
    final query = <String, String>{};
    if (childId != null) query['child_id'] = childId.toString();
    if (status != null && status.isNotEmpty) query['status'] = status;

    final uri = Uri.parse('$baseUrl/parent/allocations').replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: await _headers());

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final allocations = data['data'];
      if (allocations is List) return allocations;
      return [];
    }

    throw Exception(data['message'] ?? 'Failed to load allocations');
  }

  static Future<Map<String, dynamic>> parentConfirmReceipt({required int allocationId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/parent/allocations/$allocationId/confirm-receipt'),
      headers: await _headers(),
      body: json.encode({}),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }

    throw Exception(data['message'] ?? 'Failed to confirm receipt');
  }

  static Future<Map<String, dynamic>> getManagerEquipmentCampaigns({
    String? status,
    int? categoryId,
    int? childId,
    int? needId,
    String? search,
    double? minFulfillment,
    double? maxFulfillment,
    int? minPriority,
    int? maxPriority,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (categoryId != null) query['category_id'] = categoryId.toString();
    if (childId != null) query['child_id'] = childId.toString();
    if (needId != null) query['need_id'] = needId.toString();
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    if (minFulfillment != null) query['minFulfillment'] = minFulfillment.toString();
    if (maxFulfillment != null) query['maxFulfillment'] = maxFulfillment.toString();
    if (minPriority != null) query['minPriority'] = minPriority.toString();
    if (maxPriority != null) query['maxPriority'] = maxPriority.toString();
    if (startDate != null) query['startDate'] = startDate.toIso8601String();
    if (endDate != null) query['endDate'] = endDate.toIso8601String();

    final uri = Uri.parse('$baseUrl/manager/campaigns').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers());

    Map<String, dynamic>? data;
    try {
      data = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    if (response.statusCode == 200 && data?['success'] == true) {
      return Map<String, dynamic>.from(data?['data'] ?? {});
    }

    final message = (data?['message'] ?? 'Failed to load equipment campaigns').toString();
    throw Exception(
      '$message (status: ${response.statusCode}) url: $uri body: ${_safeBodySnippet(response.body)}',
    );
  }

  static Future<Map<String, dynamic>> getManagerEquipmentCampaignStats({
    String? status,
    int? categoryId,
    int? childId,
    int? needId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (categoryId != null) query['category_id'] = categoryId.toString();
    if (childId != null) query['child_id'] = childId.toString();
    if (needId != null) query['need_id'] = needId.toString();
    if (startDate != null) query['startDate'] = startDate.toIso8601String();
    if (endDate != null) query['endDate'] = endDate.toIso8601String();

    final uri = Uri.parse('$baseUrl/manager/campaigns/stats')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: await _headers());

    Map<String, dynamic>? data;
    try {
      data = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    if (response.statusCode == 200 && data?['success'] == true) {
      return Map<String, dynamic>.from(data?['data'] ?? {});
    }

    final message = (data?['message'] ?? 'Failed to load equipment campaign stats').toString();
    throw Exception(
      '$message (status: ${response.statusCode}) url: $uri body: ${_safeBodySnippet(response.body)}',
    );
  }

  static Future<Map<String, dynamic>> updateManagerEquipmentCampaign({
    required int campaignId,
    String? status,
    int? quantityFulfilled,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (quantityFulfilled != null) body['quantity_fulfilled'] = quantityFulfilled;

    final response = await http.put(
      Uri.parse('$baseUrl/manager/campaigns/$campaignId'),
      headers: await _headers(),
      body: json.encode(body),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] ?? {});
    }

    throw Exception(data['message'] ?? 'Failed to update equipment campaign');
  }
}
