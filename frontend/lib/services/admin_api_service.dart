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


  static String get publicBaseUrl {
    if (kIsWeb) {
      final scheme = (Uri.base.scheme.isEmpty) ? 'http' : Uri.base.scheme;
      final host = (Uri.base.host.isEmpty) ? 'localhost' : Uri.base.host;
      return '$scheme://$host:5000/api';
    } else {
      return 'http://10.0.2.2:5000/api';
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




  // ==================== 📱 APP CONTENT MANAGEMENT ====================

  // جلب جميع محتويات التطبيق
  static Future<Map<String, dynamic>> getAllContent({
    String? contentType,
    bool? isActive,
    int page = 1,
    int limit = 50,
    String search = '',
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (contentType != null && contentType.isNotEmpty) {
        params['content_type'] = contentType;
      }

      if (isActive != null) {
        params['is_active'] = isActive.toString();
      }

      if (search.isNotEmpty) {
        params['search'] = search;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/content').replace(queryParameters: params),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load content: ${response.statusCode}');
      }
    } catch (e) {
      print('Get all content error: $e');
      rethrow;
    }
  }

  // جلب تفاصيل محتوى محدد
  static Future<Map<String, dynamic>> getContentDetails(int contentId) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/content/$contentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load content details: ${response.statusCode}');
      }
    } catch (e) {
      print('Get content details error: $e');
      rethrow;
    }
  }

  // إنشاء محتوى جديد
  static Future<Map<String, dynamic>> createContent(Map<String, dynamic> contentData) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$baseUrl/content'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(contentData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create content: ${response.statusCode}');
      }
    } catch (e) {
      print('Create content error: $e');
      rethrow;
    }
  }

  // تحديث محتوى موجود
  static Future<Map<String, dynamic>> updateContent(int contentId, Map<String, dynamic> updateData) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.put(
        Uri.parse('$baseUrl/content/$contentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update content: ${response.statusCode}');
      }
    } catch (e) {
      print('Update content error: $e');
      rethrow;
    }
  }

  // حذف محتوى
  static Future<Map<String, dynamic>> deleteContent(int contentId) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.delete(
        Uri.parse('$baseUrl/content/$contentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete content: ${response.statusCode}');
      }
    } catch (e) {
      print('Delete content error: $e');
      rethrow;
    }
  }

  // إعادة ترتيب المحتويات
  static Future<Map<String, dynamic>> reorderContent(String contentType, List<Map<String, dynamic>> orderUpdates) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$baseUrl/content/reorder'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'content_type': contentType,
          'order_updates': orderUpdates,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to reorder content: ${response.statusCode}');
      }
    } catch (e) {
      print('Reorder content error: $e');
      rethrow;
    }
  }

  // ==================== 👤 PUBLIC CONTENT (للمستخدمين العاديين) ====================

  // جلب أقسام المساعدة والدعم للمستخدمين العاديين
  // جلب أقسام المساعدة والدعم
static Future<Map<String, dynamic>> getHelpSections({String language = 'ar'}) async {
  try {
    print('🔗 Fetching from: ${publicBaseUrl}/admin/public/help-sections');
    
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(
      Uri.parse('${publicBaseUrl}/admin/public/help-sections').replace(queryParameters: {
        'lang': language,
      }),
      headers: headers,
    ).timeout(Duration(seconds: 10));

    print('📊 Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to load help sections: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Get help sections error: $e');
    return {
      'success': false,
      'data': {'sections': []}
    };
  }
}

