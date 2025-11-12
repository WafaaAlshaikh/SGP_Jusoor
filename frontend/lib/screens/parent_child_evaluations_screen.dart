import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

class ParentChildEvaluationsScreen extends StatefulWidget {
  final int? childId; // إذا تم تمريره، نعرض تقييمات طفل معين فقط

  const ParentChildEvaluationsScreen({Key? key, this.childId}) : super(key: key);

  @override
  State<ParentChildEvaluationsScreen> createState() => _ParentChildEvaluationsScreenState();
}

class _ParentChildEvaluationsScreenState extends State<ParentChildEvaluationsScreen> {
  List<dynamic> _evaluations = [];
  List<dynamic> _filteredEvaluations = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEvaluations();
  }

  Future<void> _loadEvaluations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No token found. Please login again.');
      }

      final response = await ApiService.getChildEvaluationsForParent(token);

      if (response != null && response['success'] == true) {
        List<dynamic> allEvaluations = response['data'] ?? [];

        // إذا تم تحديد طفل معين، فلتر التقييمات
        if (widget.childId != null) {
          allEvaluations = allEvaluations
              .where((eval) => eval['child_id'] == widget.childId)
              .toList();
        }

        setState(() {
          _evaluations = allEvaluations;
          _filteredEvaluations = allEvaluations;
          _isLoading = false;
        });
      } else {
        throw Exception(response?['error'] ?? 'Failed to load evaluations');
      }
    } catch (e) {
      print('❌ Error loading evaluations: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredEvaluations = _evaluations;
      });
      return;
    }

    setState(() {
      _filteredEvaluations = _evaluations.where((eval) {
        final childName = eval['child_name']?.toString().toLowerCase() ?? '';
        final evalType = eval['evaluation_type']?.toString().toLowerCase() ?? '';
        final specialistName = eval['specialist_name']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return childName.contains(query) ||
            evalType.contains(query) ||
            specialistName.contains(query);
      }).toList();
    });
  }

  Color _getProgressColor(dynamic score) {
    double progressScore = 0.0;

    if (score != null) {
      if (score is double) {
        progressScore = score;
      } else if (score is int) {
        progressScore = score.toDouble();
      } else if (score is String) {
        progressScore = double.tryParse(score) ?? 0.0;
      }
    }

    if (progressScore >= 75) return AppColors.success;
    if (progressScore >= 50) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getEvaluationIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'initial':
        return Icons.start;
      case 'mid':
        return Icons.trending_up;
      case 'final':
        return Icons.check_circle;
      case 'follow-up':
        return Icons.refresh;
      default:
        return Icons.assignment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          widget.childId != null ? 'Child Evaluations' : 'All Child Reports',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorState()
              : _filteredEvaluations.isEmpty
                  ? _buildEmptyState()
                  : _buildEvaluationsList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Reports',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGray),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEvaluations,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment, size: 80, color: AppColors.textGray.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No Reports Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your child\'s evaluation reports will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationsList() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applySearch();
            },
            decoration: InputDecoration(
              hintText: 'Search by child name, type, or specialist...',
              prefixIcon: Icon(Icons.search, color: AppColors.primary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Statistics Section
        if (_evaluations.isNotEmpty) _buildStatisticsSection(),

        const SizedBox(height: 16),

        // Count Banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.assignment, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_filteredEvaluations.length} Report${_filteredEvaluations.length != 1 ? 's' : ''} Found',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Evaluations List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadEvaluations,
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredEvaluations.length,
              itemBuilder: (context, index) {
                final evaluation = _filteredEvaluations[index];
                return _buildEvaluationCard(evaluation);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationCard(Map<String, dynamic> evaluation) {
    final evalType = evaluation['evaluation_type']?.toString() ?? 'N/A';
    final childName = evaluation['child_name']?.toString() ?? 'Unknown';
    final specialistName = evaluation['specialist_name']?.toString() ?? 'Unknown';
    final notes = evaluation['notes']?.toString() ?? 'No notes provided';
    final progressScore = evaluation['progress_score'];
    final createdAt = evaluation['created_at'];
    final specialization = evaluation['specialization']?.toString() ?? '';

    double score = 0.0;
    if (progressScore != null) {
      if (progressScore is double) {
        score = progressScore;
      } else if (progressScore is int) {
        score = progressScore.toDouble();
      } else if (progressScore is String) {
        score = double.tryParse(progressScore) ?? 0.0;
      }
    }

    String formattedDate = 'Unknown date';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt.toString());
        formattedDate = '${date.day}/${date.month}/${date.year}';
      } catch (e) {
        formattedDate = createdAt.toString();
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showEvaluationDetails(evaluation),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getEvaluationIcon(evalType),
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          evalType,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'For: $childName',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getProgressColor(score).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${score.toInt()}%',
                      style: TextStyle(
                        color: _getProgressColor(score),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Specialist Info
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: AppColors.textGray),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'By: $specialistName',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGray,
                      ),
                    ),
                  ),
                  if (specialization.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent2.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        specialization,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Date
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: AppColors.textGray),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Notes Preview
              Text(
                notes.length > 100 ? '${notes.substring(0, 100)}...' : notes,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark.withOpacity(0.8),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              // View Details Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showEvaluationDetails(evaluation),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEvaluationDetails(Map<String, dynamic> evaluation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getEvaluationIcon(evaluation['evaluation_type']),
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                evaluation['evaluation_type']?.toString() ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                'Evaluation Report',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildDetailRow('Child', evaluation['child_name']?.toString() ?? 'N/A', Icons.child_care),
                    _buildDetailRow('Specialist', evaluation['specialist_name']?.toString() ?? 'N/A', Icons.person),
                    _buildDetailRow('Specialization', evaluation['specialization']?.toString() ?? 'N/A', Icons.work),
                    _buildDetailRow('Date', _formatDate(evaluation['created_at']), Icons.calendar_today),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Progress Score
                    Text(
                      'Progress Score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProgressBar(evaluation['progress_score']),

                    const SizedBox(height: 24),

                    // Notes
                    Text(
                      'Notes & Observations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        evaluation['notes']?.toString() ?? 'No notes provided',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close', style: TextStyle(fontSize: 16)),
                      ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(dynamic score) {
    double progressScore = 0.0;

    if (score != null) {
      if (score is double) {
        progressScore = score;
      } else if (score is int) {
        progressScore = score.toDouble();
      } else if (score is String) {
        progressScore = double.tryParse(score) ?? 0.0;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${progressScore.toInt()}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getProgressColor(score),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getProgressColor(score).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                progressScore >= 75
                    ? 'Excellent'
                    : progressScore >= 50
                        ? 'Good'
                        : 'Needs Improvement',
                style: TextStyle(
                  color: _getProgressColor(score),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progressScore / 100,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(score)),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }

  // ========== إحصائيات التطور ==========
  Widget _buildStatisticsSection() {
    // حساب الإحصائيات
    double totalScore = 0;
    int count = 0;
    double highest = 0;
    double lowest = 100;
    Map<String, int> typeCount = {};

    for (var eval in _evaluations) {
      final score = _getNumericScore(eval['progress_score']);
      if (score > 0) {
        totalScore += score;
        count++;
        if (score > highest) highest = score;
        if (score < lowest) lowest = score;
      }

      final type = eval['evaluation_type']?.toString() ?? 'Unknown';
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }

    final avgScore = count > 0 ? totalScore / count : 0;

    // حساب الاتجاه (Trend)
    String trend = _calculateTrend();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.trending_up, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Track your child\'s development',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTrendIndicator(trend),
            ],
          ),

          const SizedBox(height: 20),

          // Main Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Average',
                  '${avgScore.toStringAsFixed(1)}%',
                  Icons.bar_chart,
                  _getProgressColor(avgScore),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Highest',
                  '${highest.toInt()}%',
                  Icons.arrow_upward,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Lowest',
                  '${lowest.toInt()}%',
                  Icons.arrow_downward,
                  AppColors.error,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: avgScore / 100,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(avgScore)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getProgressMessage(avgScore.toDouble()),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Evaluation Types Distribution
          if (typeCount.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Evaluation Types',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: typeCount.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent2.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getEvaluationIcon(entry.key), size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.key}: ${entry.value}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(String trend) {
    IconData icon;
    Color color;
    String text;

    switch (trend) {
      case 'improving':
        icon = Icons.trending_up;
        color = AppColors.success;
        text = 'Improving';
        break;
      case 'stable':
        icon = Icons.trending_flat;
        color = AppColors.warning;
        text = 'Stable';
        break;
      case 'declining':
        icon = Icons.trending_down;
        color = AppColors.error;
        text = 'Needs Focus';
        break;
      default:
        icon = Icons.help_outline;
        color = AppColors.textGray;
        text = 'New';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTrend() {
    if (_evaluations.length < 2) return 'new';

    // ترتيب التقييمات حسب التاريخ
    final sorted = List<dynamic>.from(_evaluations);
    sorted.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['created_at'].toString());
        final dateB = DateTime.parse(b['created_at'].toString());
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });

    // مقارنة أول 3 مع آخر 3
    final firstHalf = sorted.take((sorted.length / 2).ceil()).toList();
    final secondHalf = sorted.skip((sorted.length / 2).ceil()).toList();

    double firstAvg = 0;
    double secondAvg = 0;
    int firstCount = 0;
    int secondCount = 0;

    for (var eval in firstHalf) {
      final score = _getNumericScore(eval['progress_score']);
      if (score > 0) {
        firstAvg += score;
        firstCount++;
      }
    }

    for (var eval in secondHalf) {
      final score = _getNumericScore(eval['progress_score']);
      if (score > 0) {
        secondAvg += score;
        secondCount++;
      }
    }

    if (firstCount == 0 || secondCount == 0) return 'new';

    firstAvg /= firstCount;
    secondAvg /= secondCount;

    final difference = secondAvg - firstAvg;

    if (difference > 5) return 'improving';
    if (difference < -5) return 'declining';
    return 'stable';
  }

  double _getNumericScore(dynamic score) {
    if (score == null) return 0;
    if (score is double) return score;
    if (score is int) return score.toDouble();
    if (score is String) return double.tryParse(score) ?? 0;
    return 0;
  }

  String _getProgressMessage(double avgScore) {
    if (avgScore >= 80) return '🎉 Excellent progress! Keep up the great work!';
    if (avgScore >= 65) return '👍 Good progress! Continue the momentum!';
    if (avgScore >= 50) return '💪 Steady progress. Stay consistent!';
    return '🌱 Starting journey. Every step counts!';
  }
}
