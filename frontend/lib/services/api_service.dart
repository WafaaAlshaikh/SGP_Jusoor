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

  static String _buildUrl(String endpoint) {
    if (kIsWeb) {
      return 'http://localhost:5000/api/$endpoint';
    } else {
      return 'http://10.0.2.2:5000/api/$endpoint';
    }
  }





  static Future<Map<String, dynamic>> signupInitial(Map<String, dynamic> data) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚀 [API SERVICE] PREPARING DATA TO SEND');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📦 Original data received:');
      print('   Keys: ${data.keys.toList()}');
      print('   location_lat exists: ${data.containsKey('location_lat')}');
      print('   location_lng exists: ${data.containsKey('location_lng')}');

      Map<String, dynamic> requestData = {
        'full_name': data['full_name'],
        'email': data['email'],
        'password': data['password'],
        'role': data['role'],
        'phone': data['phone'],
        'profile_picture': data['profile_picture'],

        'location_lat': data['location_lat'],
        'location_lng': data['location_lng'],
        'location_address': data['location_address'],
        'city': data['city'],
        'region': data['region'],
      };

      if (data['role'] == 'Parent') {
        requestData['address'] = data['address'];
        requestData['occupation'] = data['occupation'];
      } else if (data['role'] == 'Specialist') {
        requestData['specialization'] = data['specialization'];
        requestData['years_experience'] = data['years_experience'];
        requestData['institution_id'] = data['institution_id'];
      } else if (data['role'] == 'Manager') {
        requestData['institution_id'] = data['institution_id'];
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 REQUEST BODY TO BE SENT:');
      print('   location_lat: ${requestData['location_lat']}');
      print('   location_lng: ${requestData['location_lng']}');
      print('   location_address: ${requestData['location_address']}');
      print('   city: ${requestData['city']}');
      print('   region: ${requestData['region']}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 30));

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

  static Future<Map<String, dynamic>> verifySignup(String tempToken, String otp) async {
    try {
      print('🔐 Verifying OTP with token: $tempToken');

      final response = await http.post(
        Uri.parse('$baseUrl/verify-signup'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tempToken',
        },
        body: jsonEncode({'otp': otp}),
      ).timeout(Duration(seconds: 30));

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

  static Future<Map<String, dynamic>> login(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> sendResetCode(String email) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:5000/api/password/send-reset-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verifyResetCode(String email, String code) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:5000/api/password/verify-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> resetPassword( String email, String code, String newPassword) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/password/reset-password'); // الرابط الصحيح
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
        throw Exception('Failed to load dashboard data: ${response.statusCode}');
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
        throw Exception('Failed to load upcoming sessions: ${response.statusCode}');
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
        'tip': 'Spend quality time with your child today—every moment together builds a stronger future.',
        'aiGenerated': false,
        'isGeneric': true
      };
    } catch (e) {
      print('❌ Error fetching daily tip: $e');
      return {
        'success': true,
        'tip': 'Spend quality time with your child today—every moment together builds a stronger future.',
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
        'tips': ['Spend quality time together', 'Create routines', 'Celebrate progress']
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
        Uri.parse('http://10.0.2.2:5000/api/diagnoses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Diagnoses response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else if (response.statusCode == 404) {
        print('⚠️ Diagnoses endpoint not found, using default list');
        return _getDefaultDiagnoses();
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
      {'diagnosis_id': 1, 'name': 'Autism Spectrum Disorder (ASD)'},
      {'diagnosis_id': 2, 'name': 'Attention Deficit Hyperactivity Disorder (ADHD)'},
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
      throw Exception('Failed to fetch child statistics: ${response.statusCode}');
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
        Uri.parse('http://10.0.2.2:5000/api/parent/sessions/$sessionId/confirm'),
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



  static Future<Map<String, dynamic>> cancelSession(String token, String sessionId, {String? reason}) async {
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

  static Future<List<Map<String, dynamic>>> getInstitutions(String token) async {
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
        if (gender != null && gender.isNotEmpty && gender != 'All') 'gender': gender,
        if (diagnosis != null && diagnosis.isNotEmpty && diagnosis != 'All') 'diagnosis': diagnosis,
        if (registrationStatus != null && registrationStatus.isNotEmpty && registrationStatus != 'All') 'registration_status': registrationStatus,
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
      throw Exception('Failed to fetch children: ${response.statusCode} - ${response.body}');
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

  static Future<List<Session>> getChildSessions(String token, String childId) async {
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
      String token,
      String sessionId,
      double rating,
      String? review
      ) async {
    try {
      print('⭐ Rating session $sessionId with rating: $rating, review: $review');

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
        throw Exception(error['message'] ?? 'Failed to rate session: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Rating API Error: $e');
      throw e;
    }
  }

  static Future<Map<String, dynamic>> getSessionDetails(String token, String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions/$sessionId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load session details: ${response.statusCode}');
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

      final formattedDate = "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";

      final response = await http.patch(
        Uri.parse('http://10.0.2.2:5000/api/parent/sessions/$sessionId/reschedule'),
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
      if (questionnaireId != null) requestBody['questionnaire_id'] = questionnaireId;

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/questionnaire/responses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 30));

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
        throw Exception(errorData['message'] ?? 'فشل في حفظ الإجابات: ${response.statusCode}');
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







  static Future<bool> updateParentProfile(Map<String, dynamic> updateData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.put(
        Uri.parse('http://10.0.2.2:5000/api/parent/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        print('Update profile failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  static Future<String?> uploadProfileImage(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:5000/api/upload/profile-image'), // تأكد من هذا الراوت
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imagePath,
      ));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);
        return jsonResponse['imageUrl'];
      } else {
        print('Image upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }




  static Future<Map<String, dynamic>> addChildWithAI(
      String token,
      Map<String, dynamic> childData
      ) async {
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
      String token,
      String symptomsDescription,
      String? location
      ) async {
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

  static Future<Map<String, dynamic>?> getChildEvaluationsForParent(String token) async {
    try {
      print('🌐 Calling API: http://10.0.2.2:5000/api/parent/child-evaluations');
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
          return {
            'success': true,
            'data': data['evaluations']
          };
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
      return {
        'success': false,
        'error': 'Network unavailable',
        'data': []
      };
    } on TimeoutException catch (e) {
      print('❌ Network Error - Timeout: $e');
      return {
        'success': false,
        'error': 'Request timeout',
        'data': []
      };
    } catch (e) {
      print('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Unexpected error: $e',
        'data': []
      };
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

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/children/$childId/medical-analysis'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(medicalData),
      ).timeout(Duration(seconds: 30));

      print('📡 [API] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        print('📊 Raw API response structure:');
        print('   - success: ${result['success']}');
        print('   - analysis type: ${result['analysis']?.runtimeType}');
        print('   - recommended_institutions type: ${result['recommended_institutions']?.runtimeType}');

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

        print('✅ Final processed institutions count: ${institutionsList.length}');

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
          'message': errorData['message'] ?? 'Failed to analyze medical condition',
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
      String childId, {
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
      if (specializationFilter != null) queryParams['specialization_filter'] = specializationFilter;
      if (maxDistance != null) queryParams['max_distance'] = maxDistance.toString();
      if (minRating != null) queryParams['min_rating'] = minRating.toString();
      if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/children/$childId/recommended-institutions')
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
      print('📝 Requesting registration for child: $childId at institution: $institutionId');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/children/$childId/request-registration'),
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
          'message': errorData['message'] ?? 'Failed to submit registration request',
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
        Uri.parse('http://10.0.2.2:5000/api/children/$childId/registration-status'),
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

  // Get reviews for an institution
  static Future<Map<String, dynamic>> getInstitutionReviews(
    String token, {
    required int institutionId,
    String sort = 'recent',
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${_buildUrl('reviews/institution/$institutionId')}?sort=$sort&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'reviews': []};
      }
    } catch (e) {
      print('Error fetching reviews: $e');
      return {'success': false, 'reviews': []};
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
  static Future<Map<String, dynamic>> getCommunityPosts(String token, {int limit = 10}) async {
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
        }).toList() ?? [];
        
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

  static Future<AdminDashboardStats> getAdminDashboardStats(String token) async {
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

  static Future<bool> approveInstitution(String token, int institutionId) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/admin/institutions/$institutionId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('Failed to approve institution: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error approving institution: $e');
      rethrow;
    }
  }

  static Future<bool> rejectInstitution(String token, int institutionId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/admin/institutions/$institutionId/reject'),
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
}
