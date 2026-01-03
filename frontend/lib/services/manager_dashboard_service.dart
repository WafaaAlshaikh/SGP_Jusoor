// lib/services/manager_dashboard_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerDashboardService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api'; // أو الـ URL الخاص بالسيرفر

  // دالة للحصول على التوكن
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ================= Impact Posts (Manager) =================

  static Future<Map<String, dynamic>> listImpactPosts({
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    try {
      final headers = await _getHeaders();
      final query = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (type != null && type.trim().isNotEmpty) {
        query['type'] = type.trim();
      }

      final uri = Uri.parse('$_baseUrl/manager/impact/posts').replace(queryParameters: query);
      final response = await http.get(uri, headers: headers);

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      }

      throw Exception(data['message'] ?? 'Failed to load impact posts');
    } catch (e) {
      print('Error listing impact posts: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createImpactPost(Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/manager/impact/posts'),
        headers: headers,
        body: json.encode(body),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if ((response.statusCode == 201 || response.statusCode == 200) && data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      }
      throw Exception(data['message'] ?? 'Failed to create impact post');
    } catch (e) {
      print('Error creating impact post: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateImpactPost(int postId, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/manager/impact/posts/$postId'),
        headers: headers,
        body: json.encode(body),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return (data['data'] is Map<String, dynamic>) ? (data['data'] as Map<String, dynamic>) : <String, dynamic>{};
      }
      throw Exception(data['message'] ?? 'Failed to update impact post');
    } catch (e) {
      print('Error updating impact post: $e');
      rethrow;
    }
  }

  static Future<void> deleteImpactPost(int postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/manager/impact/posts/$postId'),
        headers: headers,
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return;
      }
      throw Exception(data['message'] ?? 'Failed to delete impact post');
    } catch (e) {
      print('Error deleting impact post: $e');
      rethrow;
    }
  }

  // Get institution-level impact (money + equipment + impact posts)
  static Future<Map<String, dynamic>> getInstitutionDonationImpactV2() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/manager/donations/impact/v2'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to load impact');
        }
      } else {
        throw Exception('Failed to load impact: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching institution donation impact v2: $e');
      rethrow;
    }
  }

  // دالة للحصول على الـ Headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // جلب إحصائيات Dashboard
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/DashbordManager/dashboard/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch dashboard stats');
        }
      } else {
        throw Exception('Failed to load dashboard stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      rethrow;
    }
  }

  // Get detailed impact for a single campaign
  static Future<Map<String, dynamic>> getDonationCampaignImpact(
      int campaignId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/manager/donations/campaigns/$campaignId/impact'),
        headers: headers,
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(data['message'] ?? 'Failed to load campaign impact');
      }
    } catch (e) {
      print('Error fetching donation campaign impact: $e');
      rethrow;
    }
  }

  // ================= Donation Campaigns (Manager) =================

  // Get all campaigns for the manager's institution
  static Future<List<dynamic>> getDonationCampaigns() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/manager/donations/campaigns'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as List<dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch campaigns');
        }
      } else {
        throw Exception('Failed to load campaigns: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching donation campaigns: $e');
      rethrow;
    }
  }

  // Create a new campaign
  static Future<Map<String, dynamic>> createDonationCampaign(
      Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/manager/donations/campaigns'),
        headers: headers,
        body: json.encode(body),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(data['message'] ?? 'Failed to create campaign');
      }
    } catch (e) {
      print('Error creating donation campaign: $e');
      rethrow;
    }
  }

  // Update an existing campaign
  static Future<Map<String, dynamic>> updateDonationCampaign(
      int campaignId, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/manager/donations/campaigns/$campaignId'),
        headers: headers,
        body: json.encode(body),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(data['message'] ?? 'Failed to update campaign');
      }
    } catch (e) {
      print('Error updating donation campaign: $e');
      rethrow;
    }
  }

  // جلب التقرير المالي للمؤسسة
  static Future<Map<String, dynamic>> getFinancialReport() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/DashbordManager/financial/report'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch financial report');
        }
      } else {
        throw Exception('Failed to load financial report: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching financial report: $e');
      rethrow;
    }
  }

  // جلب تفاصيل التبرعات (قائمة التبرعات + التخصيصات)
  static Future<Map<String, dynamic>> getDonationDetails() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/DashbordManager/dashboard/donations'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch donation details');
        }
      } else {
        throw Exception('Failed to load donation details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching donation details: $e');
      rethrow;
    }
  }

  // دالة للـ Debugging
  static Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/DashbordManager/debug'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load debug info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching debug info: $e');
      rethrow;
    }
  }





  static Future<Map<String, dynamic>> getDonationStatistics() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/manager/donations/statistics'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch donation statistics');
        }
      } else {
        throw Exception('Failed to load donation statistics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching donation statistics: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getFilteredDonationStatistics({
    DateTime? startDate,
    DateTime? endDate,
    int? campaignId,
    double? minAmount,
    double? maxAmount,
    String groupBy = 'day',
  }) async {
    try {
      final headers = await _getHeaders();
      
      final params = <String, String>{
        'groupBy': groupBy,
      };
      
      if (startDate != null) {
        params['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        params['endDate'] = endDate.toIso8601String();
      }
      if (campaignId != null) {
        params['campaignId'] = campaignId.toString();
      }
      if (minAmount != null) {
        params['minAmount'] = minAmount.toString();
      }
      if (maxAmount != null) {
        params['maxAmount'] = maxAmount.toString();
      }
      
      final uri = Uri.parse('$_baseUrl/manager/donations/statistics/filtered')
        .replace(queryParameters: params);
      
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch filtered statistics');
        }
      } else {
        throw Exception('Failed to load filtered statistics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching filtered donation statistics: $e');
      rethrow;
    }
  }

