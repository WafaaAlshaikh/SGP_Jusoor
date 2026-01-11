// lib/services/notification_shared_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSharedService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api';

  /// إرسال إشعار
  static Future<Map<String, dynamic>> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null) {
        throw Exception('❌ No authentication token found in SharedPreferences');
      }

      print('📤 Sending notification via API...');
      print('Title: $title');
      print('Body: $body');
      print('Token: ${fcmToken.substring(0, 20)}...');
      print('Data: $data');

      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/test'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken', // ✅ Added auth header
        },
        body: json.encode({
          'token': fcmToken,
          'title': title,
          'body': body,
          ...(data ?? {}),
        }),
      );

      print('📥 Notification response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final respData = json.decode(response.body);
        return respData;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to send notification');
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
      rethrow;
    }
  }

  /// إشعار إضافة طفل
  static Future<void> sendChildAddedNotification({
    required String parentToken,
    required String childName,
    required String childId,
  }) async {
    try {
      print('👶 Sending child added notification...');
      await sendNotification(
        fcmToken: parentToken,
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
      print('⚠️ Failed to send child notification: $e');
    }
  }

  /// إشعار حجز جلسة
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
        fcmToken: specialistToken,
        title: '📅 New Session Booked',
        body: 'Session on $date $time for child $childName',
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
      print('⚠️ Failed to send session notification: $e');
    }
  }

  /// إشعارات الجداول
  static Future<void> sendScheduleNotification({
    required String specialistToken,
    required String action,
    required String dayOfWeek,
    String? startTime,
    String? endTime,
    int? numberOfSchedules,
  }) async {
    try {
      print('📅 Sending schedule notification...');
      String title;
      String body;
      Map<String, String> data = {
        'type': 'schedule_change',
        'action': action,
        'day_of_week': dayOfWeek,
        'timestamp': DateTime.now().toString(),
      };

      switch (action) {
        case 'added':
          title = '📅 New Schedule Added';
          body = 'New schedule added for $dayOfWeek: $startTime - $endTime';
          data['start_time'] = startTime!;
          data['end_time'] = endTime!;
          break;
        case 'updated':
          title = '🔄 Schedule Updated';
          body = 'Schedule for $dayOfWeek has been updated';
          if (startTime != null) data['start_time'] = startTime;
          if (endTime != null) data['end_time'] = endTime;
          break;
        case 'deleted':
          title = '🗑️ Schedule Deleted';
          body = 'Schedule for $dayOfWeek has been deleted';
          break;
        case 'bulk_added':
          title = '📋 Multiple Schedules Added';
          body = '$numberOfSchedules schedules have been added';
          data['count'] = numberOfSchedules.toString();
          break;
        default:
          title = '📅 Schedule Modified';
          body = 'Your schedule has been modified';
      }

      await sendNotification(
        fcmToken: specialistToken,
        title: title,
        body: body,
        data: data,
      );

      print('✅ Schedule notification sent successfully');
    } catch (e) {
      print('⚠️ Failed to send schedule notification: $e');
    }
  }

  static Future<void> sendManagerApprovalNotification({
  required String managerToken,
  required String childName,
  required String institutionName,
  required String childId,
  String? specialistName,
  String? sessionDate,
  String? sessionTime,
  String? sessionId,
}) async {
  try {
    print('👨‍💼 Sending manager approval notification...');
    await sendNotification(
      fcmToken: managerToken,
      title: '✅ Automatic approval for child registration',
      body:
          'The child $childName has been automatically approved at $institutionName',
      data: {
        'type': 'child_auto_approved',
        'child_name': childName,
        'institution_name': institutionName,
        'child_id': childId,
        'specialist_name': specialistName ?? '',
        'session_date': sessionDate ?? '',
        'session_time': sessionTime ?? '',
        'session_id': sessionId ?? '',
        'action': 'view_pending_registrations',
        'channel': 'manager_channel',
      },
    );
    print('✅ Manager approval notification sent successfully');
  } catch (e) {
    print('⚠️ Failed to send manager approval notification: $e');
  }
}
}