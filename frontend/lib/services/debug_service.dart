// lib/services/debug_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DebugService {
  static Future<void> debugMyRatings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      print('🔍 === DEBUG MY RATINGS ===');
      print('🔑 Token: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/ratings/my-ratings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('📡 Status: ${response.statusCode}');
      print('📦 Headers: ${response.headers}');
      print('📄 Body:');

      try {
        final data = jsonDecode(response.body);
        print('📊 Success: ${data['success']}');
        print('📊 Message: ${data['message']}');

        if (data['data'] != null) {
          final ratings = data['data']['ratings'] as List;
          print('📈 Number of ratings: ${ratings.length}');

          if (ratings.isNotEmpty) {
            print('📝 First rating sample:');
            print(jsonEncode(ratings.first));

            // تحليل الحقول
            final sample = ratings.first as Map;
            sample.forEach((key, value) {
              print('   $key: $value (${value.runtimeType})');
            });
          }
        }
      } catch (e) {
        print('❌ JSON Parse Error: $e');
        print('📄 Raw body: ${response.body}');
      }

      print('🔍 === END DEBUG ===');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }
}