// جلب إحصائيات التبرعات العينية
static Future<Map<String, dynamic>> getEquipmentDonationStats() async {
  try {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/DashbordManager/dashboard/equipment-stats'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch equipment donation stats');
      }
    } else {
      throw Exception('Failed to load equipment donation stats: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching equipment donation stats: $e');
    rethrow;
  }
}

// جلب قائمة التبرعات العينية مع الفلاتر
static Future<Map<String, dynamic>> getEquipmentDonationsList({
  int page = 1,
  int limit = 10,
  String? status,
  String? condition,
  int? categoryId,
  String? search,
  String? startDate,
  String? endDate,
}) async {
  try {
    final headers = await _getHeaders();
    
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    if (status != null && status != 'all') {
      params['status'] = status;
    }
    
    if (condition != null && condition != 'all') {
      params['condition'] = condition;
    }
    
    if (categoryId != null && categoryId != -1) {
      params['category_id'] = categoryId.toString();
    }
    
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    
    if (startDate != null) {
      params['startDate'] = startDate;
    }
    
    if (endDate != null) {
      params['endDate'] = endDate;
    }
    
    final uri = Uri.parse('$_baseUrl/DashbordManager/dashboard/equipment-donations')
      .replace(queryParameters: params);
    
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch equipment donations list');
      }
    } else {
      throw Exception('Failed to load equipment donations list: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching equipment donations list: $e');
    rethrow;
  }
}

// تحديث حالة التبرع العيني
static Future<void> updateEquipmentDonationStatus(
  int donationId,
  Map<String, dynamic> data,
) async {
  try {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$_baseUrl/DashbordManager/dashboard/equipment-donations/$donationId/status'),
      headers: headers,
      body: json.encode(data),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);
    if (response.statusCode == 200 && responseData['success'] == true) {
      return;
    } else {
      throw Exception(responseData['message'] ?? 'Failed to update donation status');
    }
  } catch (e) {
    print('Error updating equipment donation status: $e');
    rethrow;
  }
}
  


 
}
