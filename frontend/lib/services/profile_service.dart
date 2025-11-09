import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfileService {
  // 🔥 تحديد الـ baseUrl بناءً على المنصة
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/users'; // للويب
    } else {
      return 'http://10.0.2.2:5000/api/users'; // للموبايل
    }
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Get Profile Response: ${response.statusCode} - URL: $baseUrl/profile');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? profilePicture,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final Map<String, dynamic> body = {};
      if (fullName != null) body['full_name'] = fullName;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (profilePicture != null) body['profile_picture'] = profilePicture;

      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      print('📡 Update Profile Response: ${response.statusCode} - URL: $baseUrl/profile');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  // Update specialist info (without salary)
  static Future<Map<String, dynamic>> updateSpecialistInfo({
    String? specialization,
    int? yearsExperience,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final Map<String, dynamic> body = {};
      if (specialization != null) body['specialization'] = specialization;
      if (yearsExperience != null) body['years_experience'] = yearsExperience;

      final response = await http.put(
        Uri.parse('$baseUrl/specialist-info'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      print('📡 Update Specialist Info Response: ${response.statusCode} - URL: $baseUrl/specialist-info');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to update specialist info: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating specialist info: $e');
    }
  }

  // Change password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/change-password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      print('📡 Change Password Response: ${response.statusCode} - URL: $baseUrl/change-password');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to change password: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error changing password: $e');
    }
  }

  // 🔥 دالة إضافية للتحقق من اتصال السيرفر
  static Future<bool> testConnection() async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('🔗 Profile Service Connection Test: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Profile Service Connection Failed: $e');
      return false;
    }
  }
}