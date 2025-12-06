import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';
import '../models/rating_models.dart';

class SpecialistRatingsScreen extends StatefulWidget {
  const SpecialistRatingsScreen({Key? key}) : super(key: key);

  @override
  State<SpecialistRatingsScreen> createState() => _SpecialistRatingsScreenState();
}

class _SpecialistRatingsScreenState extends State<SpecialistRatingsScreen> {
  List<SessionRating> _ratings = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _averageRating = 0.0;
  int _totalRatings = 0;
  Map<int, int> _ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }


  Future<void> _loadRatings() async {
  setState(() {
    _isLoading = true;
    _hasError = false;
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    // جلب تقييمات الأخصائي
    final response = await http.get(
      Uri.parse('http://10.0.2.2:5000/api/ratings/specialist-ratings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      print('📊 Ratings API Response: $data'); // للديبقنق
      
      if (data['success'] == true) {
        final ratingsData = data['data']['ratings'] as List;
        final stats = data['data']['statistics'];
        
        final ratings = ratingsData.map((item) {
          // 🔥 إصلاح مشكلة تحويل rating
          double ratingValue = 0.0;
          final rating = item['rating'];
          
          if (rating is num) {
            ratingValue = rating.toDouble();
          } else if (rating is String) {
            ratingValue = double.tryParse(rating) ?? 0.0;
          }
          
          return SessionRating(
            id: item['id'] ?? 0,
            sessionId: item['session_id'] ?? 0,
            specialistId: item['specialist_id'] ?? 0,
            parentId: item['parent_id'] ?? 0,
            childId: item['child_id'] ?? 0,
            rating: ratingValue, // 🔥 استخدم القيمة المحولة بأمان
            ratingTag: item['rating_tag'] ?? '',
            comment: item['comment'],
            sessionType: item['session_type'] ?? '',
            ratedAt: DateTime.parse(item['rated_at'] ?? DateTime.now().toIso8601String()),
            parentName: item['parent_name'] ?? 'Anonymous',
            childName: item['child_name'] ?? '',
            sessionDate: item['session_date'] ?? '',
          );
        }).toList();

        // 🔥 إصلاح مشكلة تحويل الإحصائيات أيضاً
        double avgRating = 0.0;
        int totalRatings = 0;
        Map<int, int> ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        
        final avg = stats['average_rating'];
        if (avg is num) {
          avgRating = avg.toDouble();
        } else if (avg is String) {
          avgRating = double.tryParse(avg) ?? 0.0;
        }
        
        final total = stats['total_ratings'];
        if (total is num) {
          totalRatings = total.toInt();
        } else if (total is String) {
          totalRatings = int.tryParse(total) ?? 0;
        }
        
        final dist = stats['distribution'];
        if (dist is Map) {
          dist.forEach((key, value) {
            int star = int.tryParse(key.toString()) ?? 0;
            int count = 0;
            
            if (value is num) {
              count = value.toInt();
            } else if (value is String) {
              count = int.tryParse(value) ?? 0;
            }
            
            if (star >= 1 && star <= 5) {
              ratingDistribution[star] = count;
            }
          });
        }

        setState(() {
          _ratings = ratings;
          _averageRating = avgRating;
          _totalRatings = totalRatings;
          _ratingDistribution = ratingDistribution;
          _isLoading = false;
        });
      } else {
        throw Exception(data['message'] ?? 'Failed to load ratings');
      }
    } else {
      throw Exception('HTTP Error ${response.statusCode}');
    }
  } catch (e, stackTrace) {
    print('❌ Error loading specialist ratings: $e');
    print('📋 Stack trace: $stackTrace');
    setState(() {
      _hasError = true;
      _errorMessage = 'Failed to load ratings: $e';
      _isLoading = false;
    });
  }
}

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Overall Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall Rating',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '/5.0',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        Icons.star_rounded,
                        size: 24,
                        color: index < _averageRating.floor()
                            ? Colors.amber
                            : Colors.white.withOpacity(0.3),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_totalRatings ratings',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Rating Distribution
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rating Distribution',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ..._ratingDistribution.entries.map((entry) {
                final starCount = entry.key;
                final count = entry.value;
                final percentage = _totalRatings > 0 ? (count / _totalRatings) * 100 : 0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Row(
                          children: [
                            Text(
                              '$starCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              height: 8,
                              width: percentage * 3,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(SessionRating rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
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
                      color: index < rating.rating.floor()
                          ? Colors.amber
                          : Colors.grey[300],
                    );
                  }),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
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
              'Parent: ${rating.parentName} • ${rating.sessionDate}',
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
                  '${rating.rating.toStringAsFixed(1)} / 5.0',
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRatings,
        color: AppColors.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Card
              _buildStatsCard(),
              
              const SizedBox(height: 24),
              
              // Ratings List
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_hasError)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textGray),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRatings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              else if (_ratings.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.star_outline_rounded, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No Ratings Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your ratings will appear here after parents rate your sessions',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textGray),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      'Recent Ratings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._ratings.map(_buildRatingCard).toList(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}