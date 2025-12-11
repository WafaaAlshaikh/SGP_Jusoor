import 'dart:convert';
import 'dart:io';
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

  // ========== Upload Profile Picture ==========
  static Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-profile-picture'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          imageFile.path,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      print('📤 Uploading profile picture to: $baseUrl/upload-profile-picture');
      print('📁 File path: ${imageFile.path}');

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('📥 Upload response status: ${response.statusCode}');
      print('📥 Upload response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success']) {
          return {
            'success': true,
            'profile_picture': responseData['data']['profile_picture'],
            'user': responseData['data']['user'],
            'message': responseData['message'],
          };
        } else {
          throw Exception(responseData['message'] ?? 'Failed to upload image');
        }
      } else {
        throw Exception('Upload failed: ${responseData['message']} (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error in uploadProfilePicture: $e');
      rethrow;
    }
  }

  // ========== Get user profile ==========
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

  // ========== Update user profile ==========
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

  // ========== Update specialist info ==========
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

  // ========== Change password ==========
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

  // ========== Helper: Validate image size ==========
  static Future<bool> validateImageSize(File imageFile, {int maxSizeMB = 5}) async {
    try {
      final sizeInBytes = await imageFile.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      return sizeInMB <= maxSizeMB;
    } catch (e) {
      print('Error checking image size: $e');
      return false;
    }
  }

  // ========== Helper: Test connection ==========
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