import 'dart:convert';
import 'dart:io'; 
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../models/session.dart';
import '../models/questionnaire_model.dart';



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
      ).timeout(const Duration(seconds: 15)); // ⚠️ إضافة timeout
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load dashboard data: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      print('⚠️ Dashboard API timeout after 15 seconds');
      throw Exception('Request timeout - Please check your connection');
    } catch (e) {
      print('❌ Dashboard API error: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> getUpcomingSessions(String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/parent/upcoming-sessions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return List<dynamic>.from(data['sessions'] ?? []);
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
      ).timeout(const Duration(seconds: 15));

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



  static Future<bool> cancelSession(String token, String sessionId) async {
    try {
      final response = await http.patch(
        Uri.parse('http://10.0.2.2:5000/api/parent/sessions/$sessionId/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to cancel session');
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/parent/completed-sessions'),
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

  static Future<List<Session>> getChildSessions(String token, String childId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/parent/child-sessions/$childId'),
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

      await Future.delayed(const Duration(seconds: 2));

      print('✅ MOCK: Rating submitted successfully for session $sessionId');
      print('✅ Rating: $rating/5, Review: ${review ?? "No review"}');

      return true;

      // // الكود الأصلي - علقوه لوقت ما الـ API يجهز
      // final response = await http.post(
      //   Uri.parse('$baseUrl/sessions/$sessionId/rate'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      //   body: json.encode({
      //     'rating': rating,
      //     'review': review ?? '',
      //   }),
      // );
      //
      // if (response.statusCode == 200 || response.statusCode == 201) {
      //   return true;
      // } else {
      //   throw Exception('Failed to rate session: ${response.statusCode}');
      // }
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


  static Future<List<Question>> getScreeningQuestions(
      String token, {
        String? childId,
        Map<String, dynamic>? previousAnswers,
      }) async {
    try {
      final Map<String, String> queryParams = {};
      if (childId != null) queryParams['child_id'] = childId;
      if (previousAnswers != null) {
        queryParams['previous_answers'] = jsonEncode(previousAnswers);
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/questionnaire/questions')
            .replace(queryParameters: queryParams),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == false) {
          throw Exception('API Error: ${data['message']}');
        }

        final questions = (data['questions'] as List)
            .map((q) {
          try {
            return Question.fromJson(q);
          } catch (e) {
            print('❌ Error parsing question: $e');
            print('❌ Question data: $q');
            return Question.fromJson({
              'question_id': 0,
              'category': 'General',
              'question_text': 'سؤال غير متوفر',
              'question_type': 'Multiple Choice',
              'options': ['نعم', 'لا'],
              'weight': 1.0,
              'target_conditions': [],
              'min_age': 0,
              'max_age': 18,
            });
          }
        })
            .where((q) => q.questionId != 0) // إزالة الأسئلة الفاشلة
            .toList();

        print('✅ Successfully parsed ${questions.length} questions');
        return questions;
      } else {
        throw Exception('Failed to load questions: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getScreeningQuestions: $e');
      throw Exception('Failed to load questions: $e');
    }
  }

  static Future<Map<String, dynamic>> submitQuestionnaire(
      String token, {
        required Map<String, dynamic> responses,
        String? childId,
      }) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/questionnaire/responses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'responses': responses,
          'child_id': childId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to submit questionnaire: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in submitQuestionnaire: $e');
      throw Exception('Failed to submit questionnaire: $e');
    }
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



  
}
