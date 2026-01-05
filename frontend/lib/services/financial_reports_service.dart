import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for calling manager financial reports endpoints
/// Backed by Backend/controllers/financialReportsController.js
class FinancialReportsService {
  static String get _baseUrl {
  if (kIsWeb) {
    return 'http://localhost:5000/api';
  } else {
    return 'http://10.0.2.2:5000/api';
  }
}

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // الحصول على الـ Headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ==================== التقارير الرئيسية ====================

  // التقرير المالي الشهري الكامل
  // تحديث جميع الدوال لاستخدام التحويل الآمن

  static Future<Map<String, dynamic>> getMonthlyFinancialReport({
    int? year,
    int? month,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{};
      if (year != null) params['year'] = year.toString();
      if (month != null) params['month'] = month.toString();

      final uri = Uri.parse('$_baseUrl/financial-reports/monthly')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          return _processApiData(data['data'] as Map<String, dynamic>);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch report');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching monthly financial report: $e');
      rethrow;
    }
  }

  // دالة مساعدة لمعالجة البيانات من API
  static Map<String, dynamic> _processApiData(Map<String, dynamic> data) {
    return _convertNumbersToDouble(data);
  }

  static Map<String, dynamic> _convertNumbersToDouble(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    result.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = _convertNumbersToDouble(value);
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _convertNumbersToDouble(item);
          } else if (item is int) {
            return item.toDouble();
          }
          return item;
        }).toList();
      } else if (value is int) {
        result[key] = value.toDouble();
      }
    });

    return result;
  }

  // تقرير مالي شامل (V2) - endpoint موحد للشاشة المتقدمة
  static Future<Map<String, dynamic>> getAdvancedFinancialReportV2({
    String? startDate,
    String? endDate,
    int? year,
    int? month,
    int? limitInvoices,
    int? limitSpecialists,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{};

      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;
      if (year != null) params['year'] = year.toString();
      if (month != null) params['month'] = month.toString();
      if (limitInvoices != null) params['limit_invoices'] = limitInvoices.toString();
      if (limitSpecialists != null) {
        params['limit_specialists'] = limitSpecialists.toString();
      }

      final uri = Uri.parse('$_baseUrl/financial-reports/advanced-v2')
          .replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          return _processApiData(data['data'] as Map<String, dynamic>);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch advanced financial report (V2)');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching advanced financial report V2: $e');
      rethrow;
    }
  }

  // تقرير تدفق الأموال
  static Future<Map<String, dynamic>> getFinancialFlowReport({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;

      final uri = Uri.parse('$_baseUrl/financial-reports/flow')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch flow report');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching financial flow report: $e');
      rethrow;
    }
  }

  // تقرير الفواتير والمدفوعات (Invoices & Payments)
  static Future<Map<String, dynamic>> getInvoicesPaymentsReport({
    int? year,
    int? month,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{};
      if (year != null) params['year'] = year.toString();
      if (month != null) params['month'] = month.toString();

      final uri = Uri.parse('$_baseUrl/financial-reports/invoices-payments')
          .replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch invoices & payments report');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching invoices & payments report: $e');
      rethrow;
    }
  }

  // الوضع المالي الحالي (Dashboard)
  static Future<Map<String, dynamic>> getCurrentFinancialStatus() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/financial-reports/current-status'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch current status');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching current financial status: $e');
      rethrow;
    }
  }

  // ==================== التقارير التفصيلية ====================

  // تقرير تفصيلي عن المساعدات المالية
  static Future<Map<String, dynamic>> getFinancialAssistanceDetailedReport({
    String? startDate,
    String? endDate,
    String? status,
    String? tier,
    double? minDiscount,
    double? maxDiscount,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;
      if (status != null) params['status'] = status;
      if (tier != null) params['tier'] = tier;
      if (minDiscount != null) params['min_discount'] = minDiscount.toString();
      if (maxDiscount != null) params['max_discount'] = maxDiscount.toString();

      final uri = Uri.parse('$_baseUrl/financial-reports/assistance-detailed')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch assistance report');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching assistance detailed report: $e');
      rethrow;
    }
  }

  // تقرير التبرعات والتمويل
  static Future<Map<String, dynamic>> getDonationsAndFundingReport({
    String? startDate,
    String? endDate,
    bool includeCampaigns = false,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{
        'include_campaigns': includeCampaigns.toString(),
      };
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;

      final uri = Uri.parse('$_baseUrl/financial-reports/donations-funding')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch donations report');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching donations and funding report: $e');
      rethrow;
    }
  }

  // تحليل الدخل والنفقات
  static Future<Map<String, dynamic>> getIncomeExpenseAnalysis({
    int? year,
    bool detailed = false,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{
        'detailed': detailed.toString(),
      };
      if (year != null) params['year'] = year.toString();

      final uri = Uri.parse('$_baseUrl/financial-reports/income-expense')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch income expense analysis');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching income expense analysis: $e');
      rethrow;
    }
  }

  // تقرير مالي متقدم (إيرادات الجلسات + رواتب الأخصائيين + ملخص التبرعات)
  static Future<Map<String, dynamic>> getAdvancedFinancialReport({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;

      final uri = Uri.parse('$_baseUrl/financial-reports/advanced')
          .replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch advanced financial report');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching advanced financial report: $e');
      rethrow;
    }
  }

  // نظرة عامة على المساعدات المالية للعائلات
  static Future<Map<String, dynamic>> getFamilyAssistanceOverview({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;

      final uri = Uri.parse('$_baseUrl/financial-reports/family-assistance/overview')
          .replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch family assistance overview');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching family assistance overview: $e');
      rethrow;
    }
  }

  // ==================== تصدير التقارير ====================

  // تصدير التقرير بصيغة Excel
  static Future<List<int>> exportToExcel({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;

      final uri = Uri.parse('$_baseUrl/financial-reports/export/excel')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      rethrow;
    }
  }

  // تصدير التقرير بصيغة PDF
  static Future<String> exportToPDF({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;

      final uri = Uri.parse('$_baseUrl/financial-reports/export/pdf')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error exporting to PDF: $e');
      rethrow;
    }
  }

  // ==================== التنبيهات والإحصائيات ====================

  // الحصول على التنبيهات المالية
  static Future<List<dynamic>> getFinancialAlerts() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/financial-reports/alerts'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as List<dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch alerts');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching financial alerts: $e');
      rethrow;
    }
  }

  // إحصائيات سريعة
  static Future<Map<String, dynamic>> getQuickStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/financial-reports/quick-stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch quick stats');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching quick stats: $e');
      rethrow;
    }
  }

  // تقرير مبسط للجوال
  static Future<Map<String, dynamic>> getMobileSummary() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/financial-reports/mobile-summary'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch mobile summary');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching mobile summary: $e');
      rethrow;
    }
  }

  // الجدول الزمني المالي
  static Future<Map<String, dynamic>> getFinancialTimeline({
    int months = 6,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{
        'months': months.toString(),
      };

      final uri = Uri.parse('$_baseUrl/financial-reports/timeline')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch timeline');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching financial timeline: $e');
      rethrow;
    }
  }

  // فحص صحة البيانات المالية
  static Future<Map<String, dynamic>> getFinancialHealthCheck() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/financial-reports/health-check'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch health check');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching financial health check: $e');
      rethrow;
    }
  }

  // تقرير مالي تفصيلي (Detailed Financial Report)
static Future<Map<String, dynamic>> getDetailedFinancialReport({
  int? year,
}) async {
  try {
    final headers = await _getHeaders();
    final params = <String, String>{};
    if (year != null) params['year'] = year.toString();

    final uri = Uri.parse('$_baseUrl/financial-reports/detailed')
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        // تحويل الأرقام إلى double لسهولة العرض
        return _convertNumbersToDouble(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      } else {
        throw Exception(
            data['message'] ?? 'Failed to fetch detailed financial report');
      }
    } else {
      throw Exception('HTTP Error ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching detailed financial report: $e');
    rethrow;
  }
}
}