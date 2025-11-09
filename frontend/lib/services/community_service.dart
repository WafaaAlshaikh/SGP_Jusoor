import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CommunityService {
  // 🔥 تحديد الـ baseUrl بناءً على المنصة
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/community'; // للويب
    } else {
      return 'http://10.0.2.2:5000/api/community'; // للموبايل
    }
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> createPost({
    String? content,
    File? mediaFile,
    String? mediaType,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/posts');
      final headers = await _getMultipartHeaders();

      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);

      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }

      if (mediaType != null) {
        request.fields['media_type'] = mediaType;
      }

      if (mediaFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('media', mediaFile.path),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      print('📡 Create Post Response: ${response.statusCode} - URL: $baseUrl/posts');

      if (response.statusCode == 201) {
        return json.decode(responseData);
      } else {
        throw Exception('Failed to create post: ${json.decode(responseData)['message']}');
      }
    } catch (e) {
      throw Exception('Error creating post: $e');
    }
  }

  static Future<Map<String, dynamic>> getAllPosts({int page = 1, int limit = 10}) async {
    try {
      final url = Uri.parse('$baseUrl/posts?page=$page&limit=$limit');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      print('📡 Get All Posts Response: ${response.statusCode} - URL: $baseUrl/posts');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load posts: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('Error loading posts: $e');
    }
  }

  static Future<Map<String, dynamic>> getMyPosts({int page = 1, int limit = 10}) async {
    try {
      final url = Uri.parse('$baseUrl/posts/my-posts?page=$page&limit=$limit');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      print('📡 Get My Posts Response: ${response.statusCode} - URL: $baseUrl/posts/my-posts');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load my posts: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('Error loading my posts: $e');
    }
  }

  static Future<Map<String, dynamic>> addComment(String postId, String content) async {
    try {
      final url = Uri.parse('$baseUrl/posts/$postId/comments');
      final headers = await _getHeaders();

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'content': content}),
      );

      print('📡 Add Comment Response: ${response.statusCode} - URL: $baseUrl/posts/$postId/comments');

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add comment: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('Error adding comment: $e');
    }
  }

  static Future<Map<String, dynamic>> toggleLike(String postId) async {
    try {
      final url = Uri.parse('$baseUrl/posts/$postId/like');
      final headers = await _getHeaders();

      final response = await http.post(url, headers: headers);

      print('📡 Toggle Like Response: ${response.statusCode} - URL: $baseUrl/posts/$postId/like');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to toggle like: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('Error toggling like: $e');
    }
  }

  // ✅ UPDATED: Repost with optional comment
  static Future<Map<String, dynamic>> repost(String postId, {String? comment}) async {
    try {
      final url = Uri.parse('$baseUrl/posts/$postId/repost');
      final headers = await _getHeaders();

      final body = comment != null ? {'comment': comment} : {};

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      print('📡 Repost Response: ${response.statusCode} - URL: $baseUrl/posts/$postId/repost');

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to repost: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('Error reposting: $e');
    }
  }

  static Future<Map<String, dynamic>> translatePost(String postId, String targetLang) async {
    try {
      final url = Uri.parse('$baseUrl/posts/$postId/translate');
      final headers = await _getHeaders();

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'targetLang': targetLang}),
      );

      print('📡 Translate Post Response: ${response.statusCode} - URL: $baseUrl/posts/$postId/translate');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to translate post: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('Error translating post: $e');
    }
  }

  static Future<Map<String, dynamic>> updatePost(String postId, String content) async {
    try {
      final url = Uri.parse('$baseUrl/posts/$postId');
      final headers = await _getHeaders();

      final response = await http.put(
        url,
        headers: headers,
        body: json.encode({'content': content}),
      );

      print('📡 Update Post Response: ${response.statusCode} - URL: $baseUrl/posts/$postId');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update post: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('Error updating post: $e');
    }
  }

  static Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
      final url = Uri.parse('$baseUrl/posts/$postId');
      final headers = await _getHeaders();

      final response = await http.delete(url, headers: headers);

      print('📡 Delete Post Response: ${response.statusCode} - URL: $baseUrl/posts/$postId');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to delete post: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('Error deleting post: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteComment(String commentId) async {
    try {
      final url = Uri.parse('$baseUrl/comments/$commentId');
      final headers = await _getHeaders();

      final response = await http.delete(url, headers: headers);

      print('📡 Delete Comment Response: ${response.statusCode} - URL: $baseUrl/comments/$commentId');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to delete comment: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('Error deleting comment: $e');
    }
  }
}