// manager_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ManagerService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/manager';
    } else {
      return 'http://10.0.2.2:5000/api/manager';
    }
  }

  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  // ✅ جلب الأطفال المسجلين في المؤسسة
  static Future<Map<String, dynamic>> getInstitutionChildren({
    String? search,
    String? registrationStatus,
    String? gender,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'data': []
        };
      }

      print('🔍 Fetching children with token: ${token.substring(0, 20)}...');

      // بناء query parameters
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (registrationStatus != null && registrationStatus != 'All') {
        params['registration_status'] = registrationStatus;
      }
      if (gender != null && gender != 'All') params['gender'] = gender;

      final uri = Uri.parse('$baseUrl/children').replace(queryParameters: params);

      print('🌐 Calling API: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Successfully loaded ${data['data']?.length ?? 0} children');
        return data;
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Authentication failed - please login again',
          'data': []
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Access denied - manager role required',
          'data': []
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to load children',
            'data': []
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
            'data': []
          };
        }
      }
    } catch (e) {
      print('❌ Error in getInstitutionChildren: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': []
      };
    }
  }

  // ✅ جلب طلبات التسجيل المعلقة
  static Future<Map<String, dynamic>> getPendingRegistrationRequests({
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'data': []
        };
      }

      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse('$baseUrl/registration-requests/pending').replace(queryParameters: params);

      print('🌐 Calling API: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Successfully loaded ${data['data']?.length ?? 0} pending requests');
        return data;
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to load pending requests',
            'data': []
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
            'data': []
          };
        }
      }
    } catch (e) {
      print('❌ Error in getPendingRegistrationRequests: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': []
      };
    }
  }

  // ✅ الموافقة على طلب تسجيل
  static Future<Map<String, dynamic>> approveRegistrationRequest(int requestId, {String? notes}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found'
        };
      }

      final response = await http.put(
        Uri.parse('$baseUrl/registration-requests/$requestId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'notes': notes}),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to approve request'
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}'
          };
        }
      }
    } catch (e) {
      print('❌ Error in approveRegistrationRequest: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // ✅ رفض طلب تسجيل
  static Future<Map<String, dynamic>> rejectRegistrationRequest(int requestId, {required String reason}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found'
        };
      }

      final response = await http.put(
        Uri.parse('$baseUrl/registration-requests/$requestId/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to reject request'
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}'
          };
        }
      }
    } catch (e) {
      print('❌ Error in rejectRegistrationRequest: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // ✅ جلب إحصائيات الأطفال
  static Future<Map<String, dynamic>> getChildrenStatistics() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'data': null
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children/statistics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to load statistics',
            'data': null
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
            'data': null
          };
        }
      }
    } catch (e) {
      print('❌ Error in getChildrenStatistics: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null
      };
    }
  }

  // ✅ جلب تفاصيل طفل معين
  static Future<Map<String, dynamic>> getChildDetails(int childId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'data': null
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children/$childId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to load child details',
            'data': null
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
            'data': null
          };
        }
      }
    } catch (e) {
      print('❌ Error in getChildDetails: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null
      };
    }
  }

  // ✅ جلب الإحصائيات المتقدمة للطفل
  static Future<Map<String, dynamic>> getAdvancedChildStatistics(int childId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'data': null
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children/$childId/advanced-statistics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to load advanced statistics',
            'data': null
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
            'data': null
          };
        }
      }
    } catch (e) {
      print('❌ Error in getAdvancedChildStatistics: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null
      };
    }
  }

  // ✅ جلب تحليل الفريق متعدد التخصصات
  static Future<Map<String, dynamic>> getChildMultidisciplinaryInsights(int childId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found',
          'data': null
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children/$childId/multidisciplinary-insights'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to load multidisciplinary insights',
            'data': null
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
            'data': null
          };
        }
      }
    } catch (e) {
      print('❌ Error in getChildMultidisciplinaryInsights: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null
      };
    }
  }

  // ✅ جلب بيانات Team Room للطفل
static Future<Map<String, dynamic>> getChildTeamOverview(int childId) async {
  try {
    final token = await _getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'No authentication token found',
        'data': null
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/children/$childId/team'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to load team overview',
          'data': null
        };
      } catch (e) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
          'data': null
        };
      }
    }
  } catch (e) {
    print('❌ Error in getChildTeamOverview: $e');
    return {
      'success': false,
      'message': 'Network error: ${e.toString()}',
      'data': null
    };
  }
}
}