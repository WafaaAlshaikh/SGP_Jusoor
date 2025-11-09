// services/user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class UserService {
  // 🔥 تحديد الـ baseUrl بناءً على المنصة
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000'; // للويب
    } else {
      return 'http://10.0.2.2:5000'; // للموبايل
    }
  }

  // 🔹 Check if user is logged in to backend
  static Future<bool> isLoggedInToBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  // 🔹 Get available users with improved error handling
  static Future<List<Map<String, dynamic>>> getAvailableUsers() async {
    try {
      // Check login first
      if (!await isLoggedInToBackend()) {
        print('⚠️ User not logged in to backend - using mock data');
        return _getMockUsers();
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      print('🔄 Fetching available chat users from API...');

      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/available-users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          final List<dynamic> users = data['data'];
          print('✅ Successfully fetched ${users.length} users for chat from API');

          // Convert data to correct type
          List<Map<String, dynamic>> formattedUsers = [];
          for (var user in users) {
            final userMap = Map<String, dynamic>.from(user);
            formattedUsers.add({
              'id': userMap['id'].toString(),
              'name': userMap['name'] ?? '',
              'email': userMap['email'] ?? '',
              'role': userMap['role'] ?? '',
              'institution': userMap['institution'],
              'profileImage': userMap['profileImage'], // ✅ This comes from backend
              'specialization': userMap['specialization'] ?? '',
            });
          }

          return formattedUsers;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch users');
        }
      } else if (response.statusCode == 401) {
        print('❌ Invalid token - deleting token and user not logged in');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        return _getMockUsers();
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ Error fetching users from API: $e');
      return _getMockUsers();
    }
  }

  // Enhanced mock data
  static List<Map<String, dynamic>> _getMockUsers() {
    return [
      {
        'id': '1',
        'name': 'Dr. Ahmed Mohamed',
        'email': 'ahmed@jusoor.com',
        'role': 'Specialist',
        'institution': 'Jusoor Care Center',
        'profileImage': null,
        'specialization': 'Speech and Language Specialist',
        'isMock': true
      },
      {
        'id': '2',
        'name': 'Mohamed\'s Mother',
        'email': 'parent@jusoor.com',
        'role': 'Parent',
        'institution': null,
        'profileImage': null,
        'specialization': 'Parent',
        'isMock': true
      },
      {
        'id': '3',
        'name': 'Center Manager',
        'email': 'manager@jusoor.com',
        'role': 'Manager',
        'institution': 'Jusoor Care Center',
        'profileImage': null,
        'specialization': 'Manager',
        'isMock': true
      },
    ];
  }
}