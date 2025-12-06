// lib/screens/my_ratings_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/services/rating_service.dart';
import 'package:frontend/models/rating_models.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/debug_service.dart';

class MyRatingsScreen extends StatefulWidget {
  const MyRatingsScreen({Key? key}) : super(key: key);

  @override
  State<MyRatingsScreen> createState() => _MyRatingsScreenState();
}

class _MyRatingsScreenState extends State<MyRatingsScreen> {
  List<SessionRating> _ratings = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // أضيفي هذا للتصحيح
      await DebugService.debugMyRatings();
      _loadRatings();
    });
  }

  // في my_ratings_screen.dart - أصلحي دالة _loadRatings
  Future<void> _loadRatings({int page = 1}) async {
  setState(() {
    _isLoading = true;
    _hasError = false;
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://10.0.2.2:5000/api/ratings/my-ratings'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        // البيانات تأتي مباشرة كمصفوفة
        final items = data['data'] as List;
        
        final ratings = items.map((item) {
          // للبيانات الحالية التي تأتي من الـ API
          return SessionRating(
            id: (item['id'] as int?) ?? 0,
            sessionId: 0, // غير موجود في البيانات الحالية
            specialistId: 0, // غير موجود في البيانات الحالية
            parentId: 0, // غير موجود في البيانات الحالية
            childId: (item['child_id'] as int?) ?? 0,
            rating: (item['rating'] as num?)?.toDouble() ?? 0.0,
            ratingTag: (item['rating_tag'] as String?) ?? '',
            comment: item['comment'] as String?,
            sessionType: (item['session_type'] as String?) ?? '',
            ratedAt: DateTime.parse(item['rated_at'] as String? ?? DateTime.now().toIso8601String()),
            parentName: 'أنا', // غير موجود في البيانات الحالية
            childName: (item['child_name'] as String?) ?? '',
            sessionDate: (item['session_date'] as String?) ?? '',
          );
        }).toList();
        
        setState(() {
          _ratings = ratings;
          _isLoading = false;
          _totalItems = (data['count'] as int?) ?? ratings.length;
          _currentPage = 1;
          _totalPages = 1;
        });
        
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = data['message'] ?? 'Failed to load ratings';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'HTTP Error ${response.statusCode}';
        _isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      _hasError = true;
      _errorMessage = 'An error occurred while loading your ratings';
      _isLoading = false;
    });
  }
}
  // أضف هذه الدوال في _MyRatingsScreenState
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        // إزالة أي مسافات أو رموز غير مرغوبة
        final cleanValue = value.trim();
        return int.tryParse(cleanValue) ?? 0;
      } catch (e) {
        print('⚠️ Failed to parse int from string: "$value"');
        return 0;
      }
    }
    return 0;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        final cleanValue = value.trim();
        return double.tryParse(cleanValue) ?? 0.0;
      } catch (e) {
        print('⚠️ Failed to parse double from string: "$value"');
        return 0.0;
      }
    }
    return 0.0;
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        // حاول تحويل التاريخ بأشكال مختلفة
        if (value.contains('T')) {
          return DateTime.parse(value);
        } else {
          // إذا كان التاريخ بصيغة أخرى، حاول تحليله يدوياً
          return DateTime.parse(value + 'T00:00:00Z');
        }
      } catch (e) {
        print('⚠️ Failed to parse DateTime from string: "$value"');
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Widget _buildRatingCard(SessionRating rating) {
    // تأكد من أن rating.rating هو double
    final double ratingValue = rating.rating is double ? rating.rating : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: index < ratingValue.floor()
                          ? Colors.amber
                          : Colors.grey[300],
                    );
                  }),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rating.ratingTag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Session Info
            Text(
              'Session with ${rating.childName}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'On ${rating.sessionDate}',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),

            // Comment
            if (rating.comment != null && rating.comment!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rating.comment!,
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

            // Footer
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${rating.ratedAt.day}/${rating.ratedAt.month}/${rating.ratedAt.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
                Text(
                  '${ratingValue.toStringAsFixed(1)} / 5.0',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // في my_ratings_screen.dart
  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
              _ratings.length.toString(), 'Total ratings', Icons.star),
          _buildStatItem(_ratings.where((r) => r.rating >= 4).length.toString(),
              'Excellent ratings', Icons.thumb_up),
          _buildStatItem(
              _ratings
                  .where((r) => r.comment != null && r.comment!.isNotEmpty)
                  .length
                  .toString(),
              'With comment',
              Icons.comment),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading your ratings...',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'An error occurred',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGray),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadRatings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No ratings yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have not rated any session yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGray),
            ),
            const SizedBox(height: 16),
            Text(
              'Your ratings will appear here after you complete and rate sessions',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Ratings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadRatings(page: 1),
        color: AppColors.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats
              _buildStatsCard(),

              const SizedBox(height: 16),

              // Title
              Text(
                'Ratings history',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 16),

              // Ratings List
              if (_isLoading)
                _buildLoadingState()
              else if (_hasError)
                _buildErrorState()
              else if (_ratings.isEmpty)
                _buildEmptyState()
              else
                Column(
                  children: _ratings.map(_buildRatingCard).toList(),
                ),

              // Pagination
              if (_totalPages > 1 &&
                  !_isLoading &&
                  !_hasError &&
                  _ratings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentPage > 1)
                        IconButton(
                          onPressed: () => _loadRatings(page: _currentPage - 1),
                          icon: Icon(Icons.arrow_back_ios_rounded,
                              color: AppColors.primary),
                        ),
                      Text(
                        'Page $_currentPage of $_totalPages',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                      if (_currentPage < _totalPages)
                        IconButton(
                          onPressed: () => _loadRatings(page: _currentPage + 1),
                          icon: Icon(Icons.arrow_forward_ios_rounded,
                              color: AppColors.primary),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
