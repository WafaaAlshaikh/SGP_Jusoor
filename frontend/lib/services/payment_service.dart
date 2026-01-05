import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/payment_models.dart';

class PaymentService {
  static String get baseUrl {
  if (kIsWeb) {
    return 'http://localhost:5000/api';
  } else {
    return 'http://10.0.2.2:5000/api';
  }
}

  // جلب فواتير ولي الأمر
  static Future<List<Invoice>> getParentInvoices(String token) async {
    try {
      print('🔍 Fetching invoices...');
      final response = await http.get(
        Uri.parse('$baseUrl/payments/invoices'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Invoice Response Status: ${response.statusCode}');
      print('📦 Invoice Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final invoicesData = data['data'] as List;
          print('📊 Number of invoices: ${invoicesData.length}');

          final invoices = invoicesData.map((json) {
            print('🧾 Processing invoice: $json');
            return Invoice.fromJson(json);
          }).toList();

          print('✅ Successfully parsed ${invoices.length} invoices');
          return invoices;
        } else {
          throw Exception(data['message'] ?? 'Failed to load invoices');
        }
      } else {
        throw Exception('HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error loading invoices: $e');
      rethrow;
    }
  }

  // جلب طرق الدفع المتاحة
  static Future<List<PaymentMethod>> getPaymentMethods(String token, {int? invoiceId}) async {
    try {
      print('💳 Fetching payment methods...');
      final response = await http.get(
        Uri.parse('$baseUrl/payments/payment-methods${invoiceId != null ? '?invoice_id=$invoiceId' : ''}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Payment Methods Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final methodsData = data['data']['payment_methods'] as List;
          print('💰 Available payment methods: ${methodsData.length}');

          return List<PaymentMethod>.from(methodsData.map((x) => PaymentMethod.fromJson(x)));
        } else {
          throw Exception(data['message'] ?? 'Failed to load payment methods');
        }
      } else {
        throw Exception('HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error loading payment methods: $e');
      rethrow;
    }
  }

  // معالجة الدفع
  static Future<PaymentResponse> processPayment({
    required String token,
    required int invoiceId,
    required String paymentMethod,
    String? cardToken,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      print('🚀 Processing payment for invoice: $invoiceId');
      print('💳 Payment method: $paymentMethod');

      final response = await http.post(
        Uri.parse('$baseUrl/payments/process-payment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'invoice_id': invoiceId,
          'payment_method': paymentMethod,
          'card_token': cardToken,
          'payment_details': paymentDetails,
        }),
      );

      print('📡 Payment Response Status: ${response.statusCode}');
      print('📦 Payment Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return PaymentResponse.fromJson(data);
      } else {
        throw Exception(data['message'] ?? 'Payment failed');
      }
    } catch (e) {
      print('❌ Error processing payment: $e');
      rethrow;
    }
  }

  // جلب فواتير طفل محدد
  static Future<List<Invoice>> getChildInvoices(String token, int childId) async {
    try {
      print('🔍 Fetching invoices for child: $childId');
      final response = await http.get(
        Uri.parse('$baseUrl/payments/child-invoices/$childId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Child Invoices Response Status: ${response.statusCode}');
      print('📦 Child Invoices Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final invoicesData = data['data'] as List;
          print('📊 Number of invoices for child: ${invoicesData.length}');

          final invoices = invoicesData.map((json) {
            print('🧾 Processing invoice: $json');
            return Invoice.fromJson(json);
          }).toList();

          print('✅ Successfully parsed ${invoices.length} invoices for child');
          return invoices;
        } else {
          throw Exception(data['message'] ?? 'Failed to load child invoices');
        }
      } else {
        throw Exception('HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error loading child invoices: $e');
      rethrow;
    }
  }

  // جلب تفاصيل فاتورة محددة
  static Future<Invoice> getInvoiceDetails(String token, int invoiceId) async {
    try {
      print('🔍 Fetching invoice details: $invoiceId');
      final response = await http.get(
        Uri.parse('$baseUrl/payments/invoices/$invoiceId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return Invoice.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to load invoice details');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading invoice details: $e');
      rethrow;
    }
  }

  // جلب تفاصيل البنك
  static Future<Map<String, dynamic>> getBankDetails(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments/bank-details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to load bank details');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading bank details: $e');
      rethrow;
    }
  }

  // إنشاء توكن بطاقة
  static Future<Map<String, dynamic>> createCardToken({
    required String token,
    required String cardNumber,
    required int expiryMonth,
    required int expiryYear,
    required String cvv,
    required String cardHolder,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/create-card-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'card_number': cardNumber,
          'expiry_month': expiryMonth,
          'expiry_year': expiryYear,
          'cvv': cvv,
          'card_holder': cardHolder,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to create card token');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error creating card token: $e');
      rethrow;
    }
  }
}