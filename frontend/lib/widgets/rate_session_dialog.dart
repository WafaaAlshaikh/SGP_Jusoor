// lib/widgets/rate_session_dialog.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

class RateSessionDialog extends StatefulWidget {
  final Session session;
  final VoidCallback? onRated;

  const RateSessionDialog({
    super.key,
    required this.session,
    this.onRated,
  });

  @override
  State<RateSessionDialog> createState() => _RateSessionDialogState();
}

class _RateSessionDialogState extends State<RateSessionDialog> {
  double _rating = 0.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Rate Your Session',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Info
            _buildSessionInfo(),
            const SizedBox(height: 24),

            // Rating Section
            _buildRatingSection(),
            const SizedBox(height: 24),

            // Review Section
            _buildReviewSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRating,
          style: ElevatedButton.styleFrom(
            backgroundColor: ParentAppColors.primaryTeal,
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
              : const Text(
            'Submit Rating',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: ParentAppColors.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.child_care,
              color: ParentAppColors.primaryTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.session.childName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'With ${widget.session.specialistName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.session.date} • ${widget.session.time}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How was your session?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rate your experience with ${widget.session.specialistName}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        // Star Rating
        Center(
          child: Column(
            children: [
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = (index + 1).toDouble();
                      });
                    },
                    child: Icon(
                      Icons.star,
                      size: 40,
                      color: index < _rating ? Colors.amber : Colors.grey[300],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),

              // Rating Text
              Text(
                _rating == 0 ? 'Tap to rate' : '${_rating.toStringAsFixed(1)}/5',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _rating == 0 ? Colors.grey : Colors.amber,
                ),
              ),
              const SizedBox(height: 8),

              // Rating Labels
              if (_rating > 0) ...[
                Text(
                  _getRatingLabel(_rating),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Feedback (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share your experience to help improve our services',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reviewController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tell us about your session experience...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),

        // Review Tips
        const SizedBox(height: 8),
        Text(
          'Consider mentioning: specialist approach, session effectiveness, areas for improvement',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  String _getRatingLabel(double rating) {
    if (rating <= 1) return 'Poor';
    if (rating <= 2) return 'Fair';
    if (rating <= 3) return 'Good';
    if (rating <= 4) return 'Very Good';
    return 'Excellent';
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      print('🚀 Submitting rating for session: ${widget.session.sessionId}');

      final success = await ApiService.rateSession(
        token,
        widget.session.sessionId, // الآن بتكون String
        _rating,
        _reviewController.text.isNotEmpty ? _reviewController.text : null,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you for your feedback! 🌟'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          widget.onRated?.call(); // راح يحدث الـ sessions تلقائياً
        }
      } else {
        throw Exception('Failed to submit rating');
      }
    } catch (e) {
      print('❌ Rating submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: ${e.toString()}'),
            backgroundColor: Colors.red,
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
    _reviewController.dispose();
    super.dispose();
  }
}