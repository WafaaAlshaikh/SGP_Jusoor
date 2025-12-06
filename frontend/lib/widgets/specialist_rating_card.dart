import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SpecialistRatingCard extends StatelessWidget {
  final double rating;
  final int totalRatings;
  final VoidCallback onTap;
  final bool showDetails;

  const SpecialistRatingCard({
    Key? key,
    required this.rating,
    required this.totalRatings,
    required this.onTap,
    this.showDetails = false, required bool compact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Specialist Rating',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '/5.0',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                if (showDetails)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.textLight,
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Stars
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: index < rating.floor()
                      ? Colors.amber
                      : Colors.grey[300],
                );
              }),
            ),
            
            const SizedBox(height: 8),
            
            // Rating Count
            Text(
              'Based on $totalRatings reviews',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
              ),
            ),
            
            if (showDetails) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View All Ratings'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}