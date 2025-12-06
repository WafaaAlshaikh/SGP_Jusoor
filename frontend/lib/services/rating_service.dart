// lib/services/rating_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RatingService {
  static const String baseUrl = 'http://10.0.2.2:5000';

  // ==================== تقييمات الجلسات ====================
  static Future<Map<String, dynamic>> rateSession({
    required String sessionId,
    required double rating,
    String? comment,
    String? ratingTag,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/ratings/sessions/$sessionId/rate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rating': rating,
          'comment': comment,
          'rating_tag': ratingTag,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Session rated successfully',
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to rate session');
      }
    } catch (e) {
      print('❌ Error rating session: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getSessionRatings(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/sessions/$sessionId/ratings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting session ratings: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getSpecialistRatings(
    String specialistId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/specialists/$specialistId/ratings?page=$page&limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting specialist ratings: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMyRatings({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/my-ratings?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 My Ratings Response status: ${response.statusCode}');
      print('📡 My Ratings Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Ratings loaded successfully',
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to load ratings');
      }
    } catch (e) {
      print('❌ Error getting my ratings: $e');
      rethrow;
    }
  }

  // ==================== مراجعات المؤسسة ====================
  static Future<Map<String, dynamic>> addInstitutionReview({
  required String institutionId,
  required double facilitiesRating,
  required double staffRating,
  required double cleanlinessRating,  // ⬅️ تأكد من هذا الاسم
  required double accessibilityRating, // ⬅️ تأكد من هذا الاسم
  String? reviewText,
  bool wouldRecommend = true,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      throw Exception('No authentication token found');
    }

    print('📤 Adding institution review for ID: $institutionId');
    print('📊 Ratings: staff=$staffRating, facilities=$facilitiesRating, '
        'cleanliness=$cleanlinessRating, accessibility=$accessibilityRating');

    // تحويل القيم إلى double للتأكد
    final Map<String, dynamic> requestBody = {
      'staff_rating': staffRating.toDouble(),
      'facilities_rating': facilitiesRating.toDouble(),
      'cleanliness_rating': cleanlinessRating.toDouble(),  // ⬅️ استخدم هذا الاسم
      'accessibility_rating': accessibilityRating.toDouble(), // ⬅️ استخدم هذا الاسم
      'would_recommend': wouldRecommend,
    };

    // أضف review_text فقط إذا كان غير فارغ
    if (reviewText != null && reviewText.trim().isNotEmpty) {
      requestBody['review_text'] = reviewText.trim();
    }

    print('📦 Request body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse('$baseUrl/api/ratings/institutions/$institutionId/reviews'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body}');

    final data = jsonDecode(response.body);
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      return {
        'success': true,
        'data': data['data'],
        'message': data['message'] ?? 'Review added successfully',
      };
    } else {
      throw Exception(data['message'] ?? 'Failed to add review');
    }
  } catch (e) {
    print('❌ Error adding institution review: $e');
    rethrow;
  }
}
  // في دالة getInstitutionReviews في rating_service.dart
  static Future<Map<String, dynamic>> getInstitutionReviews(
      String institutionId, {
        int page = 1,
        int limit = 10,
        String sort = 'newest',
      }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final url = Uri.parse('$baseUrl/api/ratings/institutions/$institutionId/reviews')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
      });

      print('📡 Fetching reviews from: $url');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      print('📥 Reviews response status: ${response.statusCode}');
      print('📥 Reviews response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // 🔴 تحويل البيانات من String إلى double بشكل صحيح
        final reviewsData = data['data'];

        // تحويل التقييمات من String إلى double
        final List<Map<String, dynamic>> reviews = [];
        if (reviewsData['reviews'] != null) {
          for (var review in reviewsData['reviews']) {
            reviews.add({
              'id': review['id'],
              'overall_rating': _parseRating(review['overall_rating']),
              'facilities_rating': _parseRating(review['facilities_rating']),
              'staff_rating': _parseRating(review['staff_rating']),
              'cleanliness_rating': _parseRating(review['cleanliness_rating']),
              'accessibility_rating': _parseRating(review['accessibility_rating']),
              'review_text': review['review_text'],
              'would_recommend': review['would_recommend'],
              'based_on_visits': review['based_on_visits'],
              'date': review['date'],
              'parent_name': review['parent_name'],
            });
          }
        }

        return {
          'success': true,
          'data': {
            'reviews': reviews,
            'statistics': {
              'average_rating': _parseRating(reviewsData['statistics']['average_rating']),
              'total_reviews': reviewsData['statistics']['total_reviews'],
              'recommendation_rate': reviewsData['statistics']['recommendation_rate'],
              'category_averages': {
                'facilities': _parseRating(reviewsData['statistics']['category_averages']['facilities']),
                'staff': _parseRating(reviewsData['statistics']['category_averages']['staff']),
                'cleanliness': _parseRating(reviewsData['statistics']['category_averages']['cleanliness']),
                'accessibility': _parseRating(reviewsData['statistics']['category_averages']['accessibility']),
              }
            },
            'pagination': reviewsData['pagination'],
          },
          'message': data['message'] ?? 'Reviews loaded successfully',
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to load reviews');
      }
    } catch (e) {
      print('❌ Error getting institution reviews: $e');
      rethrow;
    }
  }

// دالة مساعدة لتحويل التقييمات
  static double _parseRating(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  static Future<Map<String, dynamic>> getMyInstitutionReviews({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/my-institution-reviews?page=$page&limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting my institution reviews: $e');
      rethrow;
    }
  }

  // ==================== ملاحظات الأخصائيين ====================
  static Future<Map<String, dynamic>> submitSpecialistFeedback({
    required int specialistId,
    required double professionalismScore,
    required double communicationScore,
    required double knowledgeScore,
    required double punctualityScore,
    String? strengths,
    String? improvementsNeeded,
    bool wouldContinue = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/ratings/specialists/feedback'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'specialist_id': specialistId,
          'professionalism_score': professionalismScore,
          'communication_score': communicationScore,
          'knowledge_score': knowledgeScore,
          'punctuality_score': punctualityScore,
          'strengths': strengths,
          'improvements_needed': improvementsNeeded,
          'would_continue': wouldContinue,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Your feedback has been submitted successfully',
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to submit feedback');
      }
    } catch (e) {
      print('❌ Error submitting specialist feedback: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMyFeedbacks({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/my-feedbacks?page=$page&limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting my feedbacks: $e');
      rethrow;
    }
  }

  // ==================== إحصائيات المدير ====================
  static Future<Map<String, dynamic>> getRatingDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/manager/rating-dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting rating dashboard: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getSpecialistDetailedReport(String specialistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/manager/specialists/$specialistId/report'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting specialist report: $e');
      rethrow;
    }
  }
}