// widgets/rating_stats_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RatingStatsCard extends StatelessWidget {
  final double rating;
  final int totalRatings;
  final Map<String, dynamic> distribution;
  final Map<String, double>? categoryAverages;

  const RatingStatsCard({
    Key? key,
    required this.rating,
    required this.totalRatings,
    required this.distribution,
    this.categoryAverages,
  }) : super(key: key);

  Widget _buildRatingBar(int starCount, int count) {
    final percentage = totalRatings > 0 ? (count / totalRatings) * 100 : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Row(
              children: [
                Text(
                  '$starCount',
                  style: TextStyle(fontSize: 14),
                ),
                Icon(Icons.star, size: 16, color: Colors.amber),
              ],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: percentage * 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '$count',
              style: TextStyle(fontSize: 14, color: AppColors.textGray),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String category, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getCategoryLabel(category),
            style: TextStyle(fontSize: 14),
          ),
          Row(
            children: [
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4),
              ...List.generate(5, (index) {
                final star = index + 1;
                return Icon(
                  star <= score.round()
                      ? Icons.star
                      : Icons.star_border,
                  size: 16,
                  color: star <= score.round() ? Colors.amber : Colors.grey,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(String category) {
    final labels = {
      'facilities': 'التجهيزات',
      'staff': 'الكادر',
      'cleanliness': 'النظافة',
      'accessibility': 'سهولة الوصول',
      'professionalism': 'الاحترافية',
      'communication': 'التواصل',
      'knowledge': 'المعرفة',
      'punctuality': 'الالتزام بالوقت',
    };
    return labels[category] ?? category;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التقييم العام',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textGray,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          ' /5',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalRatings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'تقييم',
                      style: TextStyle(
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Rating Distribution
            Text(
              'توزيع التقييمات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            ...List.generate(5, (index) {
              final starCount = 5 - index;
              final count = distribution[starCount.toString()] ?? 0;
              return _buildRatingBar(starCount, count);
            }),
            
            // Category Averages
            if (categoryAverages != null && categoryAverages!.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'تقييمات الفئات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              ...categoryAverages!.entries.map((entry) => 
                _buildCategoryRow(entry.key, entry.value)
              ).toList(),
            ],
          ],
        ),
      ),
    );
  }
}