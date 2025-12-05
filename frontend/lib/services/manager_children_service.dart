import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerChildrenService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api'; // أو عنوان خادمك

  static Future<Map<String, dynamic>> getChildrenManagementData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/children-management'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Managers only.');
      } else if (response.statusCode == 404) {
        throw Exception('Manager or institution not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load data');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getDetailedStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/children-management/statistics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load statistics');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> approveRegistrationRequest(
      int requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/registration-requests/$requestId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': 'Approved'}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to approve request');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> rejectRegistrationRequest(int requestId,
      {String? reason}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/registration-requests/$requestId/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': 'Rejected',
          'reason': reason ?? 'Request rejected'
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to reject request');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateChildStatus({
    required int childId,
    required String status,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/children/$childId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': status,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            errorData['message'] ?? 'Failed to update child status');
      }
    } catch (e) {
      rethrow;
    }
  }


  static Future<Map<String, dynamic>> getChildDetailedInfo(int childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/child/$childId/detailed-info'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Managers only.');
      } else if (response.statusCode == 404) {
        throw Exception('Child not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load child details');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getChildDetails(int childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/children/$childId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load child details');
      }
    } catch (e) {
      rethrow;
    }
  }

// 1. جلب قائمة الآباء
  static Future<Map<String, dynamic>> getParentsList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/children/parents'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Managers only.');
      } else if (response.statusCode == 404) {
        throw Exception('Institution not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load parents list');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 2. جلب الأخصائيين المتاحين
  static Future<Map<String, dynamic>> getAvailableSpecialists({String? date}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      // بناء URL مع أو بدون تاريخ
      String url = '$_baseUrl/manager/children/available-specialists';
      if (date != null) {
        url += '?date=$date';
      }

      print('Requesting available specialists from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Date is required');
      } else if (response.statusCode == 404) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'No available specialists found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load available specialists');
      }
    } catch (e) {
      print('Error in getAvailableSpecialists: $e');
      rethrow;
    }
  }

  // 3. إضافة طفل جديد - UPDATED
  static Future<Map<String, dynamic>> addNewChild({
    required Map<String, dynamic> parentData,
    required Map<String, dynamic> childData,
    Map<String, dynamic>? sessionData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('Sending add child request...');
      print('Parent data: $parentData');
      print('Child data: $childData');
      print('Session data: $sessionData');

      final response = await http.post(
        Uri.parse('$_baseUrl/manager/children/add-child'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'parentData': parentData,
          'childData': childData,
          'sessionData': sessionData,
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 200) {
        // في بعض الحالات قد يرجع الـ API 200 بدلاً من 201
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Missing required information');
      } else if (response.statusCode == 404) {
        throw Exception('Institution not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to add child');
      }
    } catch (e) {
      print('Error in addNewChild: $e');
      rethrow;
    }
  }


  // 4. حجز جلسة General
  static Future<Map<String, dynamic>> bookGeneralSession({
    required int childId,
    required int specialistId,
    required String date,
    required String startTime,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/manager/children/book-general-session'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'child_id': childId,
          'specialist_id': specialistId,
          'date': date,
          'start_time': startTime,
          'notes': notes,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        throw Exception('Missing required information');
      } else if (response.statusCode == 404) {
        throw Exception('Child or specialist not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to book session');
      }
    } catch (e) {
      rethrow;
    }
  }

}