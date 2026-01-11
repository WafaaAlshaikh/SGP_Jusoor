import 'package:flutter/material.dart';
import 'package:frontend/models/session.dart';
import 'package:frontend/services/rating_service.dart';
import 'package:frontend/theme/app_colors.dart';

class RateSessionDialog extends StatefulWidget {
  final Session session;
  final VoidCallback onRated;

  const RateSessionDialog({
    Key? key,
    required this.session,
    required this.onRated,
  }) : super(key: key);

  @override
  State<RateSessionDialog> createState() => _RateSessionDialogState();
}

class _RateSessionDialogState extends State<RateSessionDialog> {
  double _rating = 0.0;
  TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  final Map<int, String> _ratingTags = {
    1: 'Very Poor',
    2: 'Poor',
    3: 'Average',
    4: 'Good',
    5: 'Excellent',
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.star, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate Session',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            widget.session.childName,
                            style: TextStyle(
                              color: AppColors.textGray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Session Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSessionInfoRow('Specialist', widget.session.specialistName),
                      _buildSessionInfoRow('Date', widget.session.date),
                      _buildSessionInfoRow('Time', widget.session.time),
                      _buildSessionInfoRow('Type', widget.session.sessionType),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Rating Stars
                Center(
                  child: Column(
                    children: [
                      Text(
                        'How would you rate this session?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_rating > 0)
                        Text(
                          _ratingTags[_rating.toInt()] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: List.generate(5, (index) {
                          return IconButton(
                            onPressed: () {
                              setState(() {
                                _rating = (index + 1).toDouble();
                              });
                            },
                            icon: Icon(
                              Icons.star_rounded,
                              size: 32,
                              color: index < _rating.floor()
                                  ? Colors.amber
                                  : AppColors.textLight.withOpacity(0.3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_rating.toStringAsFixed(1)} / 5.0',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Comment
                Text(
                  'Comment (Optional)',
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
                    hintText: 'Write your comment about the session...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 32),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textGray,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: AppColors.textGray.withOpacity(0.3)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _rating == 0 ? null : _submitRating,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text('Rate Session'),
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

  Widget _buildSessionInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;

    setState(() => _isSubmitting = true);

    try {
      print('🎯 Starting rating process...');
      print('📱 Session ID: ${widget.session.sessionId}');
      print('⭐ Rating: $_rating');
      print('📝 Comment: ${_commentController.text}');

      final result = await RatingService.rateSession(
        sessionId: widget.session.sessionId,
        rating: _rating,
        comment: _commentController.text.isNotEmpty ? _commentController.text : null,
        ratingTag: _ratingTags[_rating.toInt()],
      );

      print('✅ Server response: $result');

      if (result['success'] == true) {
        // Short delay to prevent issues
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          // Close Dialog first
          Navigator.pop(context);

          // Wait a bit before showing Snackbar
          await Future.delayed(const Duration(milliseconds: 100));

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Rating submitted successfully'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );

          // Wait before calling onRated
          await Future.delayed(const Duration(milliseconds: 500));

          // Call update function
          widget.onRated();
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to rate session');
      }
    } catch (e) {
      print('❌ Rating error: $e');

      if (mounted) {
        // In case of error, keep Dialog open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rating failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );

        // Reset submitting state
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