import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class PublicInstitutionService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/public';
    }
    return 'http://10.0.2.2:5000/api/public';
  }

  static Future<List<dynamic>> getInstitutions() async {
    final response = await http.get(Uri.parse('$_baseUrl/institutions'));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as List?) ?? [];
    }

    final message = (data is Map ? data['message'] : null) ?? 'Failed to load institutions';
    throw Exception(message);
  }

  static Future<Map<String, dynamic>> getInstitutionProfile(int institutionId) async {
    final response = await http.get(Uri.parse('$_baseUrl/institutions/$institutionId/profile'));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    }

    final message = (data is Map ? data['message'] : null) ?? 'Failed to load institution profile';
    throw Exception(message);
  }

  static Future<Map<String, dynamic>> getInstitutionHome(int institutionId) async {
    final response = await http.get(Uri.parse('$_baseUrl/institutions/$institutionId/home'));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    }

    final message = (data is Map ? data['message'] : null) ?? 'Failed to load institution home';
    throw Exception(message);
  }

  static Future<List<dynamic>> getInstitutionTeam(int institutionId) async {
    final response = await http.get(Uri.parse('$_baseUrl/institutions/$institutionId/team'));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as List?) ?? [];
    }

    final message = (data is Map ? data['message'] : null) ?? 'Failed to load institution team';
    throw Exception(message);
  }

  static Future<bool> getFollowStatus({
    required int institutionId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/institutions/$institutionId/follow-status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data is Map && data['success'] == true) {
      final d = (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      return d['is_following'] == true;
    }

    final message = (data is Map ? data['message'] : null) ?? 'Failed to load follow status';
    throw Exception(message);
  }

  static Future<void> followInstitution({
    required int institutionId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/institutions/$institutionId/follow'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data is Map && data['success'] == true) return;
    }

    final message = (data is Map ? data['message'] : null) ?? 'Failed to follow institution';
    throw Exception(message);
  }

  static Future<void> unfollowInstitution({
    required int institutionId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/institutions/$institutionId/unfollow'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (data is Map && data['success'] == true) return;
    }

    final message = (data is Map ? data['message'] : null) ?? 'Failed to unfollow institution';
    throw Exception(message);
  }

  static Future<Map<String, dynamic>> askInstitutionAI({
    required int institutionId,
    required String question,
    String? token,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/institutions/$institutionId/ai/ask'),
      headers: headers,
      body: jsonEncode({'question': question}),
    );
    final data = jsonDecode(response.body);

    if ((response.statusCode == 200) && data is Map && data['success'] == true) {
      return (data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    }

    final message = (data is Map ? data['message'] : null) ?? 'Failed to get AI answer';
    throw Exception(message);
  }

  static Future<List<dynamic>> getInstitutionSessionTypes(int institutionId) async {
  final response = await http.get(
    Uri.parse('$_baseUrl/institutions/$institutionId/session-types'),
  );
  final data = jsonDecode(response.body);

  if (response.statusCode == 200 && data is Map && data['success'] == true) {
    return (data['data'] as List?) ?? [];
  }

  final message = (data is Map ? data['message'] : null) ?? 'Failed to load session types';
  throw Exception(message);
}

static Future<Map<String, dynamic>> getSessionTypeDetails(int institutionId, int sessionTypeId) async {
  final response = await http.get(
    Uri.parse('$_baseUrl/institutions/$institutionId/session-types/$sessionTypeId'),
  );
  final data = jsonDecode(response.body);

  if (response.statusCode == 200 && data is Map && data['success'] == true) {
    return (data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  final message = (data is Map ? data['message'] : null) ?? 'Failed to load session type details';
  throw Exception(message);
}
}
