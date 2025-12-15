import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagerChildrenService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api'; // أو عنوان خادمك

  static Future<Map<String, dynamic>> getChildrenManagementData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/children-management'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Managers only.');
      } else if (response.statusCode == 404) {
        throw Exception('Manager or institution not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load data');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getDetailedStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/children-management/statistics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load statistics');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> approveRegistrationRequest(
      int requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/registration-requests/$requestId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': 'Approved'}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to approve request');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> rejectRegistrationRequest(int requestId,
      {String? reason}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/registration-requests/$requestId/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': 'Rejected',
          'reason': reason ?? 'Request rejected'
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to reject request');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateChildStatus({
    required int childId,
    required String status,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/children/$childId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': status,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            errorData['message'] ?? 'Failed to update child status');
      }
    } catch (e) {
      rethrow;
    }
  }


  static Future<Map<String, dynamic>> getChildDetailedInfo(int childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/child/$childId/detailed-info'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Managers only.');
      } else if (response.statusCode == 404) {
        throw Exception('Child not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load child details');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getChildDetails(int childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/children/$childId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load child details');
      }
    } catch (e) {
      rethrow;
    }
  }

// 1. جلب قائمة الآباء
  static Future<Map<String, dynamic>> getParentsList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/children/parents'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Managers only.');
      } else if (response.statusCode == 404) {
        throw Exception('Institution not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load parents list');
      }
    } catch (e) {
      rethrow;
    }
  }


  static Future<Map<String, dynamic>> getAvailableSpecialists({String? date}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      // **التعديل هنا**: التحقق من أن التاريخ ليس في الماضي
      final now = DateTime.now();
      String effectiveDate; // بدون قيمة أولية

      if (date != null) {
        final requestedDate = DateTime.parse(date);
        if (requestedDate.isBefore(DateTime(now.year, now.month, now.day))) {
          print('⚠️ Requested date $date is in the past. Using current date instead.');
          // إذا كان التاريخ في الماضي، استخدم اليوم
          effectiveDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        } else {
          // إذا كان التاريخ في الحاضر أو المستقبل، استخدمه كما هو
          effectiveDate = date;
        }
      } else {
        // إذا لم يتم تحديد تاريخ، استخدم اليوم
        effectiveDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      }

      // بناء URL مع التاريخ المصحح
      String url = '$_baseUrl/manager/children/available-specialists?date=$effectiveDate';

      print('📅 Requesting available specialists from: $url');
      print('📅 Effective date: $effectiveDate');
      print('📅 Original requested date: $date');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📥 Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Successfully loaded available specialists');
        print('   Available days: ${data['data']?['total_available_days'] ?? 0}');
        print('   Total slots: ${data['data']?['total_available_slots'] ?? 0}');
        if (data['data']?['closest_available_slot'] != null) {
          print('   Closest slot: ${data['data']['closest_available_slot']['display_date']} at ${data['data']['closest_available_slot']['display_start_time']}');
        }
        return data;
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        print('❌ Bad request: ${errorData['message']}');
        throw Exception(errorData['message'] ?? 'Invalid request parameters');
      } else if (response.statusCode == 404) {
        final errorData = json.decode(response.body);
        print('❌ Not found: ${errorData['message']}');
        throw Exception(errorData['message'] ?? 'No available specialists found');
      } else {
        final errorData = json.decode(response.body);
        print('❌ Server error: ${response.statusCode} - ${errorData['message']}');
        throw Exception(errorData['message'] ?? 'Failed to load available specialists');
      }
    } catch (e) {
      print('❌ Error in getAvailableSpecialists: $e');
      rethrow;
    }
  }


   // 3. إضافة طفل جديد - UPDATED مع الإشعارات
  static Future<Map<String, dynamic>> addNewChild({
    required Map<String, dynamic> parentData,
    required Map<String, dynamic> childData,
    Map<String, dynamic>? sessionData,
    // 👇 جديد: نضيف باراميترات للإشعارات
    String? parentFcmToken,      // توكن الأب (إذا أب موجود)
    String? specialistFcmToken,  // توكن الأخصائي (إذا بتحجز جلسة)
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('📤 Sending add child request...');
      print('📱 Parent FCM Token: ${parentFcmToken != null ? "Provided" : "Not provided"}');
      print('📱 Specialist FCM Token: ${specialistFcmToken != null ? "Provided" : "Not provided"}');
      // 👇 طبع التوكن للتأكد
      if (parentFcmToken != null) {
        print('   Parent token value: ${parentFcmToken.substring(0, 20)}...');
      }
      if (specialistFcmToken != null) {
        print('   Specialist token value: ${specialistFcmToken.substring(0, 20)}...');
      }
      // بناء الـ payload مع إضافة التوكنات لو أرسلت
      final Map<String, dynamic> payload = {
        'parentData': parentData,
        'childData': childData,
        'sessionData': sessionData,
      };

      // أضف التوكنات إذا وجدت
      if (parentFcmToken != null) {
        payload['parent_fcm_token'] = parentFcmToken;
      }
      if (specialistFcmToken != null) {
        payload['specialist_fcm_token'] = specialistFcmToken;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/manager/children/add-child'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      print('📥 Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);

        // 👇 إرسال الإشعارات مباشرة من الفرونت (بدون انتظار الباك)
        if (data['success'] == true) {
          final childId = data['data']['child']['child_id'].toString();
          final childName = childData['full_name'];

          // 1. إرسال إشعار للأهل
          if (parentFcmToken != null && parentData.containsKey('parent_id')) {
            // فقط إذا كان أب موجود (ليس جديداً)
            await sendChildAddedNotification(
              parentToken: parentFcmToken,
              childName: childName,
              childId: childId,
            ).catchError((e) {
              print('⚠️ Parent notification failed: $e');
            });
          }

          // 2. إرسال إشعار للأخصائي (إذا تم حجز جلسة)
          if (sessionData != null && specialistFcmToken != null) {
            final date = sessionData['date'];
            final time = sessionData['start_time'];
            final sessionId = data['data']['session']?['session_id']?.toString() ?? 'unknown';

            await sendSessionBookedNotification(
              specialistToken: specialistFcmToken,
              childName: childName,
              date: date,
              time: time,
              sessionId: sessionId,
            ).catchError((e) {
              print('⚠️ Specialist notification failed: $e');
            });
          }
        }

        return data;
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Missing required information');
      } else if (response.statusCode == 404) {
        throw Exception('Institution not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to add child');
      }
    } catch (e) {
      print('❌ Error in addNewChild: $e');
      rethrow;
    }
  }


  // 4. حجز جلسة General
  static Future<Map<String, dynamic>> bookGeneralSession({
    required int childId,
    required int specialistId,
    required String date,
    required String startTime,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/manager/children/book-general-session'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'child_id': childId,
          'specialist_id': specialistId,
          'date': date,
          'start_time': startTime,
          'notes': notes,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        throw Exception('Missing required information');
      } else if (response.statusCode == 404) {
        throw Exception('Child or specialist not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to book session');
      }
    } catch (e) {
      rethrow;
    }
  }
