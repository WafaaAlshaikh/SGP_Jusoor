import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerCmsService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api/manager/cms';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('No authentication token found');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ================= Page Content =================
  static Future<List<dynamic>> getPageContent() async {
    final headers = await _headers();
    final res = await http.get(Uri.parse('$_baseUrl/page-content'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as List?) ?? [];
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to load page content');
  }

  static Future<Map<String, dynamic>> upsertPageContent({
    required String key,
    String? title,
    required String content,
    int? sortOrder,
    bool? isActive,
  }) async {
    final headers = await _headers();
    final res = await http.put(
      Uri.parse('$_baseUrl/page-content/$key'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'content': content,
        'sort_order': sortOrder,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(res.body);
    if ((res.statusCode == 200 || res.statusCode == 201) && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to save content');
  }

  // ================= News =================
  static Future<Map<String, dynamic>> getNews({int page = 1, int limit = 20}) async {
    final headers = await _headers();
    final uri = Uri.parse('$_baseUrl/news').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    final res = await http.get(uri, headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to load news');
  }

  static Future<Map<String, dynamic>> createNews({
    required String title,
    String? summary,
    String? content,
    String? coverImageUrl,
    DateTime? publishedAt,
    bool isPublished = true,
  }) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$_baseUrl/news'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'summary': summary,
        'content': content,
        'cover_image_url': coverImageUrl,
        'published_at': (publishedAt ?? DateTime.now()).toIso8601String(),
        'is_published': isPublished,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 201 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to create news');
  }

  static Future<Map<String, dynamic>> updateNews({
    required int newsId,
    String? title,
    String? summary,
    String? content,
    String? coverImageUrl,
    DateTime? publishedAt,
    bool? isPublished,
  }) async {
    final headers = await _headers();
    final res = await http.put(
      Uri.parse('$_baseUrl/news/$newsId'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'summary': summary,
        'content': content,
        'cover_image_url': coverImageUrl,
        'published_at': publishedAt?.toIso8601String(),
        'is_published': isPublished,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to update news');
  }

  static Future<void> deleteNews(int newsId) async {
    final headers = await _headers();
    final res = await http.delete(Uri.parse('$_baseUrl/news/$newsId'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return;
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to delete news');
  }

  // ================= Programs =================
  static Future<List<dynamic>> getPrograms() async {
    final headers = await _headers();
    final res = await http.get(Uri.parse('$_baseUrl/programs'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as List?) ?? [];
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to load programs');
  }

  static Future<Map<String, dynamic>> createProgram({
    required String title,
    String? description,
    String? icon,
    String? imageUrl,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$_baseUrl/programs'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'icon': icon,
        'image_url': imageUrl,
        'sort_order': sortOrder,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 201 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to create program');
  }

  static Future<Map<String, dynamic>> updateProgram({
    required int programId,
    String? title,
    String? description,
    String? icon,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
  }) async {
    final headers = await _headers();
    final res = await http.put(
      Uri.parse('$_baseUrl/programs/$programId'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'icon': icon,
        'image_url': imageUrl,
        'sort_order': sortOrder,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to update program');
  }

  static Future<void> deleteProgram(int programId) async {
    final headers = await _headers();
    final res = await http.delete(Uri.parse('$_baseUrl/programs/$programId'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return;
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to delete program');
  }

  // ================= Projects =================
  static Future<List<dynamic>> getProjects() async {
    final headers = await _headers();
    final res = await http.get(Uri.parse('$_baseUrl/projects'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as List?) ?? [];
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to load projects');
  }

  static Future<Map<String, dynamic>> createProject({
    required String title,
    String? description,
    String? status,
    String? coverImageUrl,
    num? goalAmount,
    num? raisedAmount,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$_baseUrl/projects'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'status': status,
        'cover_image_url': coverImageUrl,
        'goal_amount': goalAmount,
        'raised_amount': raisedAmount,
        'sort_order': sortOrder,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 201 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to create project');
  }

  static Future<Map<String, dynamic>> updateProject({
    required int projectId,
    String? title,
    String? description,
    String? status,
    String? coverImageUrl,
    num? goalAmount,
    num? raisedAmount,
    int? sortOrder,
    bool? isActive,
  }) async {
    final headers = await _headers();
    final res = await http.put(
      Uri.parse('$_baseUrl/projects/$projectId'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'status': status,
        'cover_image_url': coverImageUrl,
        'goal_amount': goalAmount,
        'raised_amount': raisedAmount,
        'sort_order': sortOrder,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to update project');
  }

  static Future<void> deleteProject(int projectId) async {
    final headers = await _headers();
    final res = await http.delete(Uri.parse('$_baseUrl/projects/$projectId'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return;
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to delete project');
  }

  // ================= FAQ =================
  static Future<List<dynamic>> getFaq() async {
    final headers = await _headers();
    final res = await http.get(Uri.parse('$_baseUrl/faq'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as List?) ?? [];
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to load FAQ');
  }

  static Future<Map<String, dynamic>> createFaq({
    required String question,
    required String answer,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$_baseUrl/faq'),
      headers: headers,
      body: jsonEncode({
        'question': question,
        'answer': answer,
        'sort_order': sortOrder,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 201 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to create FAQ');
  }

  static Future<Map<String, dynamic>> updateFaq({
    required int faqId,
    String? question,
    String? answer,
    int? sortOrder,
    bool? isActive,
  }) async {
    final headers = await _headers();
    final res = await http.put(
      Uri.parse('$_baseUrl/faq/$faqId'),
      headers: headers,
      body: jsonEncode({
        'question': question,
        'answer': answer,
        'sort_order': sortOrder,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to update FAQ');
  }

  static Future<void> deleteFaq(int faqId) async {
    final headers = await _headers();
    final res = await http.delete(Uri.parse('$_baseUrl/faq/$faqId'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return;
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to delete FAQ');
  }

  // ================= Media =================
  static Future<List<dynamic>> getMedia() async {
    final headers = await _headers();
    final res = await http.get(Uri.parse('$_baseUrl/media'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as List?) ?? [];
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to load media');
  }

  static Future<Map<String, dynamic>> createMedia({
    required String mediaType,
    required String url,
    String? title,
    String? description,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$_baseUrl/media'),
      headers: headers,
      body: jsonEncode({
        'media_type': mediaType,
        'url': url,
        'title': title,
        'description': description,
        'sort_order': sortOrder,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 201 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to create media');
  }

  static Future<Map<String, dynamic>> updateMedia({
    required int mediaId,
    String? mediaType,
    String? url,
    String? title,
    String? description,
    int? sortOrder,
    bool? isActive,
  }) async {
    final headers = await _headers();
    final res = await http.put(
      Uri.parse('$_baseUrl/media/$mediaId'),
      headers: headers,
      body: jsonEncode({
        'media_type': mediaType,
        'url': url,
        'title': title,
        'description': description,
        'sort_order': sortOrder,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to update media');
  }

  static Future<void> deleteMedia(int mediaId) async {
    final headers = await _headers();
    final res = await http.delete(Uri.parse('$_baseUrl/media/$mediaId'), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data is Map && data['success'] == true) {
      return;
    }

    throw Exception((data is Map ? data['message'] : null) ?? 'Failed to delete media');
  }
}
