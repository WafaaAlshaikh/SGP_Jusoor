import 'package:http/http.dart' as http;
import 'dart:convert';

class OllamaService {
  static const String baseUrl = 'http://10.0.2.2:5001';

  // دالة فحص الحالة الجديدة
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'status': 'Server is running'
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Cannot connect to server: $e'
      };
    }
  }

  // دالة إرسال الرسالة

  static Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      // استخدم الـ quick endpoint للأسرع
      final response = await http.post(
        Uri.parse('$baseUrl/api/quick'),  // ← غير إلى /api/quick
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': message}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'error': 'Please try again'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error'};
    }
  }
}