// 1. Check child archive eligibility (تحقق فقط)
  static Future<Map<String, dynamic>> checkChildArchiveEligibility(int childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/child/$childId/check-archive'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Check Archive Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Child has upcoming sessions');
      } else if (response.statusCode == 404) {
        throw Exception('Child not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to check archive eligibility');
      }
    } catch (e) {
      print('Error in checkChildArchiveEligibility: $e');
      rethrow;
    }
  }

  // 2. Force archive child (حتى لو فيه جلسات)
  static Future<Map<String, dynamic>> forceArchiveChild(int childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/manager/child/$childId/force-archive'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Force Archive Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        throw Exception('Cannot archive child');
      } else if (response.statusCode == 404) {
        throw Exception('Child not found');
      } else if (response.statusCode == 403) {
        throw Exception('You are not authorized to perform this action');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to archive child');
      }
    } catch (e) {
      print('Error in forceArchiveChild: $e');
      rethrow;
    }
  }
// In manager_children_service.dart
  static Future<Map<String, dynamic>> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token'); // 👈 This is the JWT token

      if (authToken == null) {
        throw Exception('No authentication token found');
      }

      print('📤 Sending notification via API...');
      print('Title: $title');
      print('Body: $body');
      print('Token: ${token.substring(0, 20)}...');
      print('Data: $data');
      print('Auth Token: ${authToken.substring(0, 20)}...'); // 👈 For verification

      // 👇 Add the Authorization header
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/notifications/test'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken', // 👈 This was missing
        },
        body: json.encode({
          'token': token, // This is FCM token
          'title': title,
          'body': body,
          ...(data ?? {}),
        }),
      );

      print('📥 Notification response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Check your auth token');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to send notification');
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
      rethrow;
    }
  }

// Special function for child added notification
  static Future<void> sendChildAddedNotification({
    required String parentToken,
    required String childName,
    required String childId,
  }) async {
    try {
      print('👶 Sending child added notification...');

      await sendNotification(
        token: parentToken,
        title: '🎓 New Child Registered',
        body: '$childName has been registered in the system',
        data: {
          'type': 'child_added',
          'childId': childId,
          'childName': childName,
          'action': 'view_child',
        },
      );

      print('✅ Child notification sent successfully');
    } catch (e) {
      print('⚠️ Failed to send child notification (continuing anyway): $e');
      // Don't stop the process if notifications fail
    }
  }

// Special function for session booking notification
  static Future<void> sendSessionBookedNotification({
    required String specialistToken,
    required String childName,
    required String date,
    required String time,
    required String sessionId,
  }) async {
    try {
      print('📅 Sending session booked notification...');

      await sendNotification(
        token: specialistToken,
        title: '📅 New Session Booked',
        body: 'Session on $date at $time for child $childName',
        data: {
          'type': 'session_booked',
          'childName': childName,
          'sessionDate': date,
          'sessionTime': time,
          'sessionId': sessionId,
          'action': 'view_schedule',
        },
      );

      print('✅ Session notification sent successfully');
    } catch (e) {
      print('⚠️ Failed to send session notification (continuing anyway): $e');
      // Don't stop the process if notifications fail
    }
  }
// 3. Restore archived child
  static Future<Map<String, dynamic>> restoreArchivedChild(int childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/child/$childId/restore'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': 'Approved', // هذا هو الاسم الحقيقي في الداتابيز Approved
        }),
      );

      print('Restore Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        throw Exception('Cannot restore child');
      } else if (response.statusCode == 404) {
        throw Exception('Child not found');
      } else if (response.statusCode == 403) {
        throw Exception('You are not authorized to perform this action');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to restore child');
      }
    } catch (e) {
      print('Error in restoreArchivedChild: $e');
      rethrow;
    }
  }

}