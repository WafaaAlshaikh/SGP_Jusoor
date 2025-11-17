import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../widgets/review_card.dart';

class InstitutionReviewsScreen extends StatefulWidget {
  final int institutionId;
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
  List<dynamic> _reviews = [];
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String _sortBy = 'recent';
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    // user_id is stored as String in SharedPreferences
    final userIdStr = prefs.getString('user_id');
    final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
    setState(() => _currentUserId = userId);
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final result = await ApiService.getInstitutionReviews(
        token,
        institutionId: widget.institutionId,
        sort: _sortBy,
      );

      if (result['success'] == true) {
        setState(() {
          _reviews = result['reviews'] ?? [];
          _statistics = result['statistics'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddReviewDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddReviewDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          'Reviews',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReviews,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildStatisticsCard(),
                    _buildSortingBar(),
                    _buildReviewsList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReviewDialog,
        backgroundColor: AppColors.primary,
        icon: Icon(Icons.rate_review, color: Colors.white),
        label: Text('Write Review', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) return SizedBox.shrink();

    // Safe parsing for all numeric values
    final avgRating = _parseDouble(_statistics!['average_rating']);
    final totalReviews = _parseInt(_statistics!['total_reviews']);
    final fiveStar = _parseInt(_statistics!['five_star']);
    final fourStar = _parseInt(_statistics!['four_star']);
    final threeStar = _parseInt(_statistics!['three_star']);
    final twoStar = _parseInt(_statistics!['two_star']);
    final oneStar = _parseInt(_statistics!['one_star']);

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.institutionName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < avgRating.floor()
                              ? Icons.star
                              : index < avgRating
                                  ? Icons.star_half
                                  : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        );
                      }),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$totalReviews reviews',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildRatingBar('5', fiveStar, totalReviews),
                    _buildRatingBar('4', fourStar, totalReviews),
                    _buildRatingBar('3', threeStar, totalReviews),
                    _buildRatingBar('2', twoStar, totalReviews),
                    _buildRatingBar('1', oneStar, totalReviews),
                  ],
                ),
              ),
            ],
          ),
          if (_statistics!['avg_staff'] != null) ...[
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Text(
              'Aspect Ratings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (_statistics!['avg_staff'] != null)
                  _buildAspectChip('Staff', _statistics!['avg_staff']),
                if (_statistics!['avg_facilities'] != null)
                  _buildAspectChip('Facilities', _statistics!['avg_facilities']),
                if (_statistics!['avg_services'] != null)
                  _buildAspectChip('Services', _statistics!['avg_services']),
                if (_statistics!['avg_value'] != null)
                  _buildAspectChip('Value', _statistics!['avg_value']),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingBar(String stars, int count, int total) {
    final percentage = total > 0 ? (count / total) : 0.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            stars,
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
          SizedBox(width: 4),
          Icon(Icons.star, size: 12, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 6,
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            count.toString(),
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget _buildAspectChip(String label, dynamic value) {
    final rating = _parseDouble(value);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.star, size: 16, color: Colors.amber),
          SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortingBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('Most Recent', 'recent'),
                  _buildSortChip('Most Helpful', 'helpful'),
                  _buildSortChip('Highest Rating', 'rating_high'),
                  _buildSortChip('Lowest Rating', 'rating_low'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _sortBy = value);
            _loadReviews();
          }
        },
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textDark,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey[300]),
              SizedBox(height: 16),
              Text(
                'No reviews yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textGray,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Be the first to review this center!',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: _reviews.map((review) {
          final isOwn = _currentUserId != null && 
                       review['user_id'] == _currentUserId;
          
          return ReviewCard(
            review: review,
            isOwnReview: isOwn,
            onHelpful: () => _markHelpful(review['review_id'], true),
            onNotHelpful: () => _markHelpful(review['review_id'], false),
            onEdit: isOwn ? () => _editReview(review) : null,
            onDelete: isOwn ? () => _deleteReview(review['review_id']) : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddReviewDialog() {
    double rating = 5.0;
    double staffRating = 5.0;
    double facilitiesRating = 5.0;
    double servicesRating = 5.0;
    double valueRating = 5.0;
    final titleController = TextEditingController();
    final commentController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Write a Review',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                
                // Overall Rating
                Text('Overall Rating', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setDialogState(() => rating = index + 1.0),
                    );
                  }),
                ),
                
                SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Your Review',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                SizedBox(height: 20),
                Text('Detailed Ratings (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                _buildDetailedRatingSlider('Staff', staffRating, (v) => setDialogState(() => staffRating = v)),
                _buildDetailedRatingSlider('Facilities', facilitiesRating, (v) => setDialogState(() => facilitiesRating = v)),
                _buildDetailedRatingSlider('Services', servicesRating, (v) => setDialogState(() => servicesRating = v)),
                _buildDetailedRatingSlider('Value for Money', valueRating, (v) => setDialogState(() => valueRating = v)),
                
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _submitReview(
                      rating,
                      titleController.text,
                      commentController.text,
                      staffRating,
                      facilitiesRating,
                      servicesRating,
                      valueRating,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Submit Review',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailedRatingSlider(String label, double value, Function(double) onChanged) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 14)),
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  Text(' ${value.toStringAsFixed(1)}'),
                ],
              ),
            ],
          ),
          Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 8,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview(
    double rating,
    String title,
    String comment,
    double staffRating,
    double facilitiesRating,
    double servicesRating,
    double valueRating,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final result = await ApiService.createReview(
        token,
        institutionId: widget.institutionId,
        rating: rating,
        title: title,
        comment: comment,
        staffRating: staffRating,
        facilitiesRating: facilitiesRating,
        servicesRating: servicesRating,
        valueRating: valueRating,
      );

      if (result['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review submitted successfully!'), backgroundColor: Colors.green),
        );
        _loadReviews();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to submit review')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _markHelpful(int reviewId, bool isHelpful) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      await ApiService.markReviewHelpful(token, reviewId: reviewId, isHelpful: isHelpful);
      _loadReviews();
    } catch (e) {
      print('Error marking review helpful: $e');
    }
  }

  void _editReview(Map<String, dynamic> review) {
    // TODO: Implement edit functionality
  }

  Future<void> _deleteReview(int reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Review'),
        content: Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? '';

        final result = await ApiService.deleteReview(token, reviewId: reviewId);
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Review deleted'), backgroundColor: Colors.green),
          );
          _loadReviews();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting review')),
        );
      }
    }
  }

  // Helper functions for safe type conversion
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
