// widgets/rate_institution_dialog.dart
import 'package:flutter/material.dart';
import '../services/rating_service.dart';
import '../theme/app_colors.dart';

class RateInstitutionDialog extends StatefulWidget {
  final String institutionId;
  final String institutionName;
  final VoidCallback? onSubmitted;

  const RateInstitutionDialog({
    Key? key,
    required this.institutionId,
    required this.institutionName,
    this.onSubmitted,
  }) : super(key: key);

  @override
  _RateInstitutionDialogState createState() => _RateInstitutionDialogState();
}

class _RateInstitutionDialogState extends State<RateInstitutionDialog> {
  // تحديث التصنيفات لتتوافق مع الـ API
  final Map<String, double> _ratings = {
    'staff': 0.0,           // الكادر والموظفين
    'facilities': 0.0,      // التجهيزات والمرافق
    'services': 0.0,        // جودة الخدمات
    'value': 0.0,           // القيمة مقابل المال
  };
  
  final TextEditingController _commentController = TextEditingController();
  bool _wouldRecommend = true;
  bool _isSubmitting = false;
  
  // تحديث التسميات
  final Map<String, String> _categoryLabels = {
    'staff': 'الكادر والموظفين',
    'facilities': 'التجهيزات والمرافق',
    'services': 'جودة الخدمات',
    'value': 'القيمة مقابل المال',
  };

  Widget _buildStarRating(String category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _categoryLabels[category]!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            Text(
              '${_ratings[category]?.toInt() ?? 0}/5',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final rating = index + 1;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _ratings[category] = rating.toDouble();
                });
              },
              child: Icon(
                rating <= (_ratings[category]?.toInt() ?? 0)
                    ? Icons.star
                    : Icons.star_border,
                size: 32,
                color: rating <= (_ratings[category]?.toInt() ?? 0)
                    ? Colors.amber
                    : Colors.grey,
              ),
            );
          }),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  double get _overallRating {
    final values = _ratings.values.toList();
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
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
          content: Text('يرجى تقييم: ${missingCategories.join("، ")}'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
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

      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'تم إضافة المراجعة بنجاح'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );

        widget.onSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إرسال المراجعة: ${e.toString()}'),
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
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      child: Container(
        constraints: BoxConstraints(maxWidth: 600),
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تقييم المؤسسة',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textLight),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              Text(
                'يجب أن يكون لديك زيارات سابقة للمؤسسة لتقييمها',
                style: TextStyle(
                  color: AppColors.textGray,
                ),
              ),
              
              SizedBox(height: 24),
              
              // Institution Info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.business,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.institutionName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Overall Rating
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'التقييم العام',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                            size: 28,
                            color: rating <= _overallRating.round()
                                ? Colors.amber
                                : Colors.grey,
                          );
                        }),
                        SizedBox(width: 8),
                        Text(
                          _overallRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Category Ratings
              ..._ratings.keys.map((category) => _buildStarRating(category)).toList(),
              
              // Review Text
              Text(
                'مراجعتك (اختياري)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'شاركنا بتجربتك مع المؤسسة...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Would Recommend
              Row(
                children: [
                  Checkbox(
                    value: _wouldRecommend,
                    onChanged: (value) {
                      setState(() {
                        _wouldRecommend = value ?? true;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  Expanded(
                    child: Text(
                      'أوصي بهذه المؤسسة للآخرين',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'إرسال التقييم',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}