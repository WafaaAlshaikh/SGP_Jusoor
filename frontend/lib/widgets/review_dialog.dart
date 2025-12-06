// lib/widgets/review_dialog.dart
import 'package:flutter/material.dart';
import 'package:frontend/services/rating_service.dart';
import 'package:frontend/theme/app_colors.dart';

class ReviewDialog extends StatefulWidget {
  final String institutionId;
  final String institutionName;
  final VoidCallback? onSubmitted;

  const ReviewDialog({
    Key? key,
    required this.institutionId,
    required this.institutionName,
    this.onSubmitted,
  }) : super(key: key);

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  // 🔴 تصحيح: استخدم الأسماء التي يتوقعها السيرفر
  final Map<String, double> _ratings = {
    'staff': 0,           // Staff & Team
    'facilities': 0,      // Facilities & Equipment
    'cleanliness': 0,     // Cleanliness
    'accessibility': 0,   // Accessibility
  };

  final Map<String, String> _categoryLabels = {
    'staff': 'Staff & Team',
    'facilities': 'Facilities & Equipment',
    'cleanliness': 'Cleanliness',      // 🔴 تصحيح
    'accessibility': 'Accessibility', // 🔴 تصحيح
  };

  final TextEditingController _commentController = TextEditingController();
  bool _wouldRecommend = true;
  bool _isSubmitting = false;

  double get _overallRating {
    if (_ratings.values.every((rating) => rating == 0)) return 0;
    final validRatings = _ratings.values.where((rating) => rating > 0);
    if (validRatings.isEmpty) return 0;
    return validRatings.reduce((a, b) => a + b) / validRatings.length;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 500,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.business,
                              color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rate Institution',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.institutionName,
                                style: TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 13,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You should have previous visits to this institution to review it.',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Overall Rating
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Rating',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            final rating = index + 1;
                            return Icon(
                              rating <= _overallRating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 22,
                              color: rating <= _overallRating.round()
                                  ? Colors.amber
                                  : Colors.grey[300],
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            _overallRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Category Ratings
                ..._ratings.keys.map((category) {
                  return _buildCategoryRating(category);
                }).toList(),

                const SizedBox(height: 20),

                // Comment
                Text(
                  'Your Review (Optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share your experience with this center...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.textLight.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Recommendation
                Row(
                  children: [
                    Checkbox(
                      value: _wouldRecommend,
                      onChanged: (value) {
                        setState(() => _wouldRecommend = value ?? true);
                      },
                      activeColor: AppColors.primary,
                    ),
                    Expanded(
                      child: Text(
                        'I recommend this institution to others',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Buttons
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _ratings.values.any((rating) => rating == 0)
                            ? null
                            : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.5),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit Review'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textGray,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(
                              color: AppColors.textGray.withOpacity(0.3)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRating(String category) {
    final rating = _ratings[category]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _categoryLabels[category]!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  fontSize: 14,
                ),
              ),
              Text(
                '${rating.toInt()}/5',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _ratings[category] = (index + 1).toDouble();
                  });
                },
                child: Icon(
                  index < rating.floor() ? Icons.star : Icons.star_border,
                  size: 32,
                  color: index < rating.floor() ? Colors.amber : Colors.grey,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview() async {
    // التحقق من إدخال جميع التقييمات
    final missingCategories = _ratings.entries
        .where((entry) => entry.value == 0)
        .map((entry) => _categoryLabels[entry.key])
        .toList();

    if (missingCategories.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please rate: ${missingCategories.join(", ")}'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 🔴 تصحيح: استخدم الأسماء الصحيحة
      final result = await RatingService.addInstitutionReview(
        institutionId: widget.institutionId,
        staffRating: _ratings['staff']!,
        facilitiesRating: _ratings['facilities']!,
        cleanlinessRating: _ratings['cleanliness']!,      // 🔴 تصحيح
        accessibilityRating: _ratings['accessibility']!,  // 🔴 تصحيح
        reviewText: _commentController.text.isNotEmpty
            ? _commentController.text
            : null,
        wouldRecommend: _wouldRecommend,
      );

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Review added successfully'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
          widget.onSubmitted?.call();
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to add review');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add review: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}