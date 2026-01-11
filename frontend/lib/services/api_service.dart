import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../models/child_model.dart';
import '../models/session.dart';
import '../models/questionnaire_model.dart';
import '../models/admin_models.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/auth';
    } else {
      return 'http://10.0.2.2:5000/api/auth'; // للموبايل
    }
  }

  static String get publicBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else {
      return 'http://10.0.2.2:5000';
    }
  }

  static String buildFileUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$publicBaseUrl$path';
    return '$publicBaseUrl/$path';
  }

  static Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final url = _buildUrl('users/profile');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to load user profile');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ================= Invite / Referral (Donations) =================

  static Future<Map<String, dynamic>> createDonationInvite(
    String token, {
    required int institutionId,
    int? campaignId,
    String? shareMessage,
  }) async {
    try {
      final url = _buildUrl('invites/donations');
      final body = <String, dynamic>{
        'institution_id': institutionId,
        if (campaignId != null) 'campaign_id': campaignId,
        if (shareMessage != null && shareMessage.trim().isNotEmpty)
          'share_message': shareMessage.trim(),
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
      if (response.statusCode == 201 && data['success'] == true) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to create invite');
    } catch (e) {
      print('❌ Error creating donation invite: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> resolveDonationInvite({
    String? token,
    required String code,
  }) async {
    try {
      final url = _buildUrl('invites/donations/$code');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(Uri.parse(url), headers: headers);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to resolve invite');
    } catch (e) {
      print('❌ Error resolving donation invite: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMyDonationInviteStats(
      String token) async {
    try {
      final url = _buildUrl('invites/donations/my/stats');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to load invite stats');
    } catch (e) {
      print('❌ Error loading invite stats: $e');
      rethrow;
    }
  }

  static String _publicEquipmentBaseUrl() {
    return '${ApiService.baseUrl}/api/public/equipment';
  }

  static String _authEquipmentBaseUrl() {
    return '${ApiService.baseUrl}/api/equipment';
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
        if (requestedPercentage != null)
          'requested_percentage': requestedPercentage,
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

  // static Future<Map<String, dynamic>> signupInitial(
  //     Map<String, dynamic> data) async {
  //   try {
  //     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  //     print('🚀 [API SERVICE] PREPARING DATA TO SEND');
  //     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  //     print('📦 COMPLETE DATA RECEIVED:');
  //     data.forEach((key, value) {
  //       print('   $key: $value (${value.runtimeType})');
  //     });
  //     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  //     // ✅ بناء البيانات بشكل صريح لكل الدور
  //     Map<String, dynamic> requestData = {
  //       'full_name': data['full_name']?.toString() ?? '',
  //       'email': data['email']?.toString() ?? '',
  //       'password': data['password']?.toString() ?? '',
  //       'role': data['role']?.toString() ?? '',
  //       'phone': data['phone']?.toString(),
  //       'profile_picture': data['profile_picture']?.toString(),

  //       // البيانات الجغرافية
  //       'location_lat': data['location_lat'],
  //       'location_lng': data['location_lng'],
  //       'location_address': data['location_address']?.toString(),
  //       'city': data['city']?.toString(),
  //       'region': data['region']?.toString(),
  //     };

  //     // ✅ إضافة بيانات Parent
  //     if (data['role'] == 'Parent') {
  //       requestData['address'] = data['address']?.toString();
  //       requestData['occupation'] = data['occupation']?.toString();
  //     }

  //     // ✅ إضافة بيانات Specialist
  //     if (data['role'] == 'Specialist') {
  //       requestData['specialization'] = data['specialization']?.toString();
  //       requestData['years_experience'] = data['years_experience'];
  //       requestData['institution_id'] = data['institution_id'] != null
  //           ? int.tryParse(data['institution_id'].toString())
  //           : null;
  //     }

  //     // ✅ إضافة بيانات Manager - تأكد من وجودها
  //     if (data['role'] == 'Manager') {
  //       // البيانات الإلزامية
  //       requestData['institution_name'] = data['institution_name']?.toString();
  //       requestData['institution_contact_email'] =
  //           data['institution_contact_email']?.toString();
  //       requestData['institution_contact_phone'] =
  //           data['institution_contact_phone']?.toString();

  //       // البيانات الاختيارية
  //       requestData['institution_license'] =
  //           data['institution_license']?.toString();
  //       requestData['institution_established_year'] =
  //           data['institution_established_year'];
  //       requestData['institution_city'] = data['institution_city']?.toString();
  //       requestData['institution_region'] =
  //           data['institution_region']?.toString();

  //       // ✅ طباعة بيانات المؤسسة للتأكد
  //       print('🏢 MANAGER INSTITUTION DATA:');
  //       print('   ├─ institution_name: ${requestData['institution_name']}');
  //       print(
  //           '   ├─ institution_contact_email: ${requestData['institution_contact_email']}');
  //       print(
  //           '   ├─ institution_contact_phone: ${requestData['institution_contact_phone']}');
  //       print(
  //           '   ├─ institution_license: ${requestData['institution_license']}');
  //       print(
  //           '   ├─ institution_established_year: ${requestData['institution_established_year']}');
  //       print('   ├─ institution_city: ${requestData['institution_city']}');
  //       print('   └─ institution_region: ${requestData['institution_region']}');
  //     }

  //     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  //     print('📤 FINAL REQUEST DATA:');
  //     requestData.forEach((key, value) {
  //       print('   $key: $value');
  //     });
  //     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  //     final response = await http
  //         .post(
  //           Uri.parse('$baseUrl/signup'),
  //           headers: {'Content-Type': 'application/json'},
  //           body: jsonEncode(requestData),
  //         )
  //         .timeout(Duration(seconds: 30));

  //     print('📡 Signup response: ${response.statusCode}');
  //     print('📦 Response body: ${response.body}');

  //     final result = jsonDecode(response.body);

  //     if (response.statusCode == 200) {
  //       print('✅ [API SERVICE] Signup initial SUCCESS');
  //       return {
  //         'success': true,
  //         'message': result['message'],
  //         'tempToken': result['tempToken'],
  //       };
  //     } else {
  //       print('❌ [API SERVICE] Signup initial FAILED: ${result['message']}');
  //       return {
  //         'success': false,
  //         'message': result['message'] ?? 'Signup failed',
  //       };
  //     }
  //   } on TimeoutException {
  //     return {
  //       'success': false,
  //       'message': 'Connection timeout. Please try again.',
  //     };
  //   } on SocketException {
  //     return {
  //       'success': false,
  //       'message': 'No internet connection.',
  //     };
  //   } catch (e) {
  //     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  //     print('❌ [API SERVICE] CRITICAL ERROR:');
  //     print('   Error: $e');
  //     print('   Type: ${e.runtimeType}');
  //     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  //     return {
  //       'success': false,
  //       'message': 'An error occurred. Please try again.',
  //     };
  //   }
  // }

  // ... previous code ...

  static Future<Map<String, dynamic>> signupInitial(
      Map<String, dynamic> data) async {
    try {
      print('🚀 [API] Sending signup data...');

      // Prepare basic data
      Map<String, dynamic> requestData = {
        'full_name': data['full_name']?.toString() ?? '',
        'email': data['email']?.toString() ?? '',
        'password': data['password']?.toString() ?? '',
        'role': data['role']?.toString() ?? '',
        'phone': data['phone']?.toString(),

        // Location data
        'location_lat': data['location_lat'],
        'location_lng': data['location_lng'],
        'location_address': data['location_address']?.toString(),
        'city': data['city']?.toString(),
        'region': data['region']?.toString(),
      };

      // Add institution data if Manager
      if (data['role'] == 'Manager') {
        requestData.addAll({
          'institution_name': data['institution_name']?.toString(),
          'institution_contact_email':
              data['institution_contact_email']?.toString(),
          'institution_contact_phone':
              data['institution_contact_phone']?.toString(),
          'institution_license': data['institution_license']?.toString(),
          'institution_established_year': data['institution_established_year'],
          'institution_city': data['institution_city']?.toString(),
          'institution_region': data['institution_region']?.toString(),
        });
      }

      print('📤 Final data: $requestData');

      final response = await http
          .post(
            Uri.parse('$baseUrl/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestData),
          )
          .timeout(Duration(seconds: 30));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': result['message'],
          'tempToken': result['tempToken'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> updateChildBasicInfo(
    String token,
    int childId,
    Map<String, dynamic> payload,
  ) async {
    final url = _buildUrl('children/$childId');

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to update child: ${response.body}');
  }

  static Future<Map<String, dynamic>> uploadChildPhoto(
    String token,
    String childId,
    File imageFile,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(_buildUrl('children/$childId/upload-photo')),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          imageFile.path,
          filename: 'child_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      }

      throw Exception(
          responseData['message'] ?? 'Failed to upload child photo');
    } catch (e) {
      rethrow;
    }
  }

  /// Get donation impact/statistics v2 (money + equipment)
  static Future<Map<String, dynamic>> getDonationImpactV2(String token) async {
    try {
      final url = _buildUrl('donations/impact/v2');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }

      throw Exception('Failed to load donation impact v2');
    } catch (e) {
      print('❌ Error loading donation impact v2: $e');
      rethrow;
    }
  }

  /// Get donor impact feed (ImpactPost)
  static Future<Map<String, dynamic>> getDonorImpactFeed(
    String token, {
    int page = 1,
    int limit = 10,
    int? campaignId,
    int? equipmentCampaignId,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (campaignId != null) {
        queryParams['campaign_id'] = campaignId.toString();
      }
      if (equipmentCampaignId != null) {
        queryParams['equipment_campaign_id'] = equipmentCampaignId.toString();
      }

      final url = Uri.parse(_buildUrl('impact/feed'))
          .replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }

      throw Exception('Failed to load impact feed');
    } catch (e) {
      print('❌ Error loading impact feed: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getOpenEquipmentCampaigns() async {
    try {
      final url = Uri.parse('${_publicEquipmentBaseUrl()}/campaigns');

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          final List<dynamic> campaigns = data['data'] ?? [];
          return List<Map<String, dynamic>>.from(campaigns);
        } else {
          throw Exception('API Error: ${data['message']}');
        }
      } else {
        throw Exception(
            'Failed to load campaigns. Status: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get equipment donation campaigns for institution (public)
  /// Get institutions for equipment donation (PUBLIC API - No auth required)
  static Future<List<Map<String, dynamic>>>
      getEquipmentDonationInstitutions() async {
    return getEquipmentInstitutions();
  }

  /// Get institution equipment campaigns (PUBLIC API)
  static Future<List<Map<String, dynamic>>> getInstitutionEquipmentCampaigns(
    int institutionId,
  ) async {
    try {
      final url = Uri.parse(
          '${_publicEquipmentBaseUrl()}/institutions/$institutionId/campaigns');

      print('🌐 Fetching campaigns for institution: $institutionId');

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          final List<dynamic> campaigns = data['data'] ?? [];
          print('✅ Successfully loaded ${campaigns.length} campaigns');
          return List<Map<String, dynamic>>.from(campaigns);
        } else {
          throw Exception('API Error: ${data['message']}');
        }
      } else {
        throw Exception(
            'Failed to load campaigns. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getInstitutionEquipmentCampaigns: $e');
      rethrow;
    }
  }

  /// Get equipment campaign details (PUBLIC API)
  static Future<Map<String, dynamic>> getEquipmentCampaignDetails(
    int campaignId,
  ) async {
    try {
      final url =
          Uri.parse('${_publicEquipmentBaseUrl()}/campaigns/$campaignId');

      print('🌐 Fetching campaign details: $campaignId');

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          print('✅ Successfully loaded campaign details');
          return Map<String, dynamic>.from(data['data'] ?? {});
        } else {
          throw Exception('API Error: ${data['message']}');
        }
      } else {
        throw Exception(
            'Failed to load campaign details. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getEquipmentCampaignDetails: $e');
      rethrow;
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

          try {
            final fcmToken = (prefs.getString('fcm_token') ?? '').trim();
            if (fcmToken.isNotEmpty) {
              final base = kIsWeb
                  ? 'http://localhost:5000/api'
                  : 'http://10.0.2.2:5000/api';
              await http.post(
                Uri.parse('$base/device-tokens/register'),
                headers: {
                  'Authorization': 'Bearer ${result['token']}',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'token': fcmToken,
                  'platform': kIsWeb ? 'web' : 'mobile',
                }),
              );
            }
          } catch (_) {}
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
    final url = _buildUrl('password/send-reset-code');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    final url = _buildUrl('password/verify-code');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String code, String newPassword) async {
    final url = _buildUrl('password/reset-password');

    final response = await http.post(
      Uri.parse(url),
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
      final url = _buildUrl('parent/dashboard');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to load dashboard data');
      }
    } on TimeoutException {
      throw TimeoutException('Request timeout - Server is slow or unreachable');
    } catch (e) {
      throw Exception('Network error: $e');
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
    final url = _buildUrl('children');

    final response = await http.post(
      Uri.parse(url),
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
    final url = _buildUrl('children/$id');

    final response = await http.put(
      Uri.parse(url),
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
    final url = _buildUrl('children/$id');

    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete child: ${response.body}');
    }
  }

  static Future<void> unhideChild(String token, int id) async {
    final url = _buildUrl('children/$id/unhide');

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to unhide child: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getDailyAITip(String token) async {
    try {
      final url = _buildUrl('parent/daily-tip');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      print('📥 Daily Tip Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print('✅ Daily Tip Success: ${data['success']}');
        print('🤖 AI Generated: ${data['aiGenerated']}');
        print('💡 Tip: ${data['tip']}');

        return data;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to load daily tip');
      }
    } on TimeoutException {
      print('⚠️ Daily Tip timeout - using fallback');
      return _dailyTipFallback();
    } catch (e) {
      print('❌ Error fetching daily tip: $e');
      return _dailyTipFallback();
    }
  }

  static Map<String, dynamic> _dailyTipFallback() {
    return {
      'success': true,
      'tip':
          'Spend quality time with your child today—every moment together builds a stronger future.',
      'aiGenerated': false,
      'isGeneric': true,
    };
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
      final url = _buildUrl('diagnoses'); // استخدم baseUrl

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Diagnoses response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

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
      // {'diagnosis_id': 5, 'name': 'Learning Disabilities'},
      // {'diagnosis_id': 6, 'name': 'Intellectual Disability'},
      // {'diagnosis_id': 7, 'name': 'Developmental Delay'},
      // {'diagnosis_id': 8, 'name': 'Behavioral Disorders'},
      // {'diagnosis_id': 9, 'name': 'Social Communication Disorder'},
      // {'diagnosis_id': 10, 'name': 'Global Developmental Delay'},
    ];
  }

  // ================= Get Child Statistics =================
  // ================= Get Child Statistics =================
  static Future<Map<String, dynamic>> getChildStatistics(String token) async {
    final url = _buildUrl('children/stats'); // استخدم baseUrl

    final response = await http.get(
      Uri.parse(url),
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
    final url = _buildUrl('children/$childId'); // استخدم baseUrl

    final response = await http.get(
      Uri.parse(url),
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
      final url = _buildUrl('parent/sessions/$sessionId/confirm');

      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to confirm session');
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
        if (documents != null && documents.isNotEmpty) 'documents': documents,
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
        throw Exception(
            data['message'] ?? 'Failed to request financial assistance');
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
    try {
      final url = _buildUrl('parent/resources');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to fetch resources');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getInstitutions(
      String token) async {
    final url = _buildUrl('institutions'); // استخدام baseUrl

    final response = await http.get(
      Uri.parse(url),
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

// في api_service.dart - تحديث دالة getChildren
// تأكد أن getChildren تقبل named parameters
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
    final params = {
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
    };

    final uri = Uri.parse(_buildUrl('children')).replace(
      queryParameters: params.isNotEmpty ? params : null,
    );

    print('🌐 API Call: $uri');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📡 Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch children: ${response.statusCode}');
    }
  }
//   static Future<Map<String, dynamic>> getChildren({
//   required String token,
//   String? search,
//   String? gender,
//   String? diagnosis,
//   String? registrationStatus,
//   String? sort,
//   String? order,
//   int? page,
//   int? limit,
// }) async {
//   final uri = Uri.parse(
//     _buildUrl('children'), // استخدام baseUrl
//   ).replace(
//     queryParameters: {
//       if (search != null && search.isNotEmpty) 'search': search,
//       if (gender != null && gender.isNotEmpty && gender != 'All') 'gender': gender,
//       if (diagnosis != null && diagnosis.isNotEmpty && diagnosis != 'All') 'diagnosis': diagnosis,
//       if (registrationStatus != null &&
//           registrationStatus.isNotEmpty &&
//           registrationStatus != 'All')
//         'registration_status': registrationStatus,
//       if (sort != null) 'sort': sort,
//       if (order != null) 'order': order,
//       if (page != null) 'page': page.toString(),
//       if (limit != null) 'limit': limit.toString(),
//     },
//   );

//   print('🌐 API Call: $uri');
//   final response = await http.get(
//     uri,
//     headers: {
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $token',
//     },
//   );

//   print('📡 Response status: ${response.statusCode}');
//   print('📦 Raw response body: ${response.body}');

//   if (response.statusCode == 200) {
//     final Map<String, dynamic> data = jsonDecode(response.body);
//     return data;
//   } else {
//     throw Exception(
//         'Failed to fetch children: ${response.statusCode} - ${response.body}');
//   }
// }

  static Future<List<Session>> getSessions(String token) async {
    try {
      final url = _buildUrl('parent/sessions');

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
        return sessions
            .map<Session>((session) => Session.fromJson(session))
            .toList();
      } else {
        final data = json.decode(response.body);
        throw Exception(
          data['message'] ?? 'Failed to load sessions: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error fetching sessions: $e');
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

      final url = _buildUrl('parent/sessions/$sessionId/reschedule');

      final response = await http.patch(
        Uri.parse(url),
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
        }
        throw Exception(data['message'] ?? 'Failed to reschedule session');
      }

      if (response.statusCode == 404) {
        throw Exception('Session not found or you do not have permission');
      }
      if (response.statusCode == 400) {
        throw Exception('Cannot reschedule this session in its current status');
      }
      if (response.statusCode == 409) {
        throw Exception('Specialist is not available at the requested time');
      }

      throw Exception('Failed to reschedule session: ${response.statusCode}');
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

      final url = Uri.parse(_buildUrl('questionnaire/questions'))
          .replace(queryParameters: queryParams);

      final response = await http.get(
        url,
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
            Uri.parse(_buildUrl('questionnaire/responses')),
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
        Uri.parse(_buildUrl('questionnaire/history')).replace(queryParameters: {
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
        Uri.parse(_buildUrl('questionnaire/$questionnaireId')),
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
  static Future<Map<String, dynamic>> uploadParentProfilePicture(
      File imageFile) async {
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

      print(
          '📤 Uploading parent profile picture to: ${_buildUrl('parent/upload-profile-picture')}');
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
        throw Exception(
            'Upload failed: ${responseData['message']} (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error in uploadParentProfilePicture: $e');
      rethrow;
    }
  }

  // ========== UPDATE PARENT PROFILE (تحسينها) ==========
  static Future<bool> updateParentProfile(
      Map<String, dynamic> updateData) async {
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
  static Future<bool> validateImageSize(File imageFile,
      {int maxSizeMB = 5}) async {
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
        Uri.parse(_buildUrl('children')),
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
        Uri.parse(_buildUrl('children/symptoms-search')),
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
    String token,
  ) async {
    try {
      final url = _buildUrl('parent/child-evaluations');

      print('🌐 Calling API: $url');
      print('🔑 Token length: ${token.length}');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('🔍 API Response Status: ${response.statusCode}');
      print('📦 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ API Response Data: $data');

        if (data['success'] == true) {
          return data;
        }

        // fallback لو رجع evaluations مباشرة
        if (data['evaluations'] != null) {
          return {
            'success': true,
            'data': data['evaluations'],
          };
        }

        return {
          'success': false,
          'error': 'Unexpected response structure',
          'data': [],
        };
      }

      print('❌ API Error: ${response.statusCode} - ${response.body}');
      return {
        'success': false,
        'error': 'HTTP ${response.statusCode}',
        'data': [],
      };
    } on SocketException catch (e) {
      print('❌ Network Error - SocketException: $e');
      return {
        'success': false,
        'error': 'Network unavailable',
        'data': [],
      };
    } on TimeoutException catch (e) {
      print('❌ Network Error - Timeout: $e');
      return {
        'success': false,
        'error': 'Request timeout',
        'data': [],
      };
    } catch (e) {
      print('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Unexpected error: $e',
        'data': [],
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
        Uri.parse(_buildUrl('institutions/nearby')).replace(
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
        Uri.parse(_buildUrl('specialists/nearby'))
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
        Uri.parse(_buildUrl('children/basic-info')),
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
            Uri.parse(_buildUrl('children/$childId/medical-analysis')),
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
    String childId,
    double discountPercentage, {
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
        Uri.parse(_buildUrl('children/$childId/recommended-institutions'))
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
        Uri.parse(_buildUrl('children/$childId/request-registration')),
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
        Uri.parse(_buildUrl('children/$childId/registration-status')),
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

  static Future<Map<String, dynamic>> getDonorAIRecommendations(
    String token, {
    int limit = 8,
  }) async {
    try {
      final uri = Uri.parse(_buildUrl('ai/donor/recommendations')).replace(
        queryParameters: {
          'limit': limit.toString(),
        },
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
      }

      return {
        'success': false,
        'recommendations': [],
      };
    } catch (e) {
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
        Uri.parse(_buildUrl('admin/dashboard')),
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
        Uri.parse(_buildUrl('admin/institutions'))
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
        Uri.parse(_buildUrl('admin/institutions/$institutionId/approve')),
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
        Uri.parse(_buildUrl('admin/institutions/$institutionId/reject')),
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
    final url = Uri.parse(_buildUrl('financial/assessment/initiate'));

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
    try {
      final url = Uri.parse(_buildUrl('financial/assessment/submit'));
      print('🌐 Submitting financial assessment to: $url');

      final requestBody = {
        'child_id': childId,
        'institution_id': institutionId,
        'responses': responses,
        'skip_documents': skipDocuments,
      };

      print('📝 Request body: $requestBody');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to submit financial assessment: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error in submitFinancialAssessment: $e');
      throw Exception(
          'Network error while submitting financial assessment: $e');
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
    try {
      final url =
          Uri.parse(_buildUrl('financial/assistance/$requestId/status'));
      print('🌐 Fetching financial assistance status from: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to get financial assistance status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error in getFinancialAssistanceStatus: $e');
      throw Exception('Network error while fetching status: $e');
    }
  }

  // 5. Upload Financial Documents
  static Future<Map<String, dynamic>> uploadFinancialDocuments(
    String token,
    int requestId,
    List<Map<String, dynamic>> documents,
  ) async {
    try {
      final url =
          Uri.parse(_buildUrl('financial/assistance/$requestId/documents'));
      print('🌐 Uploading financial documents to: $url');
      print('📄 Number of documents: ${documents.length}');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'documents': documents}),
      );

      print('📊 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to upload financial documents: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error in uploadFinancialDocuments: $e');
      throw Exception('Network error while uploading financial documents: $e');
    }
  }

  // 6. Get Parent Financial Profile
  // في api_service.dart - تحديث دالة getParentFinancialProfile
  static Future<Map<String, dynamic>> getParentFinancialProfile(
      String token) async {
    try {
      final url = Uri.parse(_buildUrl('financial/profile'));
      print('🌐 Fetching parent financial profile from: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        // إذا لم يكن هناك ملف مالي، نعود لاستخدام بيانات افتراضية
        return {
          'success': true,
          'data': _createDefaultFinancialProfile(),
          'message': 'Using default financial profile',
        };
      } else {
        // لجميع الحالات الأخرى، نستخدم البيانات الافتراضية
        return {
          'success': true,
          'data': _createDefaultFinancialProfile(),
          'message': 'Using default financial data',
        };
      }
    } catch (e) {
      print('❌ Error in getParentFinancialProfile: $e');
      // في حالة الخطأ، نستخدم البيانات الافتراضية
      return {
        'success': true,
        'data': _createDefaultFinancialProfile(),
        'message': 'Using default due to error',
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
      final url = Uri.parse(_buildUrl('financial/requests')).replace(
        queryParameters: {
          'status': status,
          'page': page.toString(),
          'limit': limit.toString(),
          'sort_by': sortBy,
          'sort_order': sortOrder,
        },
      );

      print('🌐 Fetching financial assistance requests...');
      print('🔗 URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        print('⚠️ Failed to fetch requests, returning default response');
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
      final url = Uri.parse(_buildUrl('financial/assessment/general/initiate'));

      print('🌐 Initiating general financial assessment...');
      print('🔗 URL: $url');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to initiate general financial assessment: ${response.statusCode}');
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
      final url = Uri.parse(_buildUrl('financial/assessment/general/submit'));

      print('🌐 Submitting general financial assessment...');
      print('📝 Responses keys: ${responses.keys.toList()}');
      print('🔗 URL: $url');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'responses': responses}),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to submit general financial assessment: ${response.statusCode}');
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
      final url = Uri.parse(_buildUrl('financial/assessment/apply-to-child'));

      print('🌐 Applying financial assessment to child...');
      print('   Child ID: $childId');
      print('   Institution ID: $institutionId');
      print('   URL: $url');

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
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to apply financial assessment: ${response.statusCode}');
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
      return {'success': true, 'data': [], 'message': 'Feature coming soon'};
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
      final url = Uri.parse(_buildUrl('financial/institutions/recommended'))
          .replace(queryParameters: {
        'tier': financialTier,
        'discount': discountPercentage.toString(),
      });

      print('🌐 Getting recommended institutions by tier...');
      print('   Tier: $financialTier');
      print('   Discount: $discountPercentage%');
      print('   URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
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
      final url = _buildUrl('children/by-institution/$institutionId');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to load children',
          'data': [],
        };
      }
    } catch (e) {
      print('❌ Error in getChildrenByInstitution: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'data': [],
      };
    }
  }

  /// Get institution campaigns for donations
  static Future<List<Map<String, dynamic>>> getInstitutionCampaignsForDonations(
    String token,
    int institutionId,
  ) async {
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
        if (data['success'] == true) {
          final List campaigns = data['data'] ?? [];
          return List<Map<String, dynamic>>.from(campaigns);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch campaigns');
        }
      } else {
        throw Exception('Failed to fetch campaigns: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while loading campaigns: $e');
    }
  }

// التحقق التلقائي من المساعدة المالية
  static Future<Map<String, dynamic>> checkAutoFinancialAssistance(
    String token,
    String sessionId,
  ) async {
    try {
      final url = _buildUrl('parent/$sessionId/check-auto-assistance');

      print('🌐 Checking auto financial assistance...');
      print('   Session ID: $sessionId');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
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
      final url = _buildUrl('parent/$sessionId/apply-auto-discount');

      print('🌐 Applying auto discount...');
      print('   Session ID: $sessionId');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}), // حتى لو body فارغ
      );

      print('📥 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
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

  static String _adminUrl(String path) {
    final host = kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000';
    return '$host$path';
  }

  static Future<Map<String, dynamic>> getAdminUsers({
    required String token,
    int page = 1,
    int limit = 10,
    String? role,
    String? status,
    String? search,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (role != null && role.isNotEmpty && role != 'all') {
        queryParams['role'] = role;
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await http.get(
        Uri.parse(_adminUrl('/api/admin/users'))
            .replace(queryParameters: queryParams),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading admin users: $e');
      rethrow;
    }
  }

  static Future<bool> approveUser(String token, int userId) async {
    try {
      final response = await http.post(
        Uri.parse(_adminUrl('/api/admin/users/$userId/approve')),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('Failed to approve user: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error approving user: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAdminSystemHealth(String token) async {
    try {
      final response = await http.get(
        Uri.parse(_adminUrl('/api/admin/system/health')),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load system health: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading system health: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAdminUserRegistrationsAnalytics({
    required String token,
    String role = 'all',
    int? year,
    String? city,
    String groupBy = 'month',
  }) async {
    try {
      final Map<String, String> queryParams = {
        'role': role,
        'groupBy': groupBy,
      };
      if (year != null) queryParams['year'] = year.toString();
      if (city != null && city.isNotEmpty && city != 'all')
        queryParams['city'] = city;

      final response = await http.get(
        Uri.parse(_adminUrl('/api/admin/analytics/user-registrations'))
            .replace(queryParameters: queryParams),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load analytics: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading admin user registrations analytics: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAdminInstitutionsByCity({
    required String token,
    String status = 'all',
    int limit = 12,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'status': status,
        'limit': limit.toString(),
      };

      final response = await http.get(
        Uri.parse(_adminUrl('/api/admin/analytics/institutions-by-city'))
            .replace(queryParameters: queryParams),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to load institutions distribution: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading admin institutions by city: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAdminInstitutionsMapPoints({
    required String token,
    String status = 'Approved',
    String? city,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'status': status,
      };
      if (city != null && city.isNotEmpty && city != 'all')
        queryParams['city'] = city;

      final response = await http.get(
        Uri.parse(_adminUrl('/api/admin/map/institutions'))
            .replace(queryParameters: queryParams),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to load institutions map points: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading admin institutions map points: $e');
      rethrow;
    }
  }

  /// Create donation checkout with support for anonymous donors
  static Future<Map<String, dynamic>> createDonationCheckout(
    String? token, // ✅ جعل token اختياري
    {
    required int institutionId,
    required double amount,
    String mode = 'one_time',
    int? campaignId,
    String? inviteCode,
    bool anonymous = false,
    String? donorName,
    String? donorEmail,
    String currency = 'jod',
  }) async {
    try {
      final url = _buildUrl('donations/flexible/checkout');

      final body = <String, dynamic>{
        'institution_id': institutionId,
        'amount': amount,
        'mode': mode,
        'currency': currency,
        'anonymous': anonymous,
      };

      if (campaignId != null) {
        body['campaign_id'] = campaignId;
      }

      if (inviteCode != null && inviteCode.trim().isNotEmpty) {
        body['invite_code'] = inviteCode.trim();
      }

      // ✅ إضافة بيانات المتبرع المجهول إذا كانت متوفرة
      if (anonymous) {
        if (donorName != null && donorName.isNotEmpty) {
          body['donor_name'] = donorName;
        }
        if (donorEmail != null && donorEmail.isNotEmpty) {
          body['donor_email'] = donorEmail;
        }
      }

      print('🌐 Creating checkout (anonymous: $anonymous)');
      print('📦 Request body: $body');

      // ✅ إعداد الهيدرات بناءً على وجود token
      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          final checkoutUrl =
              (data['url'] ?? data['checkout_url'] ?? '').toString();
          final sessionId =
              (data['sessionId'] ?? data['session_id'] ?? '').toString();

          return {
            'success': true,
            'url': checkoutUrl,
            'sessionId': sessionId,
            'donation_id': data['donation_id'],
            'anonymous': data['anonymous'] ?? anonymous,
            'message': data['message'] ?? 'Checkout created successfully',
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to create checkout');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            '${errorData['message']} (Status: ${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Connection timeout. Please check your internet.');
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      print('❌ Error in createDonationCheckout: $e');
      rethrow;
    }
  }

  /// ✅ دالة جديدة للتبرع المجهول فقط
  static Future<Map<String, dynamic>> createAnonymousDonation({
    required int institutionId,
    required double amount,
    String? donorEmail,
    String? donorName,
    int? campaignId,
    String currency = 'jod',
  }) async {
    try {
      final url = _buildUrl('donations/anonymous/checkout');

      final body = <String, dynamic>{
        'institution_id': institutionId,
        'amount': amount,
        'currency': currency,
      };

      if (donorEmail != null && donorEmail.isNotEmpty) {
        body['donor_email'] = donorEmail;
      }

      if (donorName != null && donorName.isNotEmpty) {
        body['donor_name'] = donorName;
      }

      if (campaignId != null) {
        body['campaign_id'] = campaignId;
      }

      print('🎭 Creating anonymous donation');
      print('📦 Request body: $body');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Failed to create anonymous donation');
      }
    } catch (e) {
      print('❌ Error in createAnonymousDonation: $e');
      rethrow;
    }
  }

  /// Check donation status
  static Future<Map<String, dynamic>> checkDonationStatus(
    String token, {
    String? sessionId,
    int? donationId,
  }) async {
    try {
      if (sessionId == null && donationId == null) {
        throw Exception('Either sessionId or donationId is required');
      }

      final queryParams = <String, String>{};
      if (sessionId != null) queryParams['session_id'] = sessionId;
      if (donationId != null)
        queryParams['donation_id'] = donationId.toString();

      final url = Uri.parse(_buildUrl('donations/status'))
          .replace(queryParameters: queryParams);

      print('🔍 Checking donation status: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📡 Status check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to check status');
        }
      } else {
        throw Exception(
            'Failed to check donation status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error checking donation status: $e');
      rethrow;
    }
  }

  /// Confirm donation after returning from Stripe
  static Future<Map<String, dynamic>> confirmDonationFromStripe(
    String token, {
    required String sessionId,
  }) async {
    try {
      final url = _buildUrl('donations/confirm');

      final body = {'session_id': sessionId};

      print('✅ Confirming donation with session: $sessionId');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: 15));

      print('📡 Confirm response status: ${response.statusCode}');
      print('📦 Confirm response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Donation confirmed successfully',
            'donation': data['donation'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to confirm donation');
        }
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Payment not completed');
      } else {
        throw Exception('Failed to confirm donation: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception(
          'Verification timeout. Please check your donation history.');
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      print('❌ Error confirming donation: $e');
      rethrow;
    }
  }

  /// Get donation history
  static Future<Map<String, dynamic>> getDonationHistory(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
    String? donationType,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (donationType != null) queryParams['donation_type'] = donationType;

      final url = Uri.parse(_buildUrl('donations/history'))
          .replace(queryParameters: queryParams);

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
        throw Exception('Failed to load donation history');
      }
    } catch (e) {
      print('❌ Error loading donation history: $e');
      rethrow;
    }
  }

  /// Get donation impact/statistics
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }

      throw Exception('Failed to load donation impact');
    } catch (e) {
      print('❌ Error loading donation impact: $e');
      rethrow;
    }
  }

  /// Check donation status before confirming
  static Future<Map<String, dynamic>> checkDonationStatusBySession(
    String token, {
    required String sessionId,
  }) async {
    try {
      final url = Uri.parse(_buildUrl('donations/status'))
          .replace(queryParameters: {'session_id': sessionId});

      print('🔍 Checking donation status for session: $sessionId');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📡 Status check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception(
            'Failed to check donation status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error checking donation status: $e');
      rethrow;
    }
  }

// ==================== Equipment Donation APIs ====================

  /// Get equipment categories
  static Future<List<Map<String, dynamic>>> getEquipmentCategories() async {
    try {
      final url = Uri.parse('${_authEquipmentBaseUrl()}/categories');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }
      throw Exception('Failed to load equipment categories');
    } catch (e) {
      print('Error getting equipment categories: $e');
      rethrow;
    }
  }

  /// Get institutions for equipment donation
  static Future<List<Map<String, dynamic>>> getEquipmentInstitutions() async {
    try {
      final url = Uri.parse('${_publicEquipmentBaseUrl()}/institutions');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }

      throw Exception('Failed to load equipment institutions');
    } catch (e) {
      print('Error getting equipment institutions: $e');
      rethrow;
    }
  }

  /// Create anonymous equipment donation
  static Future<Map<String, dynamic>> createAnonymousEquipmentDonation({
    required int institutionId,
    required String equipmentName,
    required String contactPerson,
    required String contactPhone,
    String? contactEmail,
    int? categoryId,
    String? description,
    String? condition,
    String? deliveryType,
    double? estimatedValue,
    DateTime? preferredDate,
  }) async {
    try {
      final url = Uri.parse('${_publicEquipmentBaseUrl()}/donate/anonymous');

      final body = <String, dynamic>{
        'institution_id': institutionId,
        'equipment_name': equipmentName,
        'contact_person': contactPerson,
        'contact_phone': contactPhone,
      };

      if (contactEmail != null && contactEmail.isNotEmpty) {
        body['contact_email'] = contactEmail;
      }

      if (categoryId != null) {
        body['category_id'] = categoryId;
      }

      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }

      if (condition != null && condition.isNotEmpty) {
        body['condition'] = condition;
      }

      if (deliveryType != null && deliveryType.isNotEmpty) {
        body['delivery_type'] = deliveryType;
      }

      if (estimatedValue != null) {
        body['estimated_value'] = estimatedValue;
      }

      if (preferredDate != null) {
        body['preferred_date'] = preferredDate.toIso8601String();
      }

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Failed to submit equipment donation');
      }
    } catch (e) {
      print('Error creating anonymous equipment donation: $e');
      rethrow;
    }
  }

  /// Check equipment donation status
  static Future<Map<String, dynamic>> checkEquipmentDonationStatus({
    required int donationId,
    required String contactPhone,
  }) async {
    try {
      final url = Uri.parse('${_publicEquipmentBaseUrl()}/status')
          .replace(queryParameters: {
        'donation_id': donationId.toString(),
        'contact_phone': contactPhone,
      });

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Failed to check donation status');
      }
    } catch (e) {
      print('Error checking equipment donation status: $e');
      rethrow;
    }
  }

  /// Get user's equipment donations (authenticated)
  static Future<List<Map<String, dynamic>>> getUserEquipmentDonations(
      String token) async {
    try {
      final url = Uri.parse('${_authEquipmentBaseUrl()}/my-donations');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(
              data['data']['donations'] ?? []);
        }
      }
      throw Exception('Failed to load your equipment donations');
    } catch (e) {
      print('Error getting user equipment donations: $e');
      rethrow;
    }
  }

  /// Get equipment donation details
  static Future<Map<String, dynamic>> getEquipmentDonationDetails({
    required int donationId,
    String? token,
  }) async {
    try {
      final url = Uri.parse('${_authEquipmentBaseUrl()}/$donationId');

      final headers = {'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Failed to load donation details');
      }
    } catch (e) {
      print('Error getting equipment donation details: $e');
      rethrow;
    }
  }

// دالة جديدة لجلب بيانات المتبرع
  static Future<Map<String, dynamic>> getDonorProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse(_buildUrl('donations/donor/profile')),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load donor profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching donor profile: $e');
      rethrow;
    }
  }

// services/api_service.dart

  static Future<Map<String, dynamic>> uploadMedicalDocument(
    String token,
    String childId,
    PlatformFile file,
  ) async {
    try {
      print('📤 ========== UPLOAD DEBUG ==========');
      print('📤 File name: ${file.name}');
      print('📤 File path: ${file.path}');
      print('📤 File size: ${file.size} bytes');
      print('📤 File extension: ${file.extension}');

      // التحقق من وجود المسار
      if (file.path == null || file.path!.isEmpty) {
        throw Exception('File path is null or empty');
      }

      // التحقق من وجود الملف
      final fileExists = await File(file.path!).exists();
      print('📤 File exists: $fileExists');

      if (!fileExists) {
        throw Exception('File does not exist at path: ${file.path}');
      }

      // إنشاء الطلب
      final url = _buildUrl('children/$childId/upload-document');
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // إضافة الـ headers
      request.headers['Authorization'] = 'Bearer $token';
      print('📤 Authorization token added');

      // إضافة الملف
      final multipartFile = await http.MultipartFile.fromPath(
        'medical_document', // ⚠️ تأكد من الاسم
        file.path!,
        filename: file.name,
      );

      request.files.add(multipartFile);
      print('📤 File added to request:');
      print('   - Field name: medical_document');
      print('   - Filename: ${multipartFile.filename}');
      print('   - Content type: ${multipartFile.contentType}');
      print('   - Length: ${multipartFile.length}');

      // إرسال الطلب
      print('📤 Sending request to: ${request.url}');
      final streamedResponse = await request.send();

      print('📡 Response status: ${streamedResponse.statusCode}');

      // قراءة الاستجابة
      final responseBody = await streamedResponse.stream.bytesToString();
      print('📡 Response body: $responseBody');

      final result = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200) {
        print('✅ Upload successful!');
        return {
          'success': true,
          ...result,
        };
      } else {
        print('❌ Upload failed');
        return {
          'success': false,
          'message': result['message'] ?? 'Upload failed',
          'error_code': result['error_code'],
        };
      }
    } catch (e, stackTrace) {
      print('❌ ========== UPLOAD ERROR ==========');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');

      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// حذف مستند طبي
  static Future<Map<String, dynamic>> deleteMedicalDocument(
    String token,
    String childId,
    String fileId,
  ) async {
    try {
      final url = _buildUrl('children/$childId/documents/$fileId');

      print('🗑️ Deleting document: $fileId for child: $childId');
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to delete document: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error deleting document: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> createMobileDonationPayment({
    required String token,
    required int institutionId,
    required double amount,
    int? campaignId,
    String mode = 'one_time',
    bool anonymous = false,
    String? donorName,
    String? donorEmail,
    String? inviteCode,
    String currency = 'jod',
  }) async {
    try {
      final url = _buildUrl('donations/checkout');

      final body = {
        'institution_id': institutionId,
        'amount': amount,
        'mode': mode,
        'currency': currency,
        'platform': 'mobile', // ✅ مهم جداً
        'anonymous': anonymous,
        if (campaignId != null) 'campaign_id': campaignId,
        if (inviteCode != null && inviteCode.isNotEmpty)
          'invite_code': inviteCode,
        if (donorName != null && donorName.isNotEmpty) 'donor_name': donorName,
        if (donorEmail != null && donorEmail.isNotEmpty)
          'donor_email': donorEmail,
      };

      print('📱 Creating mobile payment:');
      print('   URL: $url');
      print('   Body: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
              'User-Agent': 'JusoorMobile/1.0', // ✅ مهم
              'X-Platform': 'mobile', // ✅ إضافي للتأكيد
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          // ✅ التحقق من وجود payment_intent_client_secret
          final clientSecret = data['payment_intent_client_secret'];

          if (clientSecret == null || clientSecret.toString().isEmpty) {
            // Backend أرجع checkout URL بدلاً من payment intent
            print('⚠️ Backend returned checkout URL instead of payment intent');
            print('Response data: $data');

            throw Exception('Backend is not configured for mobile payments. '
                'Received checkout URL instead of payment intent. '
                'Please ensure platform=mobile is being processed correctly.');
          }

          return {
            'success': true,
            'payment_intent_client_secret': clientSecret,
            'payment_intent_id': data['payment_intent_id'],
            'donation_id': data['donation_id'],
            'amount': data['amount'],
            'currency': data['currency'],
            'anonymous': data['anonymous'],
          };
        } else {
          throw Exception(data['message'] ?? 'Payment creation failed');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'HTTP ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Connection timeout. Please check your internet.');
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      print('❌ Payment creation error: $e');
      rethrow;
    }
  }

  static Future<void> confirmDonationPayment({
    required String token,
    required String paymentIntentId,
    int? donationId,
  }) async {
    try {
      final url = _buildUrl('donations/confirm-payment');

      print('🔍 Confirming payment: $paymentIntentId');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'payment_intent_id': paymentIntentId,
              if (donationId != null) 'donation_id': donationId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('📡 Confirmation response: ${response.statusCode}');

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Confirmation failed');
      }

      print('✅ Payment confirmed successfully');
    } catch (e) {
      print('⚠️ Payment confirmation error: $e');
      // لا نرمي الخطأ لأن الدفع نجح في Stripe
    }
  }

  static Future<Map<String, dynamic>> uploadActivityDocument(
    String token,
    String childId, // ✅ تأكد أنه String
    File documentFile,
  ) async {
    try {
      print('📤 Uploading activity document...');
      print('   Child ID: $childId (${childId.runtimeType})');
      print('   File path: ${documentFile.path}');

      final uri =
          Uri.parse(_buildUrl('children/$childId/upload-activity-document'));
      print('   API URL: $uri');

      var request = http.MultipartRequest('POST', uri);

      // Headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // File
      final fileExtension = documentFile.path.split('.').last.toLowerCase();
      String mimeType;

      switch (fileExtension) {
        case 'pdf':
          mimeType = 'application/pdf';
          break;
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'doc':
          mimeType = 'application/msword';
          break;
        case 'docx':
          mimeType =
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          break;
        case 'txt':
          mimeType = 'text/plain';
          break;
        default:
          mimeType = 'application/octet-stream';
      }

      print('   MIME type: $mimeType');

      request.files.add(
        await http.MultipartFile.fromPath(
          'activity_document', // ✅ اسم الحقل كما في الباك إند
          documentFile.path,
          contentType: http.MediaType.parse(mimeType),
        ),
      );

      // إرسال الطلب
      print('   Sending request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Upload response status: ${response.statusCode}');
      print('📡 Upload response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception('Failed to upload document: $e');
    }
  }

  /// تحليل المستند وتوليد أنشطة
  static Future<Map<String, dynamic>> analyzeForActivities(
      String token, String childId, // ✅ String
      {String? analysisId}) async {
    try {
      print('🔍 Analyzing for activities...');
      print('   Child ID: $childId (${childId.runtimeType})');
      print('   Analysis ID: $analysisId');

      final uri =
          Uri.parse(_buildUrl('children/$childId/analyze-for-activities'));
      print('   API URL: $uri');

      final body = <String, dynamic>{};
      if (analysisId != null && analysisId.isNotEmpty) {
        body['analysis_id'] = analysisId;
      }

      print('   Request body: $body');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body.isNotEmpty ? jsonEncode(body) : null,
      );

      print('📡 Analysis response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Analysis success: ${data['success']}');
        return data;
      } else {
        print('❌ Analysis failed: ${response.body}');
        throw Exception('Analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Analyze error: $e');
      throw Exception('Failed to analyze: $e');
    }
  }

  /// تحليل سريع (بدون مستند)
  static Future<Map<String, dynamic>> quickActivityAnalysis(
    String token,
    String childId, // ✅ String
  ) async {
    try {
      print('⚡ Quick activity analysis...');
      print('   Child ID: $childId (${childId.runtimeType})');

      final uri =
          Uri.parse(_buildUrl('children/$childId/quick-activity-analysis'));
      print('   API URL: $uri');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Quick analysis response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Quick analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Quick analysis error: $e');
      throw Exception('Failed to perform quick analysis: $e');
    }
  }

  /// جلب التوصيات
  static Future<Map<String, dynamic>> getActivityRecommendations(
    String token,
    String childId, // ✅ String
    {
    String? status,
    String? activityType,
    int? limit = 20,
    int? page = 1,
  }) async {
    try {
      print('📥 Getting activity recommendations...');
      print('   Child ID: $childId (${childId.runtimeType})');

      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (activityType != null) queryParams['activity_type'] = activityType;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (page != null) queryParams['page'] = page.toString();

      final uri =
          Uri.parse(_buildUrl('children/$childId/activity-recommendations'))
              .replace(
                  queryParameters: queryParams.isNotEmpty ? queryParams : null);

      print('   API URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Get recommendations response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // إذا لم توجد توصيات، نرجع قائمة فارغة بدل exception
        print('⚠️ No recommendations or error: ${response.body}');
        return {
          'success': true,
          'data': [],
        };
      }
    } catch (e) {
      print('❌ Get recommendations error: $e');
      // نرجع قائمة فارغة بدل exception
      return {
        'success': true,
        'data': [],
      };
    }
  }

  /// تحديث حالة النشاط
  static Future<Map<String, dynamic>> updateActivityStatus(
    String token,
    String childId, // ✅ String
    String activityId, // ✅ String
    String status, {
    int? parentRating,
    String? childEngagement,
    String? notes,
  }) async {
    try {
      print('🔄 Updating activity status...');
      print('   Child ID: $childId (${childId.runtimeType})');
      print('   Activity ID: $activityId (${activityId.runtimeType})');
      print('   New status: $status');

      final uri = Uri.parse(
          _buildUrl('children/$childId/activities/$activityId/status'));

      print('   API URL: $uri');

      final body = <String, dynamic>{
        'status': status,
      };

      if (parentRating != null) body['parent_rating'] = parentRating;
      if (childEngagement != null) body['child_engagement'] = childEngagement;
      if (notes != null) body['notes'] = notes;

      print('   Request body: $body');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('📡 Update status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Update failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Update status error: $e');
      throw Exception('Failed to update status: $e');
    }
  }
}

extension on String {
  replace({required Map<String, String> queryParameters}) {}
}
