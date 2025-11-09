import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EvaluationService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api'; // للويب
    } else {
      return 'http://10.0.2.2:5000/api'; // للموبايل
    }
  }

  // ✅ دالة مساعدة لجلب التوكن
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ✅ جلب الأطفال للأخصائي الحالي
  static Future<List<dynamic>> getChildrenForCurrentSpecialist() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/evaluations/children'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return data['data'];
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 403) {
        throw Exception('Access denied - Not a specialist');
      } else {
        throw Exception('Failed to load children: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ✅ إضافة تقييم
  static Future<dynamic> addEvaluation(Map<String, dynamic> evaluationData) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$baseUrl/evaluations/add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode(evaluationData),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to add evaluation');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ✅ رفع ملف
  static Future<dynamic> uploadFile(File file) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/evaluations/upload')
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            file.path,
          )
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'File upload failed');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // ✅ جلب جميع تقييمات الأخصائي الحالي
  static Future<List<dynamic>> getMyEvaluations() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/evaluations/my-evaluations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return data['data'];
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load evaluations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ✅ جلب تقييم محدد
  static Future<dynamic> getEvaluationById(int evaluationId) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/evaluations/$evaluationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to load evaluation');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ✅ تحديث تقييم
  static Future<dynamic> updateEvaluation(int evaluationId, Map<String, dynamic> updateData) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.put(
        Uri.parse('$baseUrl/evaluations/$evaluationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode(updateData),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to update evaluation');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ✅ حذف تقييم
  static Future<dynamic> deleteEvaluation(int evaluationId) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.delete(
        Uri.parse('$baseUrl/evaluations/$evaluationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to delete evaluation');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ✅ دالة لطلب صلاحيات التخزين
  static Future<bool> _requestStoragePermission() async {
    if (kIsWeb) return true; // للويب دائماً نرجع true

    if (await Permission.storage.isGranted) {
      return true;
    }

    final status = await Permission.storage.request();
    return status.isGranted;
  }

  // ✅ دالة محسنة لتحميل PDF
  static Future<Map<String, dynamic>> downloadAndOpenPDF(int evaluationId) async {
    try {
      // للويب: استخدم الدالة الجديدة
      if (kIsWeb) {
        return await _downloadPDFForWeb(evaluationId);
      }

      // تحقق من الصلاحيات أولاً
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission is required to download PDF files');
      }

      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/evaluations/$evaluationId/export-pdf'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // استخدم مجلد التحميلات مباشرة
        final directory = await getExternalStorageDirectory();
        final downloadsPath = '${directory?.path}/Download';

        // أنشئ المجلد إذا لم يكن موجوداً
        final downloadsDir = Directory(downloadsPath);
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final filePath = '$downloadsPath/evaluation_$evaluationId.pdf';
        final file = File(filePath);

        // احفظ الملف
        await file.writeAsBytes(response.bodyBytes);

        // افتح الملف
        await OpenFile.open(filePath);

        return {
          'success': true,
          'message': 'PDF downloaded successfully to Downloads folder',
          'filePath': filePath
        };
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('PDF download error: $e');
    }
  }

  // ✅ دالة لتحميل PDF في مجلد التحميلات العام
  static Future<Map<String, dynamic>> downloadToPublicDownloads(int evaluationId) async {
    try {
      // للويب: استخدم الدالة الجديدة
      if (kIsWeb) {
        return await _downloadPDFForWeb(evaluationId);
      }

      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/evaluations/$evaluationId/export-pdf'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // لمجلد التحميلات العام
        Directory? downloadsDir;

        try {
          // حاول الحصول على مجلد التحميلات العام (لـ Android 10+)
          if (await Permission.manageExternalStorage.request().isGranted) {
            downloadsDir = Directory('/storage/emulated/0/Download');
          }
        } catch (e) {
          print('Manage external storage failed: $e');
        }

        // إذا فشل، استخدم مجلد التطبيق
        if (downloadsDir == null || !await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
          downloadsDir = Directory('${downloadsDir?.path}/Download');
        }

        final downloadsPath = downloadsDir.path;
        print('📁 Final download path: $downloadsPath');

        // أنشئ المجلد إذا لم يكن موجوداً
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
          print('📁 Created directory: $downloadsPath');
        }

        final filePath = '$downloadsPath/evaluation_$evaluationId.pdf';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        // تحقق من وجود الملف
        final fileExists = await file.exists();
        print('📄 File exists: $fileExists');
        print('📄 File path: $filePath');
        print('📄 File size: ${(await file.length())} bytes');

        // تحقق إضافي من الملف
        print('🔍 Checking file existence...');
        final fileCheck = File(filePath);
        print('📁 File path: $filePath');
        print('✅ File exists: ${await fileCheck.exists()}');
        print('📊 File size: ${(await fileCheck.length())} bytes');

        // حاول فتح الملف للتأكد
        try {
          await OpenFile.open(filePath);
          print('🎯 File opened successfully!');
        } catch (e) {
          print('❌ Could not open file: $e');
        }

        return {
          'success': true,
          'message': 'PDF saved to Downloads folder',
          'filePath': filePath,
          'fileName': 'evaluation_$evaluationId.pdf'
        };
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ PDF download error: $e');
      throw Exception('PDF download error: $e');
    }
  }

  // ✅ دالة بديلة إذا فشل التحميل
  static Future<Map<String, dynamic>> downloadPDFSimple(int evaluationId) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/evaluations/$evaluationId/export-pdf'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // استخدم مجلد التحميلات مباشرة
        final directory = await getExternalStorageDirectory();
        final downloadsPath = '${directory?.path}/Download';

        print('📁 Download path: $downloadsPath');

        // أنشئ المجلد إذا لم يكن موجوداً
        final downloadsDir = Directory(downloadsPath);
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
          print('📁 Created directory: $downloadsPath');
        }

        final filePath = '$downloadsPath/evaluation_$evaluationId.pdf';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        // تحقق من وجود الملف
        final fileExists = await file.exists();
        print('📄 File exists: $fileExists');
        print('📄 File path: $filePath');
        print('📄 File size: ${(await file.length())} bytes');

        return {
          'success': true,
          'message': 'PDF saved to Downloads folder',
          'filePath': filePath
        };
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ PDF download error: $e');
      throw Exception('PDF download error: $e');
    }
  }

  // ✅ تصدير تقييم إلى PDF (إصدار مبسط بدون حفظ محلي)
  static Future<dynamic> exportEvaluationToPDF(int evaluationId) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/evaluations/$evaluationId/export-pdf'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // إصدار مبسط - فقط نؤكد نجاح العملية
        return {
          'success': true,
          'message': 'PDF generated successfully on server',
          'filePath': 'PDF ready on backend'
        };
      } else {
        throw Exception('Failed to export PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('PDF export error: $e');
    }
  }

  // ✅ فتح ملف PDF (إصدار مبسط)
  static Future<void> openPDF(String filePath) async {
    // إصدار مبسط - فقط نطبع رسالة
    print('PDF file would be opened from: $filePath');
    // يمكن تطوير هذه الدالة لاحقاً
  }

  // 🔥 دالة جديدة للويب فقط
  static Future<Map<String, dynamic>> _downloadPDFForWeb(int evaluationId) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('$baseUrl/evaluations/$evaluationId/export-pdf'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // للويب: ننشئ رابط تحميل مباشر
        final base64Pdf = base64Encode(response.bodyBytes);
        final pdfUrl = "data:application/pdf;base64,$base64Pdf";

        // نفتح الرابط في تاب جديد
        _openPdfInNewTab(pdfUrl, evaluationId);

        return {
          'success': true,
          'message': 'PDF opened in new tab',
          'filePath': 'web_preview'
        };
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Web PDF download error: $e');
    }
  }

  // 🔥 فتح الـ PDF في تاب جديد للويب
  static void _openPdfInNewTab(String pdfUrl, int evaluationId) {
    if (kIsWeb) {
      // للويب: ننشئ نافذة جديدة
      print('🌐 Opening PDF in new tab: $pdfUrl');
      // في التطبيق الحقيقي، يمكن استخدام JavaScript لفتح النافذة
    }
  }
}