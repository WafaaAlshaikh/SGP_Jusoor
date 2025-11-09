import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AIService {

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/ai'; // للويب
    } else {
      return 'http://10.0.2.2:5000/api/ai'; // للموبايل
    }
  }

  /// Get JWT token from storage
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Get headers with authentication
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// 📚 Get specialist advice (5 evidence-based tips)
  static Future<Map<String, dynamic>> getSpecialistAdvice() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/specialist-advice'),
        headers: headers,
      );

      print('📡 AI Advice Response: ${response.statusCode} - URL: $baseUrl/specialist-advice');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        print('❌ Error: ${response.body}');
        return {
          'success': false,
          'message': 'Failed to fetch advice',
        };
      }
    } catch (e) {
      print('❌ AI Service Error: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// 💡 Get daily tip
  static Future<Map<String, dynamic>> getDailyTip() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/daily-tip'),
        headers: headers,
      );

      print('📡 Daily Tip Response: ${response.statusCode} - URL: $baseUrl/daily-tip');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch daily tip',
        };
      }
    } catch (e) {
      print('❌ Daily Tip Error: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// 🏃 Get specialized exercise
  static Future<Map<String, dynamic>> getSpecializedExercise({String? focusArea}) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/specialized-exercise';
      if (focusArea != null && focusArea.isNotEmpty) {
        url += '?focus_area=$focusArea';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('📡 Exercise Response: ${response.statusCode} - URL: $url');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch exercise',
        };
      }
    } catch (e) {
      print('❌ Exercise Error: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// 🧪 Test API connection
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/test'));
      print('🔗 Test Connection Response: ${response.statusCode} - URL: $baseUrl/test');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Test Connection Failed: $e');
      return false;
    }
  }
}