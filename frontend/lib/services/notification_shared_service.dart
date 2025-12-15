// lib/services/notification_shared_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSharedService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api';

  static Future<Map<String, dynamic>> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null) {
        throw Exception('No authentication token found');
      }

      print('📤 Sending notification via API...');
      print('Title: $title');
      print('Body: $body');
      print('Token: ${token.substring(0, 20)}...');
      print('Data: $data');

      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/test'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'token': token,
          'title': title,
          'body': body,
          ...(data ?? {}),
        }),
      );

      print('📥 Notification response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to send notification');
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
      rethrow;
    }
  }

  // دالة لإشعار إضافة طفل (إذا تحتاجها)
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
    }
  }

  // دالة لإشعار حجز جلسة
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
      print('⚠️ Failed to send session notification (continuing anyway): $e');
    }
  }

  // دالة لإشعارات الجداول
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
        token: specialistToken,
        title: title,
        body: body,
        data: data,
      );

      print('✅ Schedule notification sent successfully');
    } catch (e) {
      print('⚠️ Failed to send schedule notification: $e');
    }
  }
}