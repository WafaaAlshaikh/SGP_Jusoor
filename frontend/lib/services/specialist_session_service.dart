import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SpecialistSessionService {
  // 🔥 تحديد الـ baseUrl بناءً على المنصة
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api'; // للويب
    } else {
      return 'http://10.0.2.2:5000/api'; // للموبايل
    }
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ✅ 1. جلب كل الجلسات - المحدثة
  static Future<List<Map<String, dynamic>>> getSessions() async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.get(
      Uri.parse('$baseUrl/specialist/sessions'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((session) {
        return {
          'id': session['session_id'],
          'childName': session['child']?['full_name'] ?? 'Unknown',
          'institution': session['institution']?['name'] ?? 'N/A',
          'type': session['SessionType']?['name'] ?? session['session_type'] ?? 'Therapy',
          'date': DateTime.parse(session['date']),
          'time': session['time'] ?? '00:00',
          'mode': session['session_type'] ?? 'Onsite',
          'status': session['status'] ?? 'Pending Approval',
          'session_type_id': session['session_type_id'],
          'duration': session['SessionType']?['duration'] ?? 60,
          'category': session['SessionType']?['category'] ?? 'General',
          'child_id': session['child_id'],
          'institution_id': session['institution_id'],
          'delete_request': session['delete_request'] ?? false,
          'delete_status': session['delete_status'] ?? 'None',
        };
      }).toList();
    } else {
      throw Exception('Failed to fetch sessions: ${response.statusCode}');
    }
  }

  // ✅ 2. جلب الجلسات القادمة - المحدثة
  static Future<List<Map<String, dynamic>>> getUpcomingSessions() async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.get(
      Uri.parse('$baseUrl/specialist/sessions/upcoming'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((session) {
        return {
          'id': session['session_id'],
          'childName': session['child']?['full_name'] ?? 'Unknown',
          'institution': session['institution']?['name'] ?? 'N/A',
          'type': session['SessionType']?['name'] ?? session['session_type'] ?? 'Therapy',
          'date': DateTime.parse(session['date']),
          'time': session['time'] ?? '00:00',
          'mode': session['session_type'] ?? 'Onsite',
          'status': session['status'] ?? 'Scheduled',
          'duration': session['SessionType']?['duration'] ?? 60,
        };
      }).toList();
    } else {
      throw Exception('Failed to fetch upcoming sessions: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> requestSessionUpdate({
    required int sessionId,
    required DateTime date,
    required String time,
    required String status,
    required String sessionType,
    String? reason,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.post(
      Uri.parse('$baseUrl/specialist/sessions/$sessionId/request-update'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'date': date.toIso8601String().split('T')[0],
        'time': time,
        'status': status,
        'session_type': sessionType,
        'reason': reason,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to request session update: ${response.statusCode} - ${response.body}');
    }
  }

  // ✅ 4. طلب حذف الجلسة - المحدثة مع السبب
  static Future<Map<String, dynamic>> requestDeleteSession(int sessionId, {String? reason}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.post(
      Uri.parse('$baseUrl/specialist/sessions/$sessionId/delete-request'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reason': reason, // ⭐ إرسال السبب (اختياري)
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to request delete: ${response.statusCode} - ${response.body}');
    }
  }

  // ✅ 5. إكمال جلسات اليوم - المحدثة
  static Future<Map<String, dynamic>> completeTodaySessions() async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.post(
      Uri.parse('$baseUrl/specialist/sessions/complete-today'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to complete today sessions: ${response.statusCode} - ${response.body}');
    }
  }

  // ✅ 6. جلب التقرير الشهري - المحدثة
  static Future<Map<String, dynamic>> getMonthlyReport({int? month, int? year}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    String url = '$baseUrl/specialist/sessions/monthly-report';
    if (month != null || year != null) {
      final params = <String>[];
      if (month != null) params.add('month=$month');
      if (year != null) params.add('year=$year');
      url += '?${params.join('&')}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get monthly report: ${response.statusCode} - ${response.body}');
    }
  }

  // ✅ 7. جلب الإحصائيات السريعة - المحدثة
  static Future<Map<String, dynamic>> getQuickStats() async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.get(
      Uri.parse('$baseUrl/specialist/sessions/quick-stats'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get quick stats: ${response.statusCode} - ${response.body}');
    }
  }

  // ✅ 8. ضبط التذكيرات - المحدثة
  static Future<Map<String, dynamic>> setReminders(int reminderTime) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.post(
      Uri.parse('$baseUrl/specialist/sessions/reminders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reminderTime': reminderTime,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to set reminders: ${response.statusCode} - ${response.body}');
    }
  }

  // ✅ 9. جلب تفاصيل اجتماع الزوم - المحدثة
  static Future<Map<String, dynamic>> getZoomMeetingDetails(int sessionId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.get(
      Uri.parse('$baseUrl/specialist/sessions/$sessionId/join-zoom'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get zoom meeting details: ${response.statusCode} - ${response.body}');
    }
  }

  // ✅ 10. الانضمام إلى جلسة زوم مباشرة - المحدثة
  static Future<void> joinAndOpenZoomSession(int sessionId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/specialist/sessions/$sessionId/join-zoom'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final meeting = data['meeting'];

        final url = meeting['joinUrl'] ?? meeting['join_url'] ?? '';
        final meetingId = meeting['meetingId'] ?? meeting['meeting_id'] ?? '';
        final password = meeting['password'] ?? '';
        final startTime = meeting['startTime'] ?? meeting['start_time'] ?? '';

        print('Zoom URL: $url');
        print('Zoom Meeting ID: $meetingId');
        print('Password: $password');
        print('Start Time: $startTime');

        if (url.isNotEmpty) {
          // محاولة فتح الرابط مباشرة
          if (await canLaunch(url)) {
            await launch(url);
            print('Successfully launched Zoom URL');
          } else {
            print('Could not launch URL directly, trying Zoom app...');
            // إذا فشل فتح الرابط المباشر، حاول فتح تطبيق Zoom
            final zoomAppUrl = 'zoomus://zoom.us/join?confno=$meetingId';
            if (await canLaunch(zoomAppUrl)) {
              await launch(zoomAppUrl);
              print('Successfully launched Zoom app');
            } else {
              print('Could not launch Zoom app, trying Play Store...');
              // إذا فشل فتح التطبيق، افتح متجر التطبيقات
              final zoomStoreUrl = 'https://play.google.com/store/apps/details?id=us.zoom.videomeetings';
              if (await canLaunch(zoomStoreUrl)) {
                await launch(zoomStoreUrl);
              } else {
                throw 'Could not launch Zoom. Please install Zoom app from Play Store.';
              }
            }
          }
        } else {
          throw 'No Zoom URL available in the response';
        }
      } else {
        throw Exception('Failed to join zoom session: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in joinAndOpenZoomSession: $e');
      rethrow;
    }
  }

  // ✅ 12. الموافقة على الجلسة المعلقة - جديدة
  static Future<Map<String, dynamic>> approvePendingSession(int pendingSessionId, bool approve) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.post(
      Uri.parse('$baseUrl/specialist/sessions/pending/$pendingSessionId/approve'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'approve': approve,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to approve/reject session: ${response.statusCode} - ${response.body}');
    }
  }

  // ✅ 15. جلب الجلسات المطلوب حذفها - النسخة النهائية
  static Future<List<Map<String, dynamic>>> getDeleteRequestedSessions() async {
    final token = await _getToken();
    if (token == null) throw Exception('Token not found');

    final response = await http.get(
      Uri.parse('$baseUrl/specialist/delete-requests'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List sessions = data['sessions'] ?? [];

      return sessions.map((session) {
        return {
          'id': session['session_id'],
          'childName': session['child']?['full_name'] ?? 'Unknown',
          'institution': session['institution']?['name'] ?? 'N/A',
          'type': session['SessionType']?['name'] ?? 'Therapy',
          'date': DateTime.parse(session['date']),
          'time': session['time'] ?? '00:00',
          'status': session['status'] ?? 'Cancelled',
          'mode': session['session_type'] ?? 'Onsite',
          'delete_request': session['delete_request'] ?? false,
          'delete_status': session['delete_status'] ?? 'Pending',
          'reason': session['reason'], // ⭐ السبب
          'duration': session['SessionType']?['duration'] ?? 60,
          'category': session['SessionType']?['category'] ?? 'General',
        };
      }).toList();
    } else {
      throw Exception('Failed to fetch deleted sessions: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingUpdateRequests() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Token not found');

      // 🔥 تأكدي من الرابط - غالباً بيكون هيك:
      final response = await http.get(
        Uri.parse('$baseUrl/specialist/pending-updates'), // ⚠️ تأكدي من الرابط
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Found ${data.length} pending sessions from API');

        return data.map((session) {
          // 🔥 طباعة البيانات علشان نتأكد من التركيب
          print('📋 Session Data Structure:');
          print('  - session_id: ${session['session_id']}');
          print('  - date: ${session['date']}');
          print('  - time: ${session['time']}');
          print('  - child: ${session['child']?['full_name']}');
          print('  - originalSession: ${session['originalSession']}');
          if (session['originalSession'] != null) {
            print('  - originalSession.date: ${session['originalSession']?['date']}');
            print('  - originalSession.time: ${session['originalSession']?['time']}');
          }

          // 🔥 الجلسة المعدلة (الجديدة)
          final newDate = DateTime.parse(session['date']);
          final newTime = session['time'];

          // 🔥 الجلسة الأصلية (القديمة)
          final originalSession = session['originalSession'];
          final originalDate = originalSession?['date'] != null
              ? DateTime.parse(originalSession['date'])
              : newDate; // إذا مافي بيانات أصلية، استخدمي الجديدة
          final originalTime = originalSession?['time'] ?? newTime;

          print('🔄 Processing: ${session['child']?['full_name']}');
          print('   - New: $newDate at $newTime');
          print('   - Original: $originalDate at $originalTime');
          print('   - Reason: ${session['reason']}');

          return {
            'id': session['session_id'],
            'childName': session['child']?['full_name'] ?? 'Unknown Child',
            'institution': session['institution']?['name'] ?? 'Unknown Institution',
            'type': session['SessionType']?['name'] ?? session['session_type'] ?? 'Therapy',

            // 🔥 الجلسة الجديدة (المعدلة) - الموعد الجديد
            'date': newDate,
            'time': newTime,

            'status': session['status'] ?? 'Pending Approval',
            'mode': session['session_type'] ?? 'Onsite',
            'duration': session['SessionType']?['duration'] ?? 60,
            'category': session['SessionType']?['category'] ?? 'General',
            'isPending': true,

            // 🔥 الجلسة الأصلية (القديمة) - الموعد القديم
            'originalSessionId': session['original_session_id'],
            'originalDate': originalDate,
            'originalTime': originalTime,

            'Reason': session['reason'] ?? 'Waiting for parent approval',
            'updateReason': session['reason'],
          };
        }).toList();
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch pending requests: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getPendingUpdateRequests: $e');
      return [];
    }
  }

  // ✅ 14. دالة مساعدة لتنسيق بيانات الجلسة - جديدة
  static Map<String, dynamic> _formatSessionData(dynamic session) {
    return {
      'id': session['session_id'],
      'childName': session['child']?['full_name'] ?? 'Unknown Child',
      'institution': session['institution']?['name'] ?? 'Unknown Institution',
      'type': session['session_type'] ?? 'Session',
      'date': DateTime.parse(session['date']),
      'time': session['time'],
      'status': session['status'],
      'mode': session['session_type'],
      'duration': session['session_type_details']?['duration'] ?? 60,
      'category': session['session_type_details']?['category'],
      'isPending': session['is_pending'] ?? false,
      'originalSessionId': session['original_session_id'],
      'originalDate': session['originalSession']?['date'] != null
          ? DateTime.parse(session['originalSession']['date'])
          : null,
      'originalTime': session['originalSession']?['time'],
      'Reason': session['reason'] ?? 'Rescheduling requested by specialist',
    };
  }
}