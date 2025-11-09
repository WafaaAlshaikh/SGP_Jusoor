// services/booking_service.dart
import 'dart:convert';
import 'dart:io'; // ⬅️⬅️⬅️ أضف هذا السطر
import 'package:http/http.dart' as http;
import '../models/booking_models.dart';

class BookingService {


  static Future<List<SessionType>> getSuitableSessionTypes(String token,
      int childId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:5000/api/booking/child/$childId/suitable-session-types'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Suitable Session Types Response: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          final List suitableSessions = data['session_types']['suitable'] ?? [];
          return suitableSessions.map((json) => SessionType.fromJson(json))
              .toList();
        } else {
          throw Exception(
              data['message'] ?? 'Failed to load suitable session types');
        }
      } else {
        throw Exception('Failed to load session types: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading suitable session types: $e');
      rethrow;
    }
  }


  static Future<List<SessionType>> getInstitutionSessionTypes(String token,
      int institutionId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:5000/api/booking/institution-session-types/$institutionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((json) => SessionType.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load session types: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading session types: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAvailableSlots({
    required String token,
    required int institutionId,
    required int sessionTypeId,
    required String date,
  }) async {
    try {
      final uri = Uri.parse('http://10.0.2.2:5000/api/booking/available-slots')
          .replace(
        queryParameters: {
          'institution_id': institutionId.toString(),
          'session_type_id': sessionTypeId.toString(),
          'date': date,
        },
      );

      print('🌐 Fetching available slots: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Response: ${response.statusCode}');
      print('📦 Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to load slots: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error loading slots: $e');
      rethrow;
    }
  }

  static Future<BookingResponse> bookSession({
    required String token,
    required int childId,
    required int institutionId,
    required int sessionTypeId,
    required int specialistId,
    required String date,
    required String time,
    String? parentNotes,
  }) async {
    try {
      final requestBody = {
        'child_id': childId,
        'institution_id': institutionId,
        'session_type_id': sessionTypeId,
        'specialist_id': specialistId,
        'date': date,
        'time': time,
        'parent_notes': parentNotes,
      };

      print('🎯 Booking Request:');
      print(' - Child ID: $childId');
      print(' - Institution ID: $institutionId');
      print(' - Session Type ID: $sessionTypeId');
      print(' - Specialist ID: $specialistId');
      print(' - Date: $date, Time: $time');

      // ⬇️⬇️⬇️ التصحيح هنا - استخدم الـ URL الصحيح
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/booking/book-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Booking Response: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      // ⬇️⬇️⬇️ تحسين معالجة الـ response
      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          return BookingResponse(
            success: true,
            message: responseData['message'] ?? 'Session booked successfully',
            sessionId: responseData['session_id'],
            status: responseData['status'] ?? 'Pending Approval',
            sessionDetails: responseData['session_details'],
          );
        } catch (e) {
          // إذا كان الـ response ليس JSON، ربما يكون خطأ من الخادم
          return BookingResponse(
            success: false,
            message: 'Server error: Invalid response format',
            status: 'Failed',
          );
        }
      } else if (response.statusCode == 404) {
        return BookingResponse(
          success: false,
          message: 'Booking endpoint not found. Please check server configuration.',
          status: 'Failed',
        );
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return BookingResponse(
            success: false,
            message: errorData['message'] ?? 'Failed to book session',
            status: 'Failed',
          );
        } catch (e) {
          return BookingResponse(
            success: false,
            message: 'Server error: ${response.statusCode}',
            status: 'Failed',
          );
        }
      }
    } catch (e) {
      print('❌ Booking error: $e');

      // معالجة أنواع مختلفة من الأخطاء
      if (e is SocketException) {
        return BookingResponse(
          success: false,
          message: 'No internet connection',
          status: 'Failed',
        );
      } else if (e is http.ClientException) {
        return BookingResponse(
          success: false,
          message: 'Network error: ${e.message}',
          status: 'Failed',
        );
      } else {
        return BookingResponse(
          success: false,
          message: 'An unexpected error occurred: ${e.toString()}',
          status: 'Failed',
        );
      }
    }
  }

  // ================= CONFIRM PAYMENT =================
  static Future<Map<String, dynamic>> confirmPayment({
    required String token,
    required int sessionId,
    String paymentMethod = 'Cash',
    String? transactionId,
  }) async {
    try {
      final requestBody = {
        'payment_method': paymentMethod,
        if (transactionId != null) 'transaction_id': transactionId,
      };

      print('💳 Confirming payment for session: $sessionId');
      print(' - Payment Method: $paymentMethod');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/booking/confirm-payment/$sessionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Payment Response: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Payment confirmed successfully',
          'session_id': responseData['session_id'],
          'new_status': responseData['new_status'],
          'session_details': responseData['session_details'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to confirm payment',
        };
      }
    } catch (e) {
      print('❌ Payment error: $e');
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  // ================= CONFIRM PAYMENT V2 (Enhanced) =================
  static Future<Map<String, dynamic>> confirmPaymentV2({
    required String token,
    required int sessionId,
    required Map<String, dynamic> paymentData,
  }) async {
    try {
      print('💳 Confirming payment V2 for session: $sessionId');
      print(' - Payment Data: $paymentData');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/booking/confirm-payment/$sessionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(paymentData),
      );

      print('📡 Payment Response: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Payment confirmed successfully',
          'payment_id': responseData['payment_id'],
          'transaction_id': responseData['transaction_id'],
          'payment_status': responseData['payment_status'],
          'requires_verification': responseData['requires_verification'] ?? false,
          'session_status': responseData['session_status'],
          'session_details': responseData['session_details'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to confirm payment',
        };
      }
    } catch (e) {
      print('❌ Payment error: $e');
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }
}