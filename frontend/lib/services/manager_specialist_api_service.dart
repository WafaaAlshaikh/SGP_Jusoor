import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerSpecialistApiService {
  static String get _baseUrl {
  if (kIsWeb) {
    return 'http://localhost:5000/api';
  } else {
    return 'http://10.0.2.2:5000/api';
  }
} // أو عنوان خادمك

  // دالة عامة للحصول على التوكن
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // دالة مساعدة للتحقق من الاستجابة
  // static Map<String, dynamic> _parseResponse(http.Response response) {
  //   final responseBody = jsonDecode(response.body);

  //   // تحويل أي String numbers إلى doubles في الاستجابة
  //   return _convertStringNumbersToDoubles(responseBody);
  // }

  // دالة لتحويل String numbers إلى doubles
  static Map<String, dynamic> _convertStringNumbersToDoubles(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    void convert(dynamic value) {
      if (value is Map<String, dynamic>) {
        value.forEach((key, val) {
          if (val is String && _isNumeric(val)) {
            value[key] = double.tryParse(val) ?? val;
          } else if (val is Map<String, dynamic>) {
            convert(val);
          } else if (val is List) {
            for (var item in val) {
              if (item is Map<String, dynamic>) {
                convert(item);
              }
            }
          }
        });
      }
    }

    convert(result);
    return result;
  }

  // دالة للتحقق إذا كانت القيمة رقمية
  static bool _isNumeric(String s) {
    if (s == null || s.isEmpty) return false;
    return double.tryParse(s) != null;
  }

  // دالة عامة للـ GET requests
  // static Future<Map<String, dynamic>> getRequest(String endpoint) async {
  //   try {
  //     final token = await _getToken();
  //     if (token == null) {
  //       throw Exception('No authentication token found');
  //     }

  //     final response = await http.get(
  //       Uri.parse('$_baseUrl$endpoint'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       return _parseResponse(response);
  //     } else {
  //       throw Exception('Failed to load data: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('API Error: $e');
  //     rethrow;
  //   }
  // }

  // تحديث ManagerSpecialistApiService لتعمل مع جميع الـ endpoints
static Future<Map<String, dynamic>> getRequest(String endpoint) async {
  try {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return _parseResponse(response);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception('Failed to load data: ${errorBody['message'] ?? response.statusCode}');
    }
  } catch (e) {
    print('API Error: $e');
    rethrow;
  }
}
// أضف هذا الدالة المساعدة:
static Map<String, dynamic> _parseResponse(http.Response response) {
  try {
    final responseBody = jsonDecode(response.body);
    
    // التحقق من وجود البيانات
    if (responseBody['data'] == null) {
      return {
        'success': responseBody['success'] ?? false,
        'message': responseBody['message'] ?? 'No data returned',
        'data': {}
      };
    }
    
    // تحويل أي String numbers إلى doubles في الاستجابة
    return _convertStringNumbersToDoubles(responseBody);
  } catch (e) {
    print('Error parsing response: $e');
    return {
      'success': false,
      'message': 'Failed to parse response',
      'data': {}
    };
  }
}

  // دالة عامة للـ POST requests
  static Future<Map<String, dynamic>> postRequest(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        throw Exception('Failed: ${responseBody['message']}');
      }
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  // دالة عامة للـ PUT requests
  static Future<Map<String, dynamic>> putRequest(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        throw Exception('Failed: ${responseBody['message']}');
      }
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  // دالة عامة للـ DELETE requests
  static Future<Map<String, dynamic>> deleteRequest(String endpoint) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        throw Exception('Failed: ${responseBody['message']}');
      }
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }
}