// جلب محتوى صفحة "حول التطبيق"
static Future<Map<String, dynamic>> getAboutContent({String language = 'ar'}) async {
  try {
    print('🔗 Fetching from: ${publicBaseUrl}/admin/public/about-content');
    
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(
      Uri.parse('${publicBaseUrl}/admin/public/about-content').replace(queryParameters: {
        'lang': language,
      }),
      headers: headers,
    ).timeout(Duration(seconds: 10));

    print('📊 Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to load about content: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Get about content error: $e');
    return {
      'success': false,
      'data': {
        'about_sections': [],
        'privacy_policy': null,
        'terms_of_service': null,
        'app_info': {
          'version': '1.0.0',
          'build': '1',
          'copyright': '© ${DateTime.now().year} Jusoor App'
        }
      }
    };
  }
}
  // ==================== 📊 CONTENT STATISTICS ====================

  // جلب إحصائيات المحتوى
  static Future<Map<String, dynamic>> getContentStatistics() async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/content').replace(queryParameters: {
          'page': '1',
          'limit': '1',
        }),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data']['statistics'] ?? {}
        };
      } else {
        throw Exception('Failed to load content statistics: ${response.statusCode}');
      }
    } catch (e) {
      print('Get content statistics error: $e');
      return {
        'success': false,
        'data': {}
      };
    }
  }

  // ==================== 📋 BATCH OPERATIONS ====================

  // تحديث حالة عدة محتويات دفعة واحدة
  static Future<Map<String, dynamic>> batchUpdateContentStatus(
    List<int> contentIds,
    bool isActive,
    String reason,
  ) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$baseUrl/content/batch-update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'content_ids': contentIds,
          'is_active': isActive,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to batch update content: ${response.statusCode}');
      }
    } catch (e) {
      print('Batch update content error: $e');
      rethrow;
    }
  }

  // استيراد محتوى من ملف
  static Future<Map<String, dynamic>> importContent(List<Map<String, dynamic>> contentList) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$baseUrl/content/import'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'contents': contentList,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to import content: ${response.statusCode}');
      }
    } catch (e) {
      print('Import content error: $e');
      rethrow;
    }
  }

  // تصدير المحتوى إلى ملف
  static Future<Map<String, dynamic>> exportContent({
    String? contentType,
    bool? isActive,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final params = <String, String>{};
      if (contentType != null) params['content_type'] = contentType;
      if (isActive != null) params['is_active'] = isActive.toString();

      final response = await http.get(
        Uri.parse('$baseUrl/content/export').replace(queryParameters: params),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to export content: ${response.statusCode}');
      }
    } catch (e) {
      print('Export content error: $e');
      rethrow;
    }
  }

  // ==================== 🔍 SEARCH AND FILTER ====================

  // البحث في المحتوى
  static Future<Map<String, dynamic>> searchContent({
    required String query,
    String? contentType,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token found');

      final params = <String, String>{
        'search': query,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (contentType != null && contentType.isNotEmpty) {
        params['content_type'] = contentType;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/content').replace(queryParameters: params),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to search content: ${response.statusCode}');
      }
    } catch (e) {
      print('Search content error: $e');
      rethrow;
    }
  }

  // ==================== 📱 CONTENT PREVIEW ====================

  // معاينة المحتوى قبل الحفظ
  static Future<Map<String, dynamic>> previewContent(Map<String, dynamic> contentData) async {
    try {
      // هذه دالة محلية فقط للمعاينة، لا ترسل للخادم
      return {
        'success': true,
        'data': {
          'preview': contentData,
          'character_count': {
            'title_ar': contentData['title_ar']?.length ?? 0,
            'title_en': contentData['title_en']?.length ?? 0,
            'content_ar': contentData['content_ar']?.length ?? 0,
            'content_en': contentData['content_en']?.length ?? 0,
          },
          'estimated_read_time': _calculateReadTime(
            contentData['content_ar'] ?? '',
            contentData['content_en'] ?? '',
          ),
        }
      };
    } catch (e) {
      print('Preview content error: $e');
      rethrow;
    }
  }

  // حساب وقت القراءة المقدر
  static Map<String, dynamic> _calculateReadTime(String contentAr, String contentEn) {
    const wordsPerMinute = 200;
    
    final wordsAr = contentAr.split(RegExp(r'\s+')).length;
    final wordsEn = contentEn.split(RegExp(r'\s+')).length;
    
    final minutesAr = (wordsAr / wordsPerMinute).ceil();
    final minutesEn = (wordsEn / wordsPerMinute).ceil();
    
    return {
      'arabic': minutesAr,
      'english': minutesEn,
      'total': minutesAr + minutesEn,
    };
  }

  // ==================== 🎯 CONTENT VALIDATION ====================

  // التحقق من صحة المحتوى
  static Future<Map<String, dynamic>> validateContent(Map<String, dynamic> contentData) async {
    try {
      final errors = <String, String>{};

      // التحقق من العنوان العربي
      if (contentData['title_ar'] == null || contentData['title_ar'].toString().isEmpty) {
        errors['title_ar'] = 'Arabic title is required';
      } else if (contentData['title_ar'].toString().length > 255) {
        errors['title_ar'] = 'Arabic title must be less than 255 characters';
      }

      // التحقق من العنوان الإنجليزي
      if (contentData['title_en'] == null || contentData['title_en'].toString().isEmpty) {
        errors['title_en'] = 'English title is required';
      } else if (contentData['title_en'].toString().length > 255) {
        errors['title_en'] = 'English title must be less than 255 characters';
      }

      // التحقق من المحتوى العربي
      if (contentData['content_ar'] == null || contentData['content_ar'].toString().isEmpty) {
        errors['content_ar'] = 'Arabic content is required';
      }

      // التحقق من المحتوى الإنجليزي
      if (contentData['content_en'] == null || contentData['content_en'].toString().isEmpty) {
        errors['content_en'] = 'English content is required';
      }

      // التحقق من مفتاح القسم
      if (contentData['section_key'] == null || contentData['section_key'].toString().isEmpty) {
        errors['section_key'] = 'Section key is required';
      } else if (!RegExp(r'^[a-z_]+$').hasMatch(contentData['section_key'].toString())) {
        errors['section_key'] = 'Section key must contain only lowercase letters and underscores';
      }

      // التحقق من نوع المحتوى
      final validTypes = ['help_section', 'about_section', 'faq', 'privacy_policy', 'terms_of_service'];
      if (!validTypes.contains(contentData['content_type'])) {
        errors['content_type'] = 'Invalid content type';
      }

      return {
        'success': errors.isEmpty,
        'data': {
          'is_valid': errors.isEmpty,
          'errors': errors,
          'warnings': errors.isEmpty ? [] : ['Please fix the errors above'],
        }
      };
    } catch (e) {
      print('Validate content error: $e');
      return {
        'success': false,
        'data': {
          'is_valid': false,
          'errors': {'general': 'Validation failed'},
          'warnings': ['Unable to validate content'],
        }
      };
    }
  }
}
