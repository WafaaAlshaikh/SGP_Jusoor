// lib/screens/institution_reviews_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/services/rating_service.dart';
import 'package:frontend/models/rating_models.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/widgets/review_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstitutionReviewsScreen extends StatefulWidget {
  final String institutionId;
  final String institutionName;

  const InstitutionReviewsScreen({
    Key? key,
    required this.institutionId,
    required this.institutionName,
  }) : super(key: key);

  @override
  State<InstitutionReviewsScreen> createState() => _InstitutionReviewsScreenState();
}

class _InstitutionReviewsScreenState extends State<InstitutionReviewsScreen> {
  List<InstitutionReview> _reviews = [];
  InstitutionReviewStats? _stats;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _canAddReview = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalReviews = 0;
  final int _limit = 10;
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    _loadAuthState();
    _loadReviews();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (!mounted) return;
    setState(() {
      _canAddReview = token.isNotEmpty;
    });
  }

  Future<void> _loadReviews({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await RatingService.getInstitutionReviews(
        widget.institutionId,
        page: page,
        limit: _limit,
        sort: _sortBy,
      );
      
      if (response['success'] == true) {
        final data = response['data'];
        final items = data['reviews'] as List;
        
        setState(() {
          _reviews = items.map((item) => InstitutionReview.fromJson(item)).toList();
          _stats = InstitutionReviewStats.fromJson(data['statistics']);
          _currentPage = data['pagination']['current_page'] ?? page;
          _totalPages = data['pagination']['total_pages'] ?? 1;
          _totalReviews = data['pagination']['total_reviews'] ?? 0;
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load reviews');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addReview() async {
    final result = await showDialog(
      context: context,
      builder: (context) => ReviewDialog(
        institutionId: widget.institutionId,
        institutionName: widget.institutionName,
      ),
    );

    if (result == true) {
      _loadReviews();
    }
  }

  Widget _buildStatsCard() {
    if (_stats == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Rating
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall rating',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _stats!.averageRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ 5.0',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Stars
              Column(
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        Icons.star_rounded,
                        size: 24,
                        color: index < _stats!.averageRating.floor()
                            ? Colors.amber
                            : Colors.grey[300],
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_stats!.totalReviews} reviews',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Recommendation Rate
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recommendation rate',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${((_stats!.recommendations / _stats!.totalReviews) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Category Ratings
          Text(
            'Rating by category',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildCategoryRating('Facilities', _stats!.facilitiesRating),
          _buildCategoryRating('Staff', _stats!.staffRating),
          _buildCategoryRating('Cleanliness', _stats!.cleanlinessRating),
          _buildCategoryRating('Accessibility', _stats!.accessibilityRating),
        ],
      ),
    );
  }

  Widget _buildCategoryRating(String category, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category,
              style: TextStyle(color: AppColors.textDark),
            ),
          ),
          SizedBox(
            width: 100,
            child: LinearProgressIndicator(
              value: rating / 5,
              color: _getRatingColor(rating),
              backgroundColor: AppColors.textLight.withOpacity(0.2),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _getRatingColor(rating),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return AppColors.success;
    if (rating >= 3) return Colors.orange;
    return AppColors.error;
  }

  Widget _buildReviewCard(InstitutionReview review) {
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
            // Review Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: review.parentAvatar != null
                      ? ClipOval(
                          child: Image.network(
                            review.parentAvatar!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          review.parentName[0].toUpperCase(),
                          style: TextStyle(color: AppColors.primary),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.parentName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${review.basedOnVisits} visits',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: index < review.overallRating.floor()
                              ? Colors.amber
                              : Colors.grey[300],
                        );
                      }),
                    ),
                    Text(
                      review.createdAt.day.toString() +
                          '/' +
                          review.createdAt.month.toString() +
                          '/' +
                          review.createdAt.year.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Review Text
            if (review.reviewText != null && review.reviewText!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.reviewText!,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Category Ratings
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildReviewChip('Facilities', review.facilitiesRating),
                _buildReviewChip('Staff', review.staffRating),
                _buildReviewChip('Cleanliness', review.cleanlinessRating),
                _buildReviewChip('Accessibility', review.accessibilityRating),
              ],
            ),

            // Recommendation
            if (review.wouldRecommend)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.thumb_up, size: 16, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      'Recommends this center',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewChip(String label, double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getRatingColor(rating).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getRatingColor(rating).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _getRatingColor(rating),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.star_rounded,
            size: 12,
            color: _getRatingColor(rating),
          ),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _getRatingColor(rating),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Reviews of ${widget.institutionName}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canAddReview)
            IconButton(
              icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
              onPressed: _addReview,
              tooltip: 'Add review',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadReviews(page: 1),
        color: AppColors.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats
              _buildStatsCard(),

              // Sort Options
              if (_reviews.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Text(
                        'Sort by:',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Newest'),
                        selected: _sortBy == 'newest',
                        onSelected: (selected) {
                          setState(() => _sortBy = 'newest');
                          _loadReviews();
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Highest rated'),
                        selected: _sortBy == 'highest',
                        onSelected: (selected) {
                          setState(() => _sortBy = 'highest');
                          _loadReviews();
                        },
                      ),
                    ],
                  ),
                ),

              // Reviews List
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
                    ],
                  ),
                )
              else if (_reviews.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.reviews, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No reviews yet',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to review this center',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _reviews.map(_buildReviewCard).toList(),
                ),

              // Pagination
              if (_totalPages > 1 && !_isLoading && !_hasError && _reviews.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentPage > 1)
                        IconButton(
                          onPressed: () => _loadReviews(page: _currentPage - 1),
                          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary),
                        ),
                      Text(
                        'Page $_currentPage of $_totalPages',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                      if (_currentPage < _totalPages)
                        IconButton(
                          onPressed: () => _loadReviews(page: _currentPage + 1),
                          icon: Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary),
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