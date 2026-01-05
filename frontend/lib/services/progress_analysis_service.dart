// lib/services/progress_analysis_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProgressAnalysisService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/specialist';
    } else {
      return 'http://10.0.2.2:5000/api/specialist';
    }
  }

  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      throw Exception('Failed to get token: $e');
    }
  }

  // 🔥 التحليل الشامل مع AI
  static Future<Map<String, dynamic>> analyzeChildProgress(int childId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found. Please login again.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children/$childId/progress-analysis'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 60));

      print('📥 API Response Status: ${response.statusCode}');
    print('📥 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to analyze progress');
      }
    } catch (e) {
      throw Exception('Analysis error: $e');
    }
  }

  // 📊 الإحصائيات السريعة
  static Future<Map<String, dynamic>> getQuickStatistics(int childId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found. Please login again.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children/$childId/quick-stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get statistics');
      }
    } catch (e) {
      throw Exception('Statistics error: $e');
    }
  }

  // 📅 مقارنة بين تاريخين محددين
  static Future<Map<String, dynamic>> compareDateRangeProgress(
      int childId, {
        required String startDate,
        required String endDate,
      }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found. Please login again.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children/$childId/compare-dates?startDate=$startDate&endDate=$endDate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 45));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to compare dates');
      }
    } catch (e) {
      throw Exception('Date comparison error: $e');
    }
  }


// 📊 الحصول على تواريخ التقييمات المتاحة للطفل
  static Future<List<DateTime>> getAvailableEvaluationDates(int childId) async {
    try {
      final analysis = await analyzeChildProgress(childId);
      final evaluations = analysis['evaluation_history'] as List?;

      if (evaluations == null || evaluations.isEmpty) {
        return [];
      }

      final dates = evaluations.map<DateTime>((eval) {
        try {
          final dateStr = eval['date']?.toString() ?? '';
          return DateTime.parse(dateStr);
        } catch (e) {
          return DateTime.now();
        }
      }).toList();

      dates.sort((a, b) => a.compareTo(b));
      return dates;
    } catch (e) {
      throw Exception('Failed to get evaluation dates: $e');
    }
  }

// 📈 الحصول على آخر 5 تقييمات للعرض السريع
  static Future<List<Map<String, dynamic>>> getRecentEvaluations(int childId) async {
    try {
      final analysis = await analyzeChildProgress(childId);
      final evaluations = analysis['evaluation_history'] as List?;

      if (evaluations == null || evaluations.isEmpty) {
        return [];
      }

      // ترتيب تنازلي وأخذ آخر 5
      final sortedEvaluations = List.from(evaluations)
        ..sort((a, b) {
          final dateA = DateTime.parse(a['date']?.toString() ?? '');
          final dateB = DateTime.parse(b['date']?.toString() ?? '');
          return dateB.compareTo(dateA);
        });

      return sortedEvaluations.take(5).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('Failed to get recent evaluations: $e');
    }
  }
  // 📈 تحليل فترة محددة
  static Future<Map<String, dynamic>> analyzePeriodProgress(
      int childId, {
        required String period, // 'last_week', 'last_month', 'last_3_months', 'last_6_months'
      }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No token found. Please login again.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/children/$childId/period-analysis?period=$period'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 45));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to analyze period');
      }
    } catch (e) {
      throw Exception('Period analysis error: $e');
    }
  }
}