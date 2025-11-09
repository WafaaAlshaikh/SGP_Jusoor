import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/evaluation_service.dart';

class EditEvaluationScreen extends StatefulWidget {
  final Map<String, dynamic> evaluation;
  final VoidCallback? onEvaluationUpdated;

  const EditEvaluationScreen({
    super.key,
    required this.evaluation,
    this.onEvaluationUpdated,
  });

  @override
  State<EditEvaluationScreen> createState() => _EditEvaluationScreenState();
}

class _EditEvaluationScreenState extends State<EditEvaluationScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _evaluationType;
  late String _notes;
  late double _progressScore;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // تهيئة البيانات من التقييم الحالي مع معالجة أنواع البيانات
    _evaluationType = widget.evaluation['evaluation_type'] ?? 'Initial';
    _notes = widget.evaluation['notes'] ?? '';

    // تحويل progress_score إلى double بشكل آمن
    final score = widget.evaluation['progress_score'];
    if (score == null) {
      _progressScore = 50.0;
    } else if (score is double) {
      _progressScore = score;
    } else if (score is int) {
      _progressScore = score.toDouble();
    } else if (score is String) {
      _progressScore = double.tryParse(score) ?? 50.0;
    } else {
      _progressScore = 50.0;
    }
  }

  Color getProgressColor(double score) {
    if (score < 40) return Colors.pinkAccent;
    if (score < 70) return Colors.orangeAccent;
    return Colors.greenAccent.shade400;
  }

  Future<void> _updateEvaluation() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final updateData = {
          'evaluation_type': _evaluationType,
          'notes': _notes,
          'progress_score': _progressScore,
        };

        // استخدام الـ API الحقيقي
        await EvaluationService.updateEvaluation(
            widget.evaluation['evaluation_id'],
            updateData
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Evaluation updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          widget.onEvaluationUpdated?.call();
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error updating evaluation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFFF6F4FB);

    InputDecoration softInput(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(color: AppColors.primary.withOpacity(0.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text(
            "Edit Evaluation",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.circle,
                  color: Colors.orange,
                  size: 12,
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Form(
            key: _formKey,
            onChanged: _onFieldChanged,
            child: Column(
              children: [
                // Child Info Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Icon(
                            Icons.child_care,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.evaluation['child_name'] ?? 'Unknown Child',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Evaluation ID: ${widget.evaluation['evaluation_id']}',
                                style: TextStyle(
                                  color: AppColors.textDark.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Parent: ${widget.evaluation['parent_name'] ?? 'Unknown'}',
                                style: TextStyle(
                                  color: AppColors.textDark.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Evaluation Type
                _section(
                  title: "Evaluation Type",
                  child: DropdownButtonFormField<String>(
                    decoration: softInput("Select type"),
                    value: _evaluationType,
                    items: ['Initial', 'Mid', 'Final', 'Follow-up']
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: TextStyle(color: AppColors.primary)),
                    ))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _evaluationType = val!);
                      _onFieldChanged();
                    },
                  ),
                ),

                // Progress Score
                _section(
                  title: "Progress Score - ${_progressScore.round()}%",
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: getProgressColor(_progressScore).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: getProgressColor(_progressScore).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _progressScore < 40 ? Icons.trending_down :
                              _progressScore < 70 ? Icons.trending_flat : Icons.trending_up,
                              color: getProgressColor(_progressScore),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _progressScore < 40 ? 'Needs significant improvement' :
                                _progressScore < 70 ? 'Making good progress' : 'Excellent progress',
                                style: TextStyle(
                                  color: getProgressColor(_progressScore),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Slider(
                        value: _progressScore,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: AppColors.primary,
                        inactiveColor: Colors.grey[300],
                        onChanged: (val) {
                          setState(() => _progressScore = val);
                          _onFieldChanged();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0%', style: TextStyle(color: Colors.grey[600])),
                          Text('50%', style: TextStyle(color: Colors.grey[600])),
                          Text('100%', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),

                // Notes
                _section(
                  title: "Notes & Observations",
                  child: TextFormField(
                    initialValue: _notes,
                    maxLines: 6,
                    style: TextStyle(color: AppColors.primary),
                    decoration: softInput("Write your notes and observations here..."),
                    onChanged: (val) {
                      setState(() => _notes = val);
                      _onFieldChanged();
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter some notes';
                      }
                      return null;
                    },
                  ),
                ),

                // Original Creation Date
                _section(
                  title: "Evaluation Information",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Created Date', _formatDate(widget.evaluation['created_at'])),
                      _infoRow('Specialist', widget.evaluation['specialist_name'] ?? 'Unknown'),
                      if (widget.evaluation['attachment'] != null) ...[
                        const SizedBox(height: 8),
                        _infoRow('Attachment', widget.evaluation['attachment']!),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: AppColors.primary),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Update Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateEvaluation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text(
                          'Update Evaluation',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}