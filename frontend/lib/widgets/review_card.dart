import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;

class ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback? onHelpful;
  final VoidCallback? onNotHelpful;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isOwnReview;

  const ReviewCard({
    Key? key,
    required this.review,
    this.onHelpful,
    this.onNotHelpful,
    this.onEdit,
    this.onDelete,
    this.isOwnReview = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safe parsing for all values
    final rating = _parseDouble(review['rating']);
    final userName = review['user_name']?.toString() ?? 'Anonymous';
    final title = review['title']?.toString() ?? '';
    final comment = review['comment']?.toString() ?? '';
    final helpfulCount = _parseInt(review['helpful_count']);
    final verifiedVisit = review['verified_visit'] == true || review['verified_visit'] == 1;
    
    final createdAt = DateTime.tryParse(review['created_at']?.toString() ?? '');
    final timeAgo = createdAt != null ? timeago.format(createdAt) : '';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (verifiedVisit) ...[
                            SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < rating.floor()
                                  ? Icons.star
                                  : index < rating
                                      ? Icons.star_half
                                      : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                          SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwnReview) ...[
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: AppColors.textGray),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) onEdit!();
                      if (value == 'delete' && onDelete != null) onDelete!();
                    },
                  ),
                ],
              ],
            ),
            
            if (title.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
            
            if (comment.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                comment,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                  height: 1.5,
                ),
              ),
            ],
            
            // Aspect ratings
            if (review['staff_rating'] != null ||
                review['facilities_rating'] != null ||
                review['services_rating'] != null ||
                review['value_rating'] != null) ...[
              SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (review['staff_rating'] != null)
                    _buildAspectRating('Staff', review['staff_rating']),
                  if (review['facilities_rating'] != null)
                    _buildAspectRating('Facilities', review['facilities_rating']),
                  if (review['services_rating'] != null)
                    _buildAspectRating('Services', review['services_rating']),
                  if (review['value_rating'] != null)
                    _buildAspectRating('Value', review['value_rating']),
                ],
              ),
            ],
            
            // Helpful buttons
            SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Was this helpful?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGray,
                  ),
                ),
                SizedBox(width: 12),
                _buildHelpfulButton(
                  icon: Icons.thumb_up_outlined,
                  label: helpfulCount > 0 ? helpfulCount.toString() : '',
                  onPressed: onHelpful,
                ),
                SizedBox(width: 8),
                _buildHelpfulButton(
                  icon: Icons.thumb_down_outlined,
                  onPressed: onNotHelpful,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAspectRating(String label, dynamic value) {
    final rating = _parseDouble(value);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.star, size: 14, color: Colors.amber),
          SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpfulButton({
    required IconData icon,
    String label = '',
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textGray.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textGray),
            if (label.isNotEmpty) ...[
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
