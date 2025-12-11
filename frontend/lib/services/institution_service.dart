import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/institution_profile.dart';
class InstitutionService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // === رفع صورة المدير ===
  static Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // إنشاء طلب متعدد الأجزاء (multipart request)
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/manager/upload_profile_picture'),
      );

      // إضافة الهيدر
      request.headers['Authorization'] = 'Bearer $token';

      // إضافة الملف
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          imageFile.path,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      print('Uploading image to: $_baseUrl/manager/upload_profile_picture');
      print('Image path: ${imageFile.path}');

      // إرسال الطلب
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Upload response status: ${response.statusCode}');
      print('Upload response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success']) {
          return {
            'success': true,
            'profile_picture': responseData['data']['profile_picture'],
            'message': responseData['message'],
          };
        } else {
          throw Exception(responseData['message'] ?? 'Failed to upload image');
        }
      } else if (response.statusCode == 400) {
        throw Exception('Invalid image file');
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 413) {
        throw Exception('Image is too large (max 5MB)');
      } else {
        throw Exception('Upload failed: ${responseData['message']}');
      }
    } catch (e) {
      print('Error in uploadProfilePicture: $e');
      rethrow;
    }
  }

  // === دالة مساعدة للتحقق من حجم الصورة ===
  static Future<bool> validateImageSize(File imageFile, {int maxSizeMB = 5}) async {
    try {
      final sizeInBytes = await imageFile.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      return sizeInMB <= maxSizeMB;
    } catch (e) {
      print('Error checking image size: $e');
      return false;
    }
  }

  // === دالة تحويل الصورة إلى Base64 (اختياري) ===
  static Future<String> imageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      rethrow;
    }
  }

  // === دالة محسنة لإعداد بيانات التحديث ===
  static Map<String, dynamic> prepareUpdateData({
    String? description,
    String? location,
    String? locationAddress,
    String? city,
    String? region,
    double? lat,  // إضافة الإحداثيات
    double? lng,  // إضافة الإحداثيات
    String? contactEmail,
    String? contactPhone,
    List<String>? servicesOffered,
    List<String>? conditionsSupported,
    String? managerFullName,
    String? managerPhone,
    String? managerEmail,
  }) {
    final updateData = <String, dynamic>{};

    // Institution data
    if (description != null && description.isNotEmpty) {
      updateData['description'] = description;
    }
    if (location != null && location.isNotEmpty) {
      updateData['location'] = location;
    }
    if (locationAddress != null && locationAddress.isNotEmpty) {
      updateData['location_address'] = locationAddress;
    }
    if (city != null && city.isNotEmpty) {
      updateData['city'] = city;
    }
    if (region != null && region.isNotEmpty) {
      updateData['region'] = region;
    }
    if (lat != null) {
      updateData['lat'] = lat;
    }
    if (lng != null) {
      updateData['lng'] = lng;
    }
    if (contactEmail != null && contactEmail.isNotEmpty) {
      updateData['contact_email'] = contactEmail;
    }
    if (contactPhone != null && contactPhone.isNotEmpty) {
      updateData['contact_phone'] = contactPhone;
    }
    if (servicesOffered != null && servicesOffered.isNotEmpty) {
      updateData['services_offered'] = servicesOffered;
    }
    if (conditionsSupported != null && conditionsSupported.isNotEmpty) {
      updateData['conditions_supported'] = conditionsSupported;
    }

    // Manager data - استخدام الاسم الصحيح الذي يتوقعه الباك إند
    if (managerFullName != null && managerFullName.isNotEmpty) {
      updateData['managerFullName'] = managerFullName;  // camelCase
      updateData['manager_full_name'] = managerFullName; // snake_case (للتوافق)
    }
    if (managerPhone != null && managerPhone.isNotEmpty) {
      updateData['managerPhone'] = managerPhone;
      updateData['manager_phone'] = managerPhone;
    }
    if (managerEmail != null && managerEmail.isNotEmpty) {
      updateData['managerEmail'] = managerEmail;
      updateData['manager_email'] = managerEmail;
    }

    print('Prepared update data: $updateData');
    return updateData;
  }

  // Get institution profile
  static Future<Map<String, dynamic>> getInstitutionProfile() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/manager/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Profile URL: $_baseUrl/manager/profile');
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          return responseData['data'];
        } else {
          throw Exception(responseData['message'] ?? 'Failed to load profile');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Profile not found. Please contact support.');
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getInstitutionProfile: $e');
      rethrow;
    }
  }

  // Update institution AND manager profile
  static Future<Map<String, dynamic>> updateInstitutionProfile(
      Map<String, dynamic> profileData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('Update data to send: $profileData');

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/update_profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(profileData),
      );

      print('Update URL: $_baseUrl/manager/update_profile');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success']) {
          return responseData['data'];
        } else {
          throw Exception(responseData['message'] ?? 'Update failed');
        }
      } else if (response.statusCode == 400) {
        // في حالة أخطاء الفاليديشن
        if (responseData.containsKey('errors')) {
          final errors = responseData['errors'] as List<dynamic>;
          throw Exception(errors.join('\n'));
        }
        throw Exception(responseData['message'] ?? 'Invalid data');
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Update failed: ${responseData['message']}');
      }
    } catch (e) {
      print('Error in updateInstitutionProfile: $e');
      rethrow;
    }
  }

  // Update manager profile picture only (باستخدام رابط)
  static Future<Map<String, dynamic>> updateManagerProfilePicture(
      String profilePictureUrl) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/manager/update_manager_picture'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'profile_picture': profilePictureUrl,
        }),
      );

      print('Update picture URL: $_baseUrl/manager/update_manager_picture');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success']) {
          return responseData['data'];
        } else {
          throw Exception(responseData['message'] ?? 'Failed to update picture');
        }
      } else if (response.statusCode == 400) {
        throw Exception(responseData['message'] ?? 'Invalid image URL');
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to update picture: ${responseData['message']}');
      }
    } catch (e) {
      print('Error in updateManagerProfilePicture: $e');
      rethrow;
    }
  }



  static Future<Map<String, dynamic>> getInstitutionReviews() async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token');

    final response = await http.get(
      Uri.parse('$_baseUrl/manager/reviews'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      if (jsonBody['success'] == true) {
        return jsonBody['data']; // ترجع فقط الجزء data من الresponse
      } else {
        throw Exception(jsonBody['message'] ?? 'Failed to load reviews');
      }
    } else {
      throw Exception('Failed to load reviews: ${response.statusCode}');
    }
  }



}
