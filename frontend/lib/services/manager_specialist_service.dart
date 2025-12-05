import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerSpecialistService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ==================== جلب جميع الأخصائيين ====================
  static Future<Map<String, dynamic>> getAllSpecialists() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/specialists'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load specialists: ${response.statusCode}');
      }
    } catch (e) {
      print('Get All Specialists Error: $e');
      rethrow;
    }
  }

  // ==================== جلب تفاصيل أخصائي معين ====================
  static Future<Map<String, dynamic>> getSpecialistDetails(int specialistId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/specialists/$specialistId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load specialist details: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Specialist Details Error: $e');
      rethrow;
    }
  }

  // ==================== إضافة أخصائي جديد ====================
  static Future<Map<String, dynamic>> addSpecialist({
    required String fullName,
    required String email,
    required String specialization,
    String? phone,
    int? yearsExperience,
    double? salary,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final Map<String, dynamic> requestBody = {
        'full_name': fullName,
        'email': email,
        'specialization': specialization,
      };

      if (phone != null && phone.isNotEmpty) {
        requestBody['phone'] = phone;
      }
      if (yearsExperience != null) {
        requestBody['years_experience'] = yearsExperience;
      }
      if (salary != null) {
        requestBody['salary'] = salary;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/manager/specialists'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return responseBody;
      } else {
        throw Exception('Failed to add specialist: ${responseBody['message']}');
      }
    } catch (e) {
      print('Add Specialist Error: $e');
      rethrow;
    }
  }

  // ==================== جلب جداول جميع الأخصائيين ====================
  static Future<Map<String, dynamic>> getAllSpecialistsSchedules() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/specialists/schedules'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load specialists schedules: ${response.statusCode}');
      }
    } catch (e) {
      print('Get All Schedules Error: $e');
      rethrow;
    }
  }

  // ==================== جلب جدول أخصائي معين ====================
  static Future<Map<String, dynamic>> getSpecialistSchedule(int specialistId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/specialists/$specialistId/schedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load specialist schedule: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Specialist Schedule Error: $e');
      rethrow;
    }
  }

  // ==================== إضافة جدول لأخصائي ====================
  static Future<Map<String, dynamic>> addSpecialistSchedule({
    required int specialistId,
    required String dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final requestBody = {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/manager/specialists/$specialistId/schedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return responseBody;
      } else {
        throw Exception('Failed to add schedule: ${responseBody['message']}');
      }
    } catch (e) {
      print('Add Schedule Error: $e');
      rethrow;
    }
  }

  // ==================== إضافة جداول متعددة ====================
  static Future<Map<String, dynamic>> addMultipleSchedules({
    required int specialistId,
    required List<Map<String, dynamic>> schedules,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final requestBody = {
        'schedules': schedules,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/manager/specialists/$specialistId/schedules/bulk'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return responseBody;
      } else {
        throw Exception('Failed to add schedules: ${responseBody['message']}');
      }
    } catch (e) {
      print('Add Multiple Schedules Error: $e');
      rethrow;
    }
  }

  // ==================== تعديل جدول ====================
  static Future<Map<String, dynamic>> updateSchedule({
    required int scheduleId,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final Map<String, dynamic> requestBody = {};
      if (dayOfWeek != null) requestBody['day_of_week'] = dayOfWeek;
      if (startTime != null) requestBody['start_time'] = startTime;
      if (endTime != null) requestBody['end_time'] = endTime;

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/schedules/$scheduleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception('Failed to update schedule: ${responseBody['message']}');
      }
    } catch (e) {
      print('Update Schedule Error: $e');
      rethrow;
    }
  }

  // ==================== حذف جدول ====================
  static Future<Map<String, dynamic>> deleteSchedule(int scheduleId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/manager/schedules/$scheduleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception('Failed to delete schedule: ${responseBody['message']}');
      }
    } catch (e) {
      print('Delete Schedule Error: $e');
      rethrow;
    }
  }
}