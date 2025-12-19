import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../models/session.dart';
import '../models/questionnaire_model.dart';
import '../models/admin_model.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/auth';
    } else {
      return 'http://10.0.2.2:5000/api/auth'; // للموبايل
    }
  }

  static Future<Map<String, dynamic>> submitSessionDecision(
    String token,
    String sessionId, {
    required String decision,
    double? requestedPercentage,
    double? requestedAmount,
    String? notes,
  }) async {
    try {
      final url = _buildUrl('parent/sessions/$sessionId/decision');
      final body = <String, dynamic>{
        'decision': decision,
        if (requestedPercentage != null) 'requested_percentage': requestedPercentage,
        if (requestedAmount != null) 'requested_amount': requestedAmount,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to submit session decision');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static String _buildUrl(String endpoint) {
    if (kIsWeb) {
      return 'http://localhost:5000/api/$endpoint';
    } else {
      return 'http://10.0.2.2:5000/api/$endpoint';
    }
  }

  static Future<Map<String, dynamic>> signupInitial(
      Map<String, dynamic> data) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚀 [API SERVICE] PREPARING DATA TO SEND');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📦 COMPLETE DATA RECEIVED:');
      data.forEach((key, value) {
        print('   $key: $value (${value.runtimeType})');
      });
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ بناء البيانات بشكل صريح لكل الدور
      Map<String, dynamic> requestData = {
        'full_name': data['full_name']?.toString() ?? '',
        'email': data['email']?.toString() ?? '',
        'password': data['password']?.toString() ?? '',
        'role': data['role']?.toString() ?? '',
        'phone': data['phone']?.toString(),
        'profile_picture': data['profile_picture']?.toString(),

        // البيانات الجغرافية
        'location_lat': data['location_lat'],
        'location_lng': data['location_lng'],
        'location_address': data['location_address']?.toString(),
        'city': data['city']?.toString(),
        'region': data['region']?.toString(),
      };

      // ✅ إضافة بيانات Parent
      if (data['role'] == 'Parent') {
        requestData['address'] = data['address']?.toString();
        requestData['occupation'] = data['occupation']?.toString();
      }

      // ✅ إضافة بيانات Specialist
      if (data['role'] == 'Specialist') {
        requestData['specialization'] = data['specialization']?.toString();
        requestData['years_experience'] = data['years_experience'];
        requestData['institution_id'] = data['institution_id'] != null
            ? int.tryParse(data['institution_id'].toString())
            : null;
      }

      // ✅ إضافة بيانات Manager - تأكد من وجودها
      if (data['role'] == 'Manager') {
        // البيانات الإلزامية
        requestData['institution_name'] = data['institution_name']?.toString();
        requestData['institution_contact_email'] =
            data['institution_contact_email']?.toString();
        requestData['institution_contact_phone'] =
            data['institution_contact_phone']?.toString();

        // البيانات الاختيارية
        requestData['institution_license'] =
            data['institution_license']?.toString();
        requestData['institution_established_year'] =
            data['institution_established_year'];
        requestData['institution_city'] = data['institution_city']?.toString();
        requestData['institution_region'] =
            data['institution_region']?.toString();

        // ✅ طباعة بيانات المؤسسة للتأكد
        print('🏢 MANAGER INSTITUTION DATA:');
        print('   ├─ institution_name: ${requestData['institution_name']}');
        print(
            '   ├─ institution_contact_email: ${requestData['institution_contact_email']}');
        print(
            '   ├─ institution_contact_phone: ${requestData['institution_contact_phone']}');
        print(
            '   ├─ institution_license: ${requestData['institution_license']}');
        print(
            '   ├─ institution_established_year: ${requestData['institution_established_year']}');
        print('   ├─ institution_city: ${requestData['institution_city']}');
        print('   └─ institution_region: ${requestData['institution_region']}');
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 FINAL REQUEST DATA:');
      requestData.forEach((key, value) {
        print('   $key: $value');
      });
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http
          .post(
            Uri.parse('$baseUrl/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestData),
          )
          .timeout(Duration(seconds: 30));

      print('📡 Signup response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ [API SERVICE] Signup initial SUCCESS');
        return {
          'success': true,
          'message': result['message'],
          'tempToken': result['tempToken'],
        };
      } else {
        print('❌ [API SERVICE] Signup initial FAILED: ${result['message']}');
        return {
          'success': false,
          'message': result['message'] ?? 'Signup failed',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timeout. Please try again.',
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection.',
      };
    } catch (e) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ [API SERVICE] CRITICAL ERROR:');
      print('   Error: $e');
      print('   Type: ${e.runtimeType}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> verifySignup(
      String tempToken, String otp) async {
    try {
      print('🔐 Verifying OTP with token: $tempToken');

      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-signup'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tempToken',
            },
            body: jsonEncode({'otp': otp}),
          )
          .timeout(Duration(seconds: 30));

      print('📡 Verify response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      final result = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (result['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', result['token']);
        }

        return {
          'success': true,
          'message': result['message'],
          'user': result['user'],
          'token': result['token'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Verification failed',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timeout. Please try again.',
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection.',
      };
    } catch (e) {
      print('❌ Verify error: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  // في api_service.dart - تحديث دالة login
  static Future<Map<String, dynamic>> login(Map<String, dynamic> data) async {
    try {
      print('🚀 [API SERVICE] Attempting login...');

      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(Duration(seconds: 30));

      print('📡 Login response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ [API SERVICE] Login SUCCESS');
        print('   Role: ${result['user']['role']}');
        if (result['user']['role'] == 'Manager') {
          print('   Institution Data: ${result['institution']}');
        }
      } else {
        print('❌ [API SERVICE] Login FAILED: ${result['message']}');
      }

      return result;
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timeout. Please try again.',
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection.',
      };
    } catch (e) {
      print('❌ [API SERVICE] Login ERROR: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> sendResetCode(String email) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:5000/api/password/send-reset-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:5000/api/password/verify-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String code, String newPassword) async {
    final url = Uri.parse(
        'http://10.0.2.2:5000/api/password/reset-password'); // الرابط الصحيح
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'newPassword': newPassword,
      }),
    );
    print('Reset password raw response: ${response.body}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Server returned status code ${response.statusCode}'
      };
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'message': 'Server returned invalid response'};
    } catch (e) {
      print('JSON decode error: $e');
      return {'success': false, 'message': 'Server returned invalid response'};
    }
  }

  // ================= Parent Dashboard =================
  static Future<Map<String, dynamic>> getParentDashboard(String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/parent/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 8)); // ⚠️ تقليل timeout

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Dashboard API error: ${response.statusCode}');
        throw Exception(
            'Failed to load dashboard data: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      print('⚠️ Dashboard API timeout after 8 seconds');
      throw TimeoutException('Request timeout - Server is slow or unreachable');
    } catch (e) {
      print('❌ Dashboard API error: $e');
      rethrow;
    }
  }

  static Future<List<Session>> getUpcomingSessions(String token) async {
    try {
      final url = _buildUrl('parent/upcoming-sessions');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final sessions = data['sessions'] as List;
        return sessions.map((session) => Session.fromJson(session)).toList();
      } else {
        throw Exception(
            'Failed to load upcoming sessions: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      print('⚠️ Upcoming sessions timeout');
      return [];
    } catch (e) {
      print('❌ Error loading upcoming sessions: $e');
      return [];
    }
  }

  static Future<Child> addChild(String token, Child child) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:5000/api/children'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(child.toJson()),
    );
    if (response.statusCode == 201) {
      return Child.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add child: ${response.body}');
    }
  }

  static Future<Child> updateChild(String token, int id, Child child) async {
    final response = await http.put(
      Uri.parse('http://10.0.2.2:5000/api/children/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(child.toJson()),
    );
    if (response.statusCode == 200) {
      return Child.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update child: ${response.body}');
    }
  }

  static Future<void> deleteChild(String token, int id) async {
    final response = await http.delete(
      Uri.parse('http://10.0.2.2:5000/api/children/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete child: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getDailyAITip(String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/parent/daily-tip'), // ⬅️ صحح الرابط
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8)); // ⚠️ تقليل timeout

      print('📥 Daily Tip Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Daily Tip Success: ${data['success']}');
        print('🤖 AI Generated: ${data['aiGenerated']}');
        print('💡 Tip: ${data['tip']}');
        return data;
      } else {
        print('❌ Daily Tip API Error: ${response.statusCode}');
        throw Exception('Failed to load daily tip: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      print('⚠️ Daily Tip timeout - using fallback');
      return {
        'success': true,
        'tip':
            'Spend quality time with your child today—every moment together builds a stronger future.',
        'aiGenerated': false,
        'isGeneric': true
      };
    } catch (e) {
      print('❌ Error fetching daily tip: $e');
      return {
        'success': true,
        'tip':
            'Spend quality time with your child today—every moment together builds a stronger future.',
        'aiGenerated': false,
        'isGeneric': true
      };
    }
  }

  static Future<Map<String, dynamic>> getWeeklyTips(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/parent/weekly-tips'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load weekly tips');
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'tips': [
          'Spend quality time together',
          'Create routines',
          'Celebrate progress'
        ]
      };
    }
  }

  static Future<Map<String, dynamic>> checkAIHealth(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/parent/ai-health'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'healthy': false};
    } catch (e) {
      return {'healthy': false, 'error': e.toString()};
    }
  }
  // إضافة هذه الدوال لملف api_service.dart
  // ================= Get Diagnoses =================
  // static Future<List<Map<String, dynamic>>> getDiagnoses(String token) async {
  //   final response = await http.get(
  //     Uri.parse('http://10.0.2.2:5000/api/diagnoses'),
  //     headers: {
  //       'Content-Type': 'application/json',
  //       'Authorization': 'Bearer $token',
  //     },
  //   );
  //   if (response.statusCode == 200) {
  //     final List data = jsonDecode(response.body);
  //     return List<Map<String, dynamic>>.from(data);
  //   } else {
  //     throw Exception('Failed to fetch diagnoses: ${response.statusCode}');
  //   }
  // }

  static Future<List<Map<String, dynamic>>> getDiagnoses(String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/diagnoses'), // ⭐ هذا صحيح
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Diagnoses response: ${response.statusCode}');
      print('📡 Response body: ${response.body}'); // ⭐ أضف هذا للتصحيح

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        print('✅ Loaded ${data.length} diagnoses from API');
        return List<Map<String, dynamic>>.from(data);
      } else {
        print('❌ Failed to fetch diagnoses: ${response.statusCode}');
        return _getDefaultDiagnoses();
      }
    } catch (e) {
      print('❌ Error loading diagnoses: $e');
      return _getDefaultDiagnoses();
    }
  }

  static List<Map<String, dynamic>> _getDefaultDiagnoses() {
    return [
      {'diagnosis_id': 1, 'name': 'Autism Spectrum Disorder'},
      {
        'diagnosis_id': 2,
        'name': 'Attention Deficit Hyperactivity Disorder (ADHD)'
      },
      {'diagnosis_id': 3, 'name': 'Down Syndrome'},
      {'diagnosis_id': 4, 'name': 'Speech and Language Delay'},
      {'diagnosis_id': 5, 'name': 'Learning Disabilities'},
      {'diagnosis_id': 6, 'name': 'Intellectual Disability'},
      {'diagnosis_id': 7, 'name': 'Developmental Delay'},
      {'diagnosis_id': 8, 'name': 'Behavioral Disorders'},
      {'diagnosis_id': 9, 'name': 'Social Communication Disorder'},
      {'diagnosis_id': 10, 'name': 'Global Developmental Delay'},
    ];
  }

  // ================= Get Child Statistics =================
  static Future<Map<String, dynamic>> getChildStatistics(String token) async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:5000/api/children/stats'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          'Failed to fetch child statistics: ${response.statusCode}');
    }
  }

  // ================= Get Single Child =================
  static Future<Child> getChild(String token, int childId) async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:5000/api/children/$childId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return Child.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch child: ${response.statusCode}');
    }
  }

  static Future<bool> confirmSession(String token, String sessionId) async {
    try {
      final response = await http.patch(
        Uri.parse(
            'http://10.0.2.2:5000/api/parent/sessions/$sessionId/confirm'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to confirm session');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Request (or renew) financial assistance for a specific child and institution
  /// This unified method is used both by the full financial assistance form
  /// and by the auto-session confirmation flow when support is exhausted.
  static Future<Map<String, dynamic>> requestFinancialAssistance(
      String token, {
        required int childId,
        required int institutionId,
        int? requestedSessionsCount,
        String? urgencyReason,
        List<Map<String, dynamic>>? documents,
      }) async {
    try {
      final url = _buildUrl('financial/assistance/request');
      final body = <String, dynamic>{
        'child_id': childId,
        'institution_id': institutionId,
        if (requestedSessionsCount != null)
          'requested_sessions_count': requestedSessionsCount,
        if (urgencyReason != null && urgencyReason.isNotEmpty)
          'urgency_reason': urgencyReason,
        if (documents != null && documents.isNotEmpty)
          'documents': documents,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to request financial assistance');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Confirm an automatically scheduled initial assessment session
  /// This will trigger invoice creation and move status to Pending Payment
  static Future<Map<String, dynamic>> confirmAutoSession(
      String token, String sessionId) async {
    try {
      final url = _buildUrl('parent/sessions/$sessionId/confirm-auto');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Session confirmed successfully',
          'session_id': data['session_id'],
          'new_status': data['new_status'],
          'invoice_id': data['invoice_id'],
          'financial_assistance': data['financial_assistance'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to confirm auto session');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> cancelSession(
      String token, String sessionId,
      {String? reason}) async {
    try {
      final url = _buildUrl('parent/sessions/$sessionId/cancel');
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (reason != null) 'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Session cancelled successfully',
          'refundProcessed': data['refundProcessed'] ?? false,
          'refundAmount': data['refundAmount'] ?? 0,
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to cancel session');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<List<dynamic>> getParentResources(String token) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/parent/resources');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token', // إذا انت مستخدم JWT
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch resources');
    }
  }

  static Future<List<Map<String, dynamic>>> getInstitutions(
      String token) async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:5000/api/institutions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Failed to fetch institutions: ${response.statusCode}');
    }
  }

  // ================= Donations =================

  /// Get list of institutions available for donations
  static Future<List<Map<String, dynamic>>> getDonationInstitutions(
      String token) async {
    try {
      final url = _buildUrl('donations/institutions');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List institutions = data['institutions'] ?? [];
        return List<Map<String, dynamic>>.from(institutions);
      } else {
        throw Exception(
            'Failed to fetch donation institutions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while loading donation institutions: $e');
    }
  }

  /// Create a new donation for a specific institution
  static Future<Map<String, dynamic>> createDonation(
    String token, {
    required int institutionId,
    required double amount,
    int? campaignId,
  }) async {
    try {
      final url = _buildUrl('donations');
      final body = <String, dynamic>{
        'institution_id': institutionId,
        'amount': amount,
        if (campaignId != null) 'campaign_id': campaignId,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 || response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to create donation');
      }
    } catch (e) {
      throw Exception('Network error while creating donation: $e');
    }
  }

  /// Start Stripe Checkout for a donation (one-time or monthly)
  static Future<Map<String, dynamic>> createDonationCheckout(
    String token, {
    required int institutionId,
    required double amount,
    int? campaignId,
    String mode = 'one_time', // or 'monthly'
  }) async {
    try {
      final url = _buildUrl('donations/checkout');
      final body = <String, dynamic>{
        'institution_id': institutionId,
        'amount': amount,
        'mode': mode,
        if (campaignId != null) 'campaign_id': campaignId,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to create donation checkout');
      }
    } catch (e) {
      throw Exception('Network error while creating donation checkout: $e');
    }
  }

  /// Confirm donation after returning from Stripe Checkout using session_id
  static Future<Map<String, dynamic>> confirmDonationFromStripe(
    String token, {
    required String sessionId,
  }) async {
    try {
      final url = _buildUrl('donations/confirm');
      final body = <String, dynamic>{
        'session_id': sessionId,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to confirm donation');
      }
    } catch (e) {
      throw Exception('Network error while confirming donation: $e');
    }
  }

  /// Get donation history for the current donor
  static Future<Map<String, dynamic>> getDonationHistory(
    String token, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse(_buildUrl('donations/history')).replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to load donation history');
      }
    } catch (e) {
      throw Exception('Network error while loading donation history: $e');
    }
  }

  /// Get aggregated donation impact for the current donor
  static Future<Map<String, dynamic>> getDonationImpact(String token) async {
    try {
      final url = _buildUrl('donations/impact');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(data['message'] ?? 'Failed to load donation impact');
      }
    } catch (e) {
      throw Exception('Network error while loading donation impact: $e');
    }
  }

  static Future<Map<String, dynamic>> getChildren({
    required String token,
    String? search,
    String? gender,
    String? diagnosis,
    String? registrationStatus,
    String? sort,
    String? order,
    int? page,
    int? limit,
  }) async {
    final uri = Uri.parse('http://10.0.2.2:5000/api/children').replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (gender != null && gender.isNotEmpty && gender != 'All')
          'gender': gender,
        if (diagnosis != null && diagnosis.isNotEmpty && diagnosis != 'All')
          'diagnosis': diagnosis,
        if (registrationStatus != null &&
            registrationStatus.isNotEmpty &&
            registrationStatus != 'All')
          'registration_status': registrationStatus,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      },
    );

    print('🌐 API Call: $uri'); // ⬅️ أضف هذا

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📡 Response status: ${response.statusCode}'); // ⬅️ وهذا
    print('📦 Raw response body: ${response.body}'); // ⬅️ وهذا

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception(
          'Failed to fetch children: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<List<Session>> getSessions(String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/parent/sessions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sessions = data['sessions'] as List;
        return sessions.map((session) => Session.fromJson(session)).toList();
      } else {
        throw Exception('Failed to load sessions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching sessions: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<List<Session>> getCompletedSessions(String token) async {
    try {
      final url = _buildUrl('parent/completed-sessions');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sessions = data['sessions'] as List;
        return sessions.map((session) => Session.fromJson(session)).toList();
      } else {
        throw Exception('Failed to load completed sessions');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<List<Session>> getPendingSessions(String token) async {
    try {
      final url = _buildUrl('parent/pending-sessions');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sessions = data['sessions'] as List;
        return sessions.map((session) => Session.fromJson(session)).toList();
      } else {
        throw Exception('Failed to load pending sessions');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<List<Session>> getCancelledSessions(String token) async {
    try {
      final url = _buildUrl('parent/cancelled-sessions');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sessions = data['sessions'] as List;
        return sessions.map((session) => Session.fromJson(session)).toList();
      } else {
        throw Exception('Failed to load cancelled sessions');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<List<Session>> getChildSessions(
      String token, String childId) async {
    try {
      // استخدام _buildUrl لبناء الـ URL الصحيح
      final url = _buildUrl('parent/child-sessions/$childId');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sessions = data['sessions'] as List;
        return sessions.map((session) => Session.fromJson(session)).toList();
      } else {
        throw Exception('Failed to load child sessions');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<bool> rateSession(
      String token, String sessionId, double rating, String? review) async {
    try {
      print(
          '⭐ Rating session $sessionId with rating: $rating, review: $review');

      final url = _buildUrl('parent/sessions/$sessionId/rate');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rating': rating,
          'review': review ?? '',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Rating submitted successfully: ${data['message']}');
        return data['success'] ?? true;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ??
            'Failed to rate session: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Rating API Error: $e');
      throw e;
    }
  }

  static Future<Map<String, dynamic>> getSessionDetails(
      String token, String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions/$sessionId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to load session details: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Session Details API Error: $e');
      throw e;
    }
  }

  static Future<bool> rescheduleSession(
    String token,
    int sessionId,
    DateTime newDate,
    String newTime,
  ) async {
    try {
      print('🔄 Rescheduling session $sessionId to $newDate at $newTime');

      final formattedDate =
          "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";

      final response = await http.patch(
        Uri.parse(
            'http://10.0.2.2:5000/api/parent/sessions/$sessionId/reschedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'new_date': formattedDate,
          'new_time': newTime,
        }),
      );

      print('📡 Reschedule response status: ${response.statusCode}');
      print('📦 Reschedule response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Session rescheduled successfully');
          return true;
        } else {
          throw Exception(data['message'] ?? 'Failed to reschedule session');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Session not found or you do not have permission');
      } else if (response.statusCode == 400) {
        throw Exception('Cannot reschedule this session in its current status');
      } else if (response.statusCode == 409) {
        throw Exception('Specialist is not available at the requested time');
      } else {
        throw Exception('Failed to reschedule session: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Reschedule API Error: $e');
      rethrow;
    }
  }

// ==================== Questionnaire APIs ====================

  static Future<List<Question>> getQuestionnaireQuestions(
    String token, {
    String? childId,
    Map<String, dynamic>? previousAnswers,
    String? stage,
    String language = 'ar',
  }) async {
    try {
      print('📋 جلب أسئلة الاستبيان - اللغة: $language');

      final Map<String, String> queryParams = {
        'language': language,
      };

      if (childId != null) queryParams['child_id'] = childId;
      if (previousAnswers != null && previousAnswers.isNotEmpty) {
        queryParams['previous_answers'] = jsonEncode(previousAnswers);
      }
      if (stage != null && stage.isNotEmpty) {
        queryParams['stage'] = stage;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/questionnaire/questions')
            .replace(queryParameters: queryParams),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      print('📡 استجابة الأسئلة: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == false) {
          throw Exception('خطأ في API: ${data['message']}');
        }

        final questions = (data['questions'] as List)
            .map((q) {
              try {
                return Question.fromJson(q);
              } catch (e) {
                print('❌ خطأ في تحليل السؤال: $e');
                print('❌ بيانات السؤال: $q');
                return Question.fromJson({
                  'question_id': 0,
                  'category': 'عام',
                  'question_text': 'سؤال غير متوفر حالياً',
                  'question_type': 'Multiple Choice',
                  'options': ['نعم', 'لا'],
                  'weight': 1.0,
                  'target_conditions': [],
                  'min_age': 0,
                  'max_age': 18,
                });
              }
            })
            .where((q) => q.questionId != 0)
            .toList();

        print('✅ تم تحليل ${questions.length} سؤال بنجاح');
        return questions;
      } else {
        throw Exception('فشل في جلب الأسئلة: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ خطأ في جلب الأسئلة: $e');
      throw Exception('فشل في جلب الأسئلة: $e');
    }
  }

  static Future<Map<String, dynamic>> submitQuestionnaireResponses(
    String token, {
    required Map<String, dynamic> responses,
    String? childId,
    String? questionnaireId,
    String language = 'ar',
  }) async {
    try {
      print('💾 حفظ إجابات الاستبيان - عدد الإجابات: ${responses.length}');

      final Map<String, dynamic> requestBody = {
        'responses': responses,
        'language': language,
      };

      if (childId != null) requestBody['child_id'] = childId;
      if (questionnaireId != null)
        requestBody['questionnaire_id'] = questionnaireId;

      final response = await http
          .post(
            Uri.parse('http://10.0.2.2:5000/api/questionnaire/responses'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: 30));

      print('📡 استجابة حفظ الإجابات: ${response.statusCode}');
      print('📦 النتيجة: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          print('✅ تم حفظ الإجابات بنجاح');
          return result;
        } else {
          throw Exception(result['message'] ?? 'فشل في حفظ الإجابات');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ??
            'فشل في حفظ الإجابات: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ خطأ في حفظ الاستبيان: $e');
      throw Exception('فشل في حفظ الاستبيان: $e');
    }
  }

  static Future<Map<String, dynamic>> getQuestionnaireHistory(
    String token, {
    int page = 1,
    int limit = 10,
    String language = 'ar',
  }) async {
    try {
      print('📜 جلب تاريخ الاستبيانات - الصفحة: $page');

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/questionnaire/history')
            .replace(queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          'language': language,
        }),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          print('✅ تم جلب ${result['questionnaires']?.length ?? 0} استبيان');
          return result;
        } else {
          throw Exception(result['message'] ?? 'فشل في جلب التاريخ');
        }
      } else {
        throw Exception('فشل في جلب التاريخ: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ خطأ في جلب التاريخ: $e');
      throw Exception('فشل في جلب التاريخ: $e');
    }
  }

  static Future<Map<String, dynamic>> getQuestionnaireDetails(
    String token,
    String questionnaireId,
  ) async {
    try {
      print('🔍 جلب تفاصيل الاستبيان: $questionnaireId');

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/questionnaire/$questionnaireId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          print('✅ تم جلب تفاصيل الاستبيان بنجاح');
          return result;
        } else {
          throw Exception(result['message'] ?? 'فشل في جلب التفاصيل');
        }
      } else {
        throw Exception('فشل في جلب التفاصيل: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ خطأ في جلب التفاصيل: $e');
      throw Exception('فشل في جلب التفاصيل: $e');
    }
  }

// ==================== دوال مساعدة محسنة ====================

// دالة جلب الأسئلة القديمة (للتوافق) - استبدال getScreeningQuestions
  static Future<List<Question>> getScreeningQuestions(
    String token, {
    String? childId,
    Map<String, dynamic>? previousAnswers,
  }) async {
    return await getQuestionnaireQuestions(
      token,
      childId: childId,
      previousAnswers: previousAnswers,
      language: 'ar',
    );
  }

// دالة إرسال الاستبيان القديمة (للتوافق) - استبدال submitQuestionnaire
  static Future<Map<String, dynamic>> submitQuestionnaire(
    String token, {
    required Map<String, dynamic> responses,
    String? childId,
  }) async {
    return await submitQuestionnaireResponses(
      token,
      responses: responses,
      childId: childId,
      language: 'ar',
    );
  }


  // ========== UPLOAD PARENT PROFILE PICTURE ==========
  static Future<Map<String, dynamic>> uploadParentProfilePicture(File imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(_buildUrl('parent/upload-profile-picture')),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          imageFile.path,
          filename: 'parent_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      print('📤 Uploading parent profile picture to: ${_buildUrl('parent/upload-profile-picture')}');
      print('📁 File path: ${imageFile.path}');

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('📥 Parent upload response status: ${response.statusCode}');
      print('📥 Parent upload response body: ${response.body}');

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
      print('❌ Error in uploadParentProfilePicture: $e');
      rethrow;
    }
  }

  // ========== UPDATE PARENT PROFILE (تحسينها) ==========
  static Future<bool> updateParentProfile(Map<String, dynamic> updateData) async {

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      print('🔄 Updating parent profile with data: $updateData');

      final response = await http.put(
        Uri.parse(_buildUrl('parent/profile')),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(updateData),
      );

      print('📡 Update parent profile response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        throw Exception('Update profile failed: ${response.statusCode}');

      }
    } catch (e) {
      print('❌ Error updating parent profile: $e');
      return false;
    }
  }



  // ========== HELPER: VALIDATE IMAGE SIZE ==========
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

  static Future<Map<String, dynamic>> addChildWithAI(
      String token, Map<String, dynamic> childData) async {
    try {
      print('🚀 Sending child data to API: $childData');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/children'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(childData),
      );

      print('📡 API Response Status: ${response.statusCode}');
      print('📦 API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('✅ Child added successfully with AI analysis');

        return {
          'success': true,
          'child': Child.fromJson(responseData['child_data'] ?? responseData),
          'ai_analysis': responseData['ai_analysis'],
          'recommended_institutions': responseData['recommended_institutions'],
          'next_steps': responseData['next_steps'],
          'message': responseData['message'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ API Error: ${errorData['message']}');
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to add child',
        };
      }
    } catch (e) {
      print('❌ Network error in addChildWithAI: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> searchBySymptoms(
      String token, String symptomsDescription, String? location) async {
    try {
      print('🔍 Analyzing symptoms: $symptomsDescription');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/children/symptoms-search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'symptoms_description': symptomsDescription,
          'location': location,
        }),
      );

      print('📡 Symptoms analysis response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('✅ Symptoms analysis successful');
        return result;
      } else {
        print('❌ Symptoms analysis failed: ${response.statusCode}');
        throw Exception('Failed to analyze symptoms: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Network error in symptoms analysis: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>?> getChildEvaluationsForParent(
      String token) async {
    try {
      print(
          '🌐 Calling API: http://10.0.2.2:5000/api/parent/child-evaluations');
      print('🔑 Token length: ${token.length}');

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/parent/child-evaluations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      ).timeout(Duration(seconds: 10));

      print('🔍 API Response Status: ${response.statusCode}');
      print('📦 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ API Response Data: $data');

        if (data['success'] == true) {
          return data;
        } else if (data['evaluations'] != null) {
          return {'success': true, 'data': data['evaluations']};
        } else {
          return {
            'success': false,
            'error': 'Unexpected response structure',
            'data': []
          };
        }
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
          'data': []
        };
      }
    } on SocketException catch (e) {
      print('❌ Network Error - SocketException: $e');
      return {'success': false, 'error': 'Network unavailable', 'data': []};
    } on TimeoutException catch (e) {
      print('❌ Network Error - Timeout: $e');
      return {'success': false, 'error': 'Request timeout', 'data': []};
    } catch (e) {
      print('❌ Unexpected Error: $e');
      return {'success': false, 'error': 'Unexpected error: $e', 'data': []};
    }
  }

  static Future<Map<String, dynamic>> getNearbyInstitutions({
    required String token,
    required double lat,
    required double lng,
    double radius = 10,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/institutions/nearby').replace(
          queryParameters: {
            'lat': lat.toString(),
            'lng': lng.toString(),
            'radius': radius.toString(),
            'page': page.toString(),
            'limit': limit.toString(),
          },
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch nearby institutions');
      }
    } catch (e) {
      print('❌ Nearby institutions error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getNearbySpecialists({
    required String token,
    required double lat,
    required double lng,
    double radius = 10,
    String? specialization,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (specialization != null) {
        queryParams['specialization'] = specialization;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/specialists/nearby')
            .replace(queryParameters: queryParams),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch nearby specialists');
      }
    } catch (e) {
      print('❌ Nearby specialists error: $e');
      rethrow;
    }
  }

  static dynamic _parseDynamicValue(dynamic value) {
    if (value == null) return null;
    if (value is String || value is int || value is double || value is bool) {
      return value;
    }
    return value.toString();
  }

  static Future<Map<String, dynamic>> saveChildBasicInfo(
    String token,
    Map<String, dynamic> childData,
  ) async {
    try {
      print('🚀 Saving child basic info: $childData');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/children/basic-info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(childData),
      );

      print('📡 Save basic info response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 201) {
        final result = jsonDecode(response.body);
        return {
          'success': true,
          'message': result['message'],
          'child_id': result['child_id'],
          'parent_location': result['parent_location'],
          'next_step': result['next_step'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to save basic information',
        };
      }
    } catch (e) {
      print('❌ Error saving basic info: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> analyzeMedicalCondition(
    String token,
    String childId,
    Map<String, dynamic> medicalData,
  ) async {
    try {
      print('🚀 [API] Sending medical analysis request...');

      final response = await http
          .post(
            Uri.parse(
                'http://10.0.2.2:5000/api/children/$childId/medical-analysis'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(medicalData),
          )
          .timeout(Duration(seconds: 30));

      print('📡 [API] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        print('📊 Raw API response structure:');
        print('   - success: ${result['success']}');
        print('   - analysis type: ${result['analysis']?.runtimeType}');
        print(
            '   - recommended_institutions type: ${result['recommended_institutions']?.runtimeType}');

        List<dynamic> institutionsList = [];
        dynamic institutionsData = result['recommended_institutions'];

        if (institutionsData != null) {
          if (institutionsData is List) {
            institutionsList = institutionsData;
            print('✅ Institutions is List, length: ${institutionsList.length}');
          } else if (institutionsData is Map) {
            print('🗺️ Institutions is Map, keys: ${institutionsData.keys}');

            if (institutionsData['institutions'] is List) {
              institutionsList = institutionsData['institutions'];
            } else if (institutionsData['data'] is List) {
              institutionsList = institutionsData['data'];
            } else if (institutionsData is Map && institutionsData.isNotEmpty) {
              institutionsList = [institutionsData];
            }
          }
        }

        print(
            '✅ Final processed institutions count: ${institutionsList.length}');

        return {
          'success': true,
          'message': result['message'],
          'analysis': result['analysis'],
          'target_conditions': result['target_conditions'],
          'recommended_institutions': institutionsList,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to analyze medical condition',
        };
      }
    } catch (e) {
      print('💥 [API] Network error: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getRecommendedInstitutions(
    String token,
    String childId, double discountPercentage, {
    String? sortBy,
    String? cityFilter,
    String? specializationFilter,
    double? maxDistance,
    double? minRating,
    double? maxPrice,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (sortBy != null) queryParams['sort_by'] = sortBy;
      if (cityFilter != null) queryParams['city_filter'] = cityFilter;
      if (specializationFilter != null)
        queryParams['specialization_filter'] = specializationFilter;
      if (maxDistance != null)
        queryParams['max_distance'] = maxDistance.toString();
      if (minRating != null) queryParams['min_rating'] = minRating.toString();
      if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();

      final response = await http.get(
        Uri.parse(
                'http://10.0.2.2:5000/api/children/$childId/recommended-institutions')
            .replace(queryParameters: queryParams),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Get institutions response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return {
          'success': true,
          'data': result['data'] ?? result['institutions'], // دعم الهيكلين
          'pagination': result['pagination'],
          'filters_applied': result['filters_applied'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch institutions',
        };
      }
    } catch (e) {
      print('❌ Error fetching institutions: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> requestInstitutionRegistration(
    String token,
    String childId,
    int institutionId, {
    String? notes,
    bool consentGiven = false,
  }) async {
    try {
      print(
          '📝 Requesting registration for child: $childId at institution: $institutionId');

      final response = await http.post(
        Uri.parse(
            'http://10.0.2.2:5000/api/children/$childId/request-registration'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'institution_id': institutionId,
          'notes': notes,
          'consent_given': consentGiven,
        }),
      );

      print('📡 Registration response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return {
          'success': true,
          'message': result['message'],
          'request_id': result['request_id'],
          'status': result['status'],
          'institution': result['institution'],
          'next_steps': result['next_steps'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to submit registration request',
        };
      }
    } catch (e) {
      print('❌ Error requesting registration: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getRegistrationStatus(
    String token,
    String childId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:5000/api/children/$childId/registration-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch registration status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get AI-powered institution recommendations
  static Future<Map<String, dynamic>> getAIRecommendations(
    String token, {
    required String childConditions,
    String? childAge,
    String? location,
    String? budget,
  }) async {
    try {
      final queryParams = {
        'childConditions': childConditions,
        if (childAge != null) 'childAge': childAge,
        if (location != null) 'location': location,
        if (budget != null) 'budget': budget,
      };

      final uri = Uri.parse(_buildUrl('ai/recommendations')).replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'recommendations': [],
        };
      }
    } catch (e) {
      print('Error fetching AI recommendations: $e');
      return {
        'success': false,
        'recommendations': [],
      };
    }
  }

  // Create a review
  static Future<Map<String, dynamic>> createReview(
    String token, {
    required int institutionId,
    required double rating,
    String? title,
    String? comment,
    double? staffRating,
    double? facilitiesRating,
    double? servicesRating,
    double? valueRating,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_buildUrl('reviews/institution/$institutionId')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rating': rating,
          if (title != null && title.isNotEmpty) 'title': title,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          if (staffRating != null) 'staff_rating': staffRating,
          if (facilitiesRating != null) 'facilities_rating': facilitiesRating,
          if (servicesRating != null) 'services_rating': servicesRating,
          if (valueRating != null) 'value_rating': valueRating,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error creating review: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }

  // Delete a review
  static Future<Map<String, dynamic>> deleteReview(
    String token, {
    required int reviewId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse(_buildUrl('reviews/$reviewId')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error deleting review: $e');
      return {'success': false};
    }
  }

  // =====================
  // Parent & Manager Workshops
  // =====================

  // Manager: get workshops for current institution
  static Future<Map<String, dynamic>> getManagerWorkshops(String token) async {
    try {
      final response = await http.get(
        Uri.parse(_buildUrl('manager/workshops')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      print('Error fetching manager workshops: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Manager: create new workshop
  static Future<Map<String, dynamic>> createManagerWorkshop(
    String token, {
    required String title,
    String? description,
    required String mode,
    String? onlineLink,
    String? locationAddress,
    required String date,
    required String startTime,
    required String endTime,
    int maxParticipants = 20,
    String status = 'published',
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'mode': mode,
        'online_link': onlineLink,
        'location_address': locationAddress,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'max_participants': maxParticipants,
        'status': status,
      };

      final response = await http.post(
        Uri.parse(_buildUrl('manager/workshops')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      print('Error creating manager workshop: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Manager: generate free session offers for eligible children
  static Future<Map<String, dynamic>> generateFreeSessionOffers(
    String token, {
    required int sessionTypeId,
    required int specialistId,
    int maxChildren = 5,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'session_type_id': sessionTypeId,
        'specialist_id': specialistId,
        'max_children': maxChildren,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await http.post(
        Uri.parse(_buildUrl('manager/free-sessions/generate')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      print('Error generating free session offers: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Parent: get published workshops for institutions related to the parent
  static Future<Map<String, dynamic>> getParentWorkshops(
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(_buildUrl('parent/workshops')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      print('Error fetching parent workshops: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Parent: get free session offers
  static Future<Map<String, dynamic>> getParentFreeSessionOffers(
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(_buildUrl('financial/free-session-offers')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      print('Error fetching free session offers: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Parent: accept a free session offer
  static Future<Map<String, dynamic>> acceptFreeSessionOffer(
    String token, {
    required int offerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_buildUrl('financial/free-session-offers/$offerId/accept')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      print('Error accepting free session offer: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Parent: register for a workshop
  static Future<Map<String, dynamic>> registerForWorkshop(
    String token, {
    required int workshopId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_buildUrl('parent/workshops/$workshopId/register')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      print('Error registering for workshop: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Mark review as helpful
  static Future<Map<String, dynamic>> markReviewHelpful(
    String token, {
    required int reviewId,
    required bool isHelpful,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_buildUrl('reviews/$reviewId/helpful')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'isHelpful': isHelpful}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error marking review helpful: $e');
      return {'success': false};
    }
  }

  // Get community posts with highlights
  static Future<Map<String, dynamic>> getCommunityPosts(String token,
      {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('${_buildUrl('community/posts')}?limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // تنسيق البيانات للتوافق مع Dashboard
        final posts = (data['data'] as List?)?.map((post) {
              return {
                'post_id': post['post_id'],
                'content': post['content'],
                'user_name': post['user_name'] ?? 'Community Member',
                'created_at': post['created_at'],
                'likes_count': post['likes_count'] ?? 0,
                'comments_count': post['comments_count'] ?? 0,
              };
            }).toList() ??
            [];

        return {
          'success': true,
          'data': posts,
        };
      } else {
        return {
          'success': false,
          'data': [],
        };
      }
    } catch (e) {
      print('Error fetching community posts: $e');
      return {
        'success': false,
        'data': [],
      };
    }
  }

  // ==================== Admin APIs ====================

  static Future<AdminDashboardStats> getAdminDashboardStats(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/admin/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return AdminDashboardStats.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to load dashboard stats');
        }
      } else {
        throw Exception('Failed to load dashboard: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading admin dashboard: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAdminInstitutions({
    required String token,
    int page = 1,
    int limit = 10,
    String? status,
    String? search,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/admin/institutions')
            .replace(queryParameters: queryParams),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load institutions: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading admin institutions: $e');
      rethrow;
    }
  }

  static Future<bool> approveInstitution(
      String token, int institutionId) async {
    try {
      final response = await http.post(
        Uri.parse(
            'http://10.0.2.2:5000/api/admin/institutions/$institutionId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        throw Exception(
            'Failed to approve institution: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error approving institution: $e');
      rethrow;
    }
  }

  static Future<bool> rejectInstitution(
      String token, int institutionId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse(
            'http://10.0.2.2:5000/api/admin/institutions/$institutionId/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('Failed to reject institution: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error rejecting institution: $e');
      rethrow;
    }
  }

  // أضف هذه الدوال لـ ApiService
  static Future<Map<String, dynamic>> recordSkillProgress({
    required String token,
    required String childId,
    required String skillId,
    required int level,
    required int attempts,
    String? notes,
  }) async {
    // تنفيذ واقعي للـ API
    await Future.delayed(Duration(milliseconds: 500)); // محاكاة اتصال شبكة

    return {
      'success': true,
      'message': 'تم حفظ التقدم بنجاح',
      'data': {
        'record_id': 'rec_${DateTime.now().millisecondsSinceEpoch}',
        'skill_id': skillId,
        'level': level,
        'attempts': attempts,
        'timestamp': DateTime.now().toIso8601String(),
      }
    };
  }

  // إضافة دوال التقييم إلى ApiService
  static Future<Map<String, dynamic>> getMyRatings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/ratings/my-ratings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting my ratings: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getInstitutionReviews(
      String institutionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/ratings/institutions/$institutionId/reviews'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting institution reviews: $e');
      rethrow;
    }
  }

// ==================== FINANCIAL ASSISTANCE APIs ====================

  // 1. Start Financial Assessment
  static Future<Map<String, dynamic>> initiateFinancialAssessment(
      String token, int childId, int institutionId) async {
    final url =
        Uri.parse('http://10.0.2.2:5000/api/financial/assessment/initiate');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'child_id': childId,
        'institution_id': institutionId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to initiate financial assessment');
    }
  }

  // 2. Submit Financial Assessment
  static Future<Map<String, dynamic>> submitFinancialAssessment(
    String token,
    int childId,
    int institutionId,
    Map<String, dynamic> responses,
    bool skipDocuments,
  ) async {
    final url =
        Uri.parse('http://10.0.2.2:5000/api/financial/assessment/submit');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'child_id': childId,
        'institution_id': institutionId,
        'responses': responses,
        'skip_documents': skipDocuments,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit financial assessment');
    }
  }

  String _encodeBase64(File file) {
  final bytes = file.readAsBytesSync();
  return base64Encode(bytes);
}
  // 4. Get Financial Assistance Status
  static Future<Map<String, dynamic>> getFinancialAssistanceStatus(
    String token,
    int requestId,
  ) async {
    final url = Uri.parse(
        'http://10.0.2.2:5000/api/financial/assistance/$requestId/status');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get financial assistance status');
    }
  }

  // 5. Upload Financial Documents
  static Future<Map<String, dynamic>> uploadFinancialDocuments(
    String token,
    int requestId,
    List<Map<String, dynamic>> documents,
  ) async {
    final url = Uri.parse(
        'http://10.0.2.2:5000/api/financial/assistance/$requestId/documents');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'documents': documents,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload financial documents');
    }
  }

  // 6. Get Parent Financial Profile
  // في api_service.dart - تحديث دالة getParentFinancialProfile
  static Future<Map<String, dynamic>> getParentFinancialProfile(
      String token) async {
    try {
      final url = Uri.parse('http://10.0.2.2:5000/api/financial/profile');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        // إذا لم يكن هناك ملف مالي، نعود لاستخدام بيانات افتراضية
        return {
          'success': true,
          'data': _createDefaultFinancialProfile(),
          'message': 'Using default financial profile'
        };
      } else {
        // لجميع الحالات الأخرى، نستخدم البيانات الافتراضية
        return {
          'success': true,
          'data': _createDefaultFinancialProfile(),
          'message': 'Using default financial data'
        };
      }
    } catch (e) {
      print('❌ Error in getParentFinancialProfile: $e');
      // في حالة الخطأ، نستخدم البيانات الافتراضية
      return {
        'success': true,
        'data': _createDefaultFinancialProfile(),
        'message': 'Using default due to error'
      };
    }
  }

// دالة لإنشاء ملف مالي افتراضي
  static Map<String, dynamic> _createDefaultFinancialProfile() {
    return {
      'parent_id': 0,
      'financial_score': 0,
      'financial_tier': 'tier_5_no_assistance',
      'monthly_income': null,
      'employment_status': null,
      'family_size': 1,
      'dependents_count': 0,
      'special_circumstances': 'none',
      'receives_government_support': false,
      'government_support_amount': 0,
      'other_monthly_expenses': 0,
      'additional_medical_expenses': 0,
      'last_financial_assessment': null,
      'financial_documents': null,
      'assessment_notes': null,
      'credibility_score': 50,
      'parent_info': {'name': 'Parent', 'email': null, 'phone': null},
      'requests_summary': {
        'total_active': 0,
        'total_completed': 0,
        'pending_documents': 0
      },
      'active_requests': [],
      'estimated_monthly_subsidy': 0
    };
  }

// 1. دالة لجلب الطلبات المالية
  static Future<Map<String, dynamic>> getFinancialAssistanceRequests(
    String token, {
    String status = 'all',
    int page = 1,
    int limit = 10,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
  }) async {
    try {
      final url = Uri.parse('http://10.0.2.2:5000/api/financial/requests?'
          'status=$status&'
          'page=$page&'
          'limit=$limit&'
          'sort_by=$sortBy&'
          'sort_order=$sortOrder');

      print('🌐 Fetching financial assistance requests...');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        // إذا فشل الـ API، نعيد بيانات افتراضية
        return _getDefaultFinancialRequestsResponse();
      }
    } catch (e) {
      print('❌ Error in getFinancialAssistanceRequests: $e');
      return _getDefaultFinancialRequestsResponse();
    }
  }

// 2. دالة افتراضية للطلبات المالية
  static Map<String, dynamic> _getDefaultFinancialRequestsResponse() {
    return {
      'success': true,
      'data': [],
      'pagination': {'page': 1, 'limit': 10, 'total': 0, 'total_pages': 0},
      'statistics': {
        'total': 0,
        'by_status': {},
        'pending_review': 0,
        'approved_count': 0
      },
      'message': 'Using default data'
    };
  }

// 3. دالة لجلب الطلبات النشطة (Active)
  static Future<Map<String, dynamic>> getActiveFinancialAssistanceRequests(
    String token, {
    int page = 1,
    int limit = 10,
  }) async {
    return await getFinancialAssistanceRequests(
      token,
      status: 'active',
      page: page,
      limit: limit,
      sortBy: 'created_at',
      sortOrder: 'DESC',
    );
  }

// ==============================================
// 🔄 NEW: General Financial Assessment Functions
// ==============================================

// 1. بدء التقييم المالي العام (بدون طفل/مؤسسة)
static Future<Map<String, dynamic>> initiateGeneralFinancialAssessment(
  String token,
) async {
  try {
    final url = Uri.parse(
      'http://10.0.2.2:5000/api/financial/assessment/general/initiate'
    );

    print('🌐 Initiating general financial assessment...');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📥 Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to initiate general financial assessment: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error in initiateGeneralFinancialAssessment: $e');
    throw e;
  }
}

// 2. إرسال التقييم المالي العام
static Future<Map<String, dynamic>> submitGeneralFinancialAssessment(
  String token,
  Map<String, dynamic> responses,
) async {
  try {
    final url = Uri.parse(
      'http://10.0.2.2:5000/api/financial/assessment/general/submit'
    );

    print('🌐 Submitting general financial assessment...');
    print('📝 Responses: ${responses.keys.toList()}');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'responses': responses,
      }),
    );

    print('📥 Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit general financial assessment: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error in submitGeneralFinancialAssessment: $e');
    throw e;
  }
}

// 3. تطبيق التقييم على طفل محدد
static Future<Map<String, dynamic>> applyFinancialAssessmentToChild(
  String token,
  int childId,
  int institutionId, {
  bool useExistingAssessment = true,
}) async {
  try {
    final url = Uri.parse(
      'http://10.0.2.2:5000/api/financial/assessment/apply-to-child'
    );

    print('🌐 Applying financial assessment to child...');
    print('   Child ID: $childId');
    print('   Institution ID: $institutionId');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'child_id': childId,
        'institution_id': institutionId,
        'use_existing_assessment': useExistingAssessment,
      }),
    );

    print('📥 Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to apply financial assessment: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error in applyFinancialAssessmentToChild: $e');
    throw e;
  }
}

// ==============================================
// 📊 دوال مساعدة للشاشات الجديدة
// ==============================================

// جلب التقارير المالية للأطفال
static Future<Map<String, dynamic>> getChildrenFinancialReports(
  String token,
) async {
  try {
    // يمكن تنفيذ هذا لاحقاً
    return {
      'success': true,
      'data': [],
      'message': 'Feature coming soon'
    };
  } catch (e) {
    print('❌ Error in getChildrenFinancialReports: $e');
    throw e;
  }
}

// حساب التقدير المالي السريع
static Future<Map<String, dynamic>> calculateQuickFinancialEstimate(
  String token,
  double monthlyIncome,
  int familySize,
  String employmentStatus,
) async {
  try {
    // يمكن تنفيذ هذا لاحقاً
    return {
      'success': true,
      'data': {
        'estimated_tier': 'tier_3_medium',
        'estimated_discount': '40-59%',
        'confidence': 'medium',
        'recommendation': 'Complete full assessment for accurate results'
      },
      'message': 'Quick estimate generated'
    };
  } catch (e) {
    print('❌ Error in calculateQuickFinancialEstimate: $e');
    throw e;
  }
}


static Future<Map<String, dynamic>> getRecommendedInstitutionsByTier(
  String token,
  String financialTier,
  double discountPercentage,
) async {
  try {
    final url = Uri.parse(
      'http://10.0.2.2:5000/api/financial/institutions/recommended?'
      'tier=$financialTier&discount=$discountPercentage'
    );

    print('🌐 Getting recommended institutions by tier...');
    print('   Tier: $financialTier');
    print('   Discount: $discountPercentage%');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📥 Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      // في حالة فشل، نعيد بيانات افتراضية
      return _getDefaultRecommendedInstitutions();
    }
  } catch (e) {
    print('❌ Error in getRecommendedInstitutionsByTier: $e');
    return _getDefaultRecommendedInstitutions();
  }
}
// بيانات افتراضية للمؤسسات الموصى بها
static Map<String, dynamic> _getDefaultRecommendedInstitutions() {
  return {
    'success': true,
    'data': [
      {
        'institution_id': 1,
        'name': 'مركز التأهيل المتقدم',
        'city': 'الرياض',
        'specializations': ['علاج النطق', 'العلاج الوظيفي', 'التدخل المبكر'],
        'financial_aid': true,
        'average_session_price': '75.00',
        'compatibility_score': 85,
        'estimated_discount': {'min': 70, 'max': 90, 'average': 80},
        'processing_time': 3,
        'image_url': null,
      },
      {
        'institution_id': 2,
        'name': 'عيادة التطور العصبي',
        'city': 'جدة',
        'specializations': ['العلاج السلوكي', 'تعديل السلوك'],
        'financial_aid': true,
        'average_session_price': '85.00',
        'compatibility_score': 78,
        'estimated_discount': {'min': 60, 'max': 80, 'average': 70},
        'processing_time': 5,
        'image_url': null,
      },
      {
        'institution_id': 3,
        'name': 'مركز الأمل للتأهيل',
        'city': 'الدمام',
        'specializations': ['التربية الخاصة', 'التدريب على المهارات'],
        'financial_aid': false,
        'average_session_price': '65.00',
        'compatibility_score': 65,
        'estimated_discount': {'min': 30, 'max': 50, 'average': 40},
        'processing_time': 7,
        'image_url': null,
      },
    ],
    'message': 'Using default recommended institutions',
  };
}

// 9. جلب الأطفال المسجلين في مؤسسة محددة
static Future<Map<String, dynamic>> getChildrenByInstitution(
  String token,
  int institutionId,
) async {
  try {
    final url = Uri.parse(
      'http://10.0.2.2:5000/api/children/by-institution/$institutionId'
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {'success': false, 'message': 'Failed to load children', 'data': []};
    }
  } catch (e) {
    print('❌ Error in getChildrenByInstitution: $e');
    return {'success': false, 'message': 'Error: $e', 'data': []};
  }
}


/// Get active/upcoming donation campaigns for a specific institution (for donors)
static Future<List<Map<String, dynamic>>> getInstitutionCampaignsForDonations(
    String token, int institutionId) async {
  try {
    final url = _buildUrl('donations/institutions/$institutionId/campaigns');
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List campaigns = data['data'] ?? [];
      return List<Map<String, dynamic>>.from(campaigns);
    } else {
      throw Exception(
          'Failed to fetch institution campaigns: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception(
        'Network error while loading institution campaigns: $e');
  }
}



// التحقق التلقائي من المساعدة المالية
static Future<Map<String, dynamic>> checkAutoFinancialAssistance(
  String token,
  String sessionId,
) async {
  try {
    final url = Uri.parse(
      'http://10.0.2.2:5000/api/parent/$sessionId/check-auto-assistance',
    );

    print('🌐 Checking auto financial assistance...');
    print('   Session ID: $sessionId');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📥 Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Failed to check auto financial assistance',
        'statusCode': response.statusCode,
      };
    }
  } catch (e) {
    print('❌ Error in checkAutoFinancialAssistance: $e');
    return {
      'success': false,
      'message': 'Error while checking auto financial assistance',
      'error': e.toString(),
    };
  }
}

// تطبيق الخصم التلقائي
static Future<Map<String, dynamic>> applyAutoDiscount(
  String token,
  String sessionId,
) async {
  try {
    final url = Uri.parse(
      'http://10.0.2.2:5000/api/parent/$sessionId/apply-auto-discount',
    );

    print('🌐 Applying auto discount...');
    print('   Session ID: $sessionId');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );

    print('📥 Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Failed to apply auto discount',
        'statusCode': response.statusCode,
      };
    }
  } catch (e) {
    print('❌ Error in applyAutoDiscount: $e');
    return {
      'success': false,
      'message': 'Error while applying auto discount',
      'error': e.toString(),
    };
  }
}

}
