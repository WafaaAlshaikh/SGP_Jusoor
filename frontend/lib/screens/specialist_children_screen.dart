// lib/screens/specialist_children_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/specialist_children_service.dart';
import '../services/api_service.dart';
import 'child_details_screen.dart';
import '../theme/app_colors.dart';

class SpecialistChildrenScreen extends StatefulWidget {
  const SpecialistChildrenScreen({Key? key}) : super(key: key);

  @override
  State<SpecialistChildrenScreen> createState() => _SpecialistChildrenScreenState();
}

class _SpecialistChildrenScreenState extends State<SpecialistChildrenScreen> {
  List<dynamic> children = [];
  bool isLoading = true;
  String errorMessage = '';
  String _searchQuery = '';
  String _selectedFilter = 'all';
  List<String> _diagnosisTypes = ['all', 'ASD', 'ADHD', 'Down Syndrome', 'Speech & Language Disorder'];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final response = await SpecialistChildrenService.getSpecialistChildren();

      if (response['success'] == true) {
        setState(() {
          children = _safeList(response['data']?['children']);
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load children';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // تصفية الأطفال حسب البحث والفلتر
  List<dynamic> get _filteredChildren {
    return children.where((child) {
      final safeChild = _safeMap(child);
      final childName = _safeString(safeChild['full_name']).toLowerCase();
      final diagnosis = _safeMap(safeChild['diagnosis']);
      final diagnosisName = _safeString(diagnosis['name']).toLowerCase();

      // تطبيق البحث
      final matchesSearch = _searchQuery.isEmpty ||
          childName.contains(_searchQuery.toLowerCase()) ||
          diagnosisName.contains(_searchQuery.toLowerCase());

      // تطبيق الفلتر
      final matchesFilter = _selectedFilter == 'all' ||
          diagnosisName == _selectedFilter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();
  }

  // دالة مساعدة للتعامل مع القوائم بشكل آمن
  List<dynamic> _safeList(dynamic list) {
    return list is List ? list : [];
  }

  // دالة مساعدة للتعامل مع الـ Map بشكل آمن
  Map<String, dynamic> _safeMap(dynamic map) {
    return map is Map<String, dynamic> ? map : {};
  }

  void _navigateToChildDetails(int childId, String childName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildDetailsScreen(childId: childId, childName: childName),
      ),
    );
  }

  Widget _buildChildCard(dynamic child) {
    final safeChild = _safeMap(child);
    final childName = _safeString(safeChild['full_name']);
    final childPhoto = _safeString(safeChild['photo']);
    final childPhotoUrl = ApiService.buildFileUrl(childPhoto);
    final diagnosis = _safeMap(safeChild['diagnosis']);
    final evaluations = _safeList(safeChild['evaluations']);
    final totalSessions = _safeInt(safeChild['total_sessions']);
    final lastSession = _safeMap(safeChild['last_session']);
    final registrationStatus = _safeString(safeChild['registration_status']);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToChildDetails(_safeInt(safeChild['child_id']), childName),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textGray.withOpacity(0.1)),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with basic info
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: childPhotoUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  childPhotoUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      childName.isNotEmpty ? childName[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Text(
                                childName.isNotEmpty ? childName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            childName.isNotEmpty ? childName : 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildStatusChip(registrationStatus),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                ),
                                child: Text(
                                  diagnosis['name'] ?? 'Not specified',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
                  ],
                ),

                SizedBox(height: 20),

                // Stats row
                _buildStatsRow(totalSessions, evaluations.length, lastSession),

                SizedBox(height: 16),

                // Quick progress indicator
                if (evaluations.isNotEmpty) _buildQuickProgress(evaluations),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String tooltip;

    switch (status.toLowerCase()) {
      case 'approved':
        color = AppColors.success;
        icon = Icons.check_circle;
        tooltip = 'Active Child';
        break;
      case 'pending':
        color = AppColors.warning;
        icon = Icons.pending;
        tooltip = 'Pending Approval';
        break;
      default:
        color = AppColors.textGray;
        icon = Icons.person_outline;
        tooltip = 'Not Registered';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildStatsRow(int sessions, int evaluations, Map<String, dynamic> lastSession) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.event, '$sessions', 'Sessions'),
          _buildStatItem(Icons.assessment, '$evaluations', 'Evaluations'),
          _buildStatItem(
              Icons.calendar_today,
              lastSession['date'] != null ? _formatDate(_safeString(lastSession['date'])) : 'N/A',
              'Last Session'
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textGray,
          ),
        ),
      ],
    );
  }

  // ========== نظام التقييم المحسن والمتقدم ==========

  // تحليل التقدم للتقييمات - نسخة محسنة وذكية
  Map<String, dynamic> _analyzeProgress(List<dynamic> evaluations) {
    final safeEvaluations = _safeList(evaluations);

    if (safeEvaluations.isEmpty) {
      return {
        'trend': 'no_data',
        'message': 'No evaluations available',
        'improvement': 0.0,
        'hasEnoughData': false,
        'confidence': 'low',
        'trendColor': AppColors.textGray,
        'trendIcon': Icons.help_outline,
      };
    }

    if (safeEvaluations.length == 1) {
      final score = _safeDouble(safeEvaluations.first['progress_score']) ?? 0.0;
      return {
        'trend': 'initial',
        'message': 'Initial evaluation completed',
        'improvement': 0.0,
        'currentScore': score,
        'hasEnoughData': false,
        'confidence': 'medium',
        'trendColor': AppColors.info,
        'trendIcon': Icons.assessment,
        'firstScore': score,
        'lastScore': score,
      };
    }

    // ترتيب التقييمات من الأقدم إلى الأحدث
    final sortedEvaluations = List.from(safeEvaluations)
      ..sort((a, b) {
        try {
          final dateA = DateTime.parse(_safeString(a['created_at']));
          final dateB = DateTime.parse(_safeString(b['created_at']));
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });

    // تحليل متقدم
    final analysis = _advancedProgressAnalysis(sortedEvaluations);
    return analysis;
  }

  // تحليل متقدم للتقدم
  Map<String, dynamic> _advancedProgressAnalysis(List<dynamic> evaluations) {
    final scores = evaluations.map((e) => _safeDouble(e['progress_score']) ?? 0.0).toList();
    final dates = evaluations.map((e) => DateTime.parse(_safeString(e['created_at']))).toList();

    // 1. التحليل الأساسي (أول vs آخر)
    final firstScore = scores.first;
    final lastScore = scores.last;
    final simpleImprovement = lastScore - firstScore;

    // 2. متوسط التقدم
    final averageScore = scores.reduce((a, b) => a + b) / scores.length;

    // 3. تحليل الاتجاه (Linear Regression)
    final trendAnalysis = _calculateTrend(scores, dates);

    // 4. تحليل الاستقرار
    final stabilityAnalysis = _calculateStability(scores);

    // 5. تحليل التقدم الأخير
    final recentAnalysis = _analyzeRecentProgress(scores);

    // 6. تحديد التصنيف النهائي
    return _determineFinalClassification(
      simpleImprovement: simpleImprovement,
      trendSlope: trendAnalysis['slope'],
      stability: stabilityAnalysis['stability'],
      recentTrend: recentAnalysis['trend'],
      averageScore: averageScore,
      evaluationCount: scores.length,
      firstScore: firstScore,
      lastScore: lastScore,
    );
  }

  // حساب الاتجاه العام باستخدام Linear Regression
  Map<String, dynamic> _calculateTrend(List<double> scores, List<DateTime> dates) {
    if (scores.length < 2) {
      return {'slope': 0.0, 'rSquared': 0.0, 'trend': 'unknown'};
    }

    // تحويل التواريخ إلى أرقام (أيام من أول تاريخ)
    final firstDate = dates.first;
    final xValues = dates.map((date) => date.difference(firstDate).inDays.toDouble()).toList();

    // حساب Linear Regression
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    final n = scores.length.toDouble();

    for (int i = 0; i < scores.length; i++) {
      sumX += xValues[i];
      sumY += scores[i];
      sumXY += xValues[i] * scores[i];
      sumX2 += xValues[i] * xValues[i];
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // حساب R-squared
    double ssTotal = 0, ssResidual = 0;
    final meanY = sumY / n;

    for (int i = 0; i < scores.length; i++) {
      final prediction = slope * xValues[i] + intercept;
      ssTotal += pow(scores[i] - meanY, 2);
      ssResidual += pow(scores[i] - prediction, 2);
    }

    final rSquared = ssTotal > 0 ? (1 - (ssResidual / ssTotal)) : 0.0;

    String trend;
    if (slope > 0.1) trend = 'strong_improvement';
    else if (slope > 0.02) trend = 'moderate_improvement';
    else if (slope > -0.02) trend = 'stable';
    else if (slope > -0.1) trend = 'moderate_decline';
    else trend = 'strong_decline';

    return {
      'slope': slope,
      'rSquared': rSquared,
      'trend': trend,
      'intercept': intercept,
    };
  }

  // حساب استقرار الأداء
  Map<String, dynamic> _calculateStability(List<double> scores) {
    if (scores.length < 2) {
      return {'stability': 'unknown', 'volatility': 0.0};
    }

    final average = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores.map((score) => pow(score - average, 2)).reduce((a, b) => a + b) / scores.length;
    final standardDeviation = sqrt(variance);
    final volatility = average > 0 ? (standardDeviation / average) * 100 : 0.0;

    String stability;
    if (volatility < 5) stability = 'very_stable';
    else if (volatility < 10) stability = 'stable';
    else if (volatility < 15) stability = 'moderate_volatility';
    else if (volatility < 20) stability = 'high_volatility';
    else stability = 'very_high_volatility';

    return {
      'stability': stability,
      'volatility': volatility,
      'standardDeviation': standardDeviation,
    };
  }

  // تحليل التقدم الأخير (آخر 3 تقييمات)
  Map<String, dynamic> _analyzeRecentProgress(List<double> scores) {
    if (scores.length < 3) {
      return {'trend': 'insufficient_data', 'recentImprovement': 0.0};
    }

    final recentScores = scores.sublist(scores.length - 3);
    final recentImprovement = recentScores.last - recentScores.first;

    String trend;
    if (recentImprovement > 5) trend = 'strong_recent_improvement';
    else if (recentImprovement > 2) trend = 'moderate_recent_improvement';
    else if (recentImprovement > -2) trend = 'stable_recent';
    else if (recentImprovement > -5) trend = 'moderate_recent_decline';
    else trend = 'strong_recent_decline';

    return {
      'trend': trend,
      'recentImprovement': recentImprovement,
      'recentScores': recentScores,
    };
  }

  // التصنيف النهائي الذكي
  Map<String, dynamic> _determineFinalClassification({
    required double simpleImprovement,
    required double trendSlope,
    required String stability,
    required String recentTrend,
    required double averageScore,
    required int evaluationCount,
    required double firstScore,
    required double lastScore,
  }) {
    // تقييم الثقة
    String confidence = 'medium';
    if (evaluationCount >= 5 && trendSlope.abs() > 0.05) confidence = 'high';
    if (evaluationCount < 3) confidence = 'low';

    // تحديد الاتجاه الأساسي
    String primaryTrend;
    Color trendColor;
    IconData trendIcon;
    String message;
    String detailedMessage;

    // تحليل متعدد العوامل
    final bool hasStrongImprovement = simpleImprovement > 15 || trendSlope > 0.15;
    final bool hasModerateImprovement = simpleImprovement > 5 || trendSlope > 0.05;
    final bool hasStablePerformance = simpleImprovement.abs() < 5 && trendSlope.abs() < 0.03;
    final bool hasModerateDecline = simpleImprovement < -5 || trendSlope < -0.05;
    final bool hasStrongDecline = simpleImprovement < -15 || trendSlope < -0.15;

    final bool isConsistent = stability == 'very_stable' || stability == 'stable';
    final bool hasRecentImprovement = recentTrend.contains('improvement');
    final bool hasRecentDecline = recentTrend.contains('decline');

    // التصنيف النهائي
    if (hasStrongImprovement && isConsistent) {
      primaryTrend = 'exceptional_improvement';
      trendColor = AppColors.success;
      trendIcon = Icons.trending_up;
      message = 'Exceptional Progress! 🌟';
      detailedMessage = 'Outstanding consistent improvement with strong growth trajectory';
    }
    else if (hasStrongImprovement) {
      primaryTrend = 'significant_improvement';
      trendColor = Color(0xFF27AE60);
      trendIcon = Icons.trending_up;
      message = 'Excellent Progress! 🎉';
      detailedMessage = 'Significant improvement observed, though with some variability';
    }
    else if (hasModerateImprovement && hasRecentImprovement) {
      primaryTrend = 'accelerating_improvement';
      trendColor = AppColors.info;
      trendIcon = Icons.trending_up;
      message = 'Steady Improvement 📈';
      detailedMessage = 'Consistent improvement with positive recent momentum';
    }
    else if (hasModerateImprovement) {
      primaryTrend = 'moderate_improvement';
      trendColor = AppColors.primary;
      trendIcon = Icons.trending_up;
      message = 'Good Progress 📈';
      detailedMessage = 'Steady improvement maintained over time';
    }
    else if (hasStablePerformance && isConsistent) {
      primaryTrend = 'very_stable';
      trendColor = AppColors.textGray;
      trendIcon = Icons.trending_flat;
      message = 'Very Stable Performance 🔄';
      detailedMessage = 'Highly consistent performance with minimal fluctuations';
    }
    else if (hasStablePerformance) {
      primaryTrend = 'stable';
      trendColor = AppColors.warning;
      trendIcon = Icons.trending_flat;
      message = 'Stable Performance ➡️';
      detailedMessage = 'Overall stable performance with normal variations';
    }
    else if (hasModerateDecline && hasRecentDecline) {
      primaryTrend = 'accelerating_decline';
      trendColor = AppColors.error;
      trendIcon = Icons.trending_down;
      message = 'Growing Concerns 📉';
      detailedMessage = 'Moderate decline with concerning recent trend';
    }
    else if (hasModerateDecline) {
      primaryTrend = 'moderate_decline';
      trendColor = Color(0xFFE67E22);
      trendIcon = Icons.trending_down;
      message = 'Needs Attention 📉';
      detailedMessage = 'Moderate decline observed, requires intervention';
    }
    else if (hasStrongDecline) {
      primaryTrend = 'significant_decline';
      trendColor = Color(0xFFC0392B);
      trendIcon = Icons.trending_down;
      message = 'Significant Decline! ⚠️';
      detailedMessage = 'Major decline detected, immediate attention required';
    }
    else {
      primaryTrend = 'mixed_pattern';
      trendColor = AppColors.primaryLight;
      trendIcon = Icons.auto_graph;
      message = 'Mixed Pattern 🔄';
      detailedMessage = 'Complex performance pattern with varying trends';
    }

    // توصيات بناءً على التحليل
    final recommendations = _generateRecommendations(
      primaryTrend: primaryTrend,
      stability: stability,
      recentTrend: recentTrend,
      averageScore: averageScore,
      evaluationCount: evaluationCount,
    );

    return {
      'trend': primaryTrend,
      'message': message,
      'detailedMessage': detailedMessage,
      'improvement': simpleImprovement,
      'trendColor': trendColor,
      'trendIcon': trendIcon,
      'firstScore': firstScore,
      'lastScore': lastScore,
      'averageScore': averageScore,
      'evaluationCount': evaluationCount,
      'confidence': confidence,
      'stability': stability,
      'recentTrend': recentTrend,
      'trendSlope': trendSlope,
      'recommendations': recommendations,
      'hasEnoughData': true,
    };
  }

  // توليد توصيات ذكية
  List<String> _generateRecommendations({
    required String primaryTrend,
    required String stability,
    required String recentTrend,
    required double averageScore,
    required int evaluationCount,
  }) {
    final recommendations = <String>[];

    // توصيات بناءً على الاتجاه
    if (primaryTrend.contains('improvement')) {
      recommendations.add('Continue current intervention strategies');
      if (primaryTrend.contains('exceptional') || primaryTrend.contains('significant')) {
        recommendations.add('Consider advancing to more challenging goals');
      }
    }

    if (primaryTrend.contains('decline')) {
      recommendations.add('Review and adjust current intervention strategies');
      recommendations.add('Consider additional assessment to identify challenges');
      if (primaryTrend.contains('significant')) {
        recommendations.add('Urgent intervention recommended');
      }
    }

    if (primaryTrend.contains('stable')) {
      recommendations.add('Maintain consistent intervention approach');
      if (averageScore < 50) {
        recommendations.add('Consider intensifying support for breakthrough');
      }
    }

    // توصيات بناءً على الاستقرار
    if (stability.contains('high_volatility')) {
      recommendations.add('Focus on consistency and routine in sessions');
      recommendations.add('Monitor for external factors affecting performance');
    }

    if (stability.contains('very_stable')) {
      recommendations.add('Stable pattern allows for predictable progress planning');
    }

    // توصيات بناءً على التقدم الأخير
    if (recentTrend.contains('recent_improvement')) {
      recommendations.add('Recent positive trend - capitalize on current momentum');
    }

    if (recentTrend.contains('recent_decline')) {
      recommendations.add('Address recent challenges promptly');
    }

    // توصيات عامة
    if (evaluationCount < 4) {
      recommendations.add('More evaluations needed for comprehensive analysis');
    }

    if (averageScore < 40) {
      recommendations.add('Consider foundational skill development focus');
    } else if (averageScore > 80) {
      recommendations.add('Focus on advanced skill development and maintenance');
    }

    return recommendations;
  }

  Widget _buildQuickProgress(List<dynamic> evaluations) {
    final safeEvaluations = _safeList(evaluations);
    if (safeEvaluations.length < 2) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textGray.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.info, size: 20, color: AppColors.warning),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Need more evaluations to show progress',
                style: TextStyle(fontSize: 14, color: AppColors.textGray, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    final progressAnalysis = _analyzeProgress(evaluations);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: progressAnalysis['trendColor'].withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: progressAnalysis['trendColor'].withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: progressAnalysis['trendColor'].withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(progressAnalysis['trendIcon'], size: 20, color: progressAnalysis['trendColor']),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progressAnalysis['message'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: progressAnalysis['trendColor'],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${progressAnalysis['firstScore']?.toInt() ?? 0}% → ${progressAnalysis['lastScore']?.toInt() ?? 0}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: progressAnalysis['trendColor'].withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${progressAnalysis['improvement'] > 0 ? '+' : ''}${progressAnalysis['improvement']?.toStringAsFixed(1) ?? '0.0'}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: progressAnalysis['trendColor'],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    try {
      if (date.isEmpty) return date;
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  // دوال مساعدة للتعامل مع البيانات بشكل آمن
  String _safeString(dynamic value) {
    return value?.toString() ?? '';
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final filteredChildren = _filteredChildren;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Children',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadChildren,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Loading children...',
              style: TextStyle(fontSize: 16, color: AppColors.textDark, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      )
          : errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.warning),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage,
                style: TextStyle(fontSize: 16, color: AppColors.textDark, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadChildren,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: Text('Try Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Search and filter section
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search children by name or diagnosis...',
                      hintStyle: TextStyle(color: AppColors.textGray),
                      prefixIcon: Icon(Icons.search, color: AppColors.primary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                SizedBox(height: 16),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _diagnosisTypes.map((diagnosis) {
                      final isSelected = _selectedFilter == diagnosis;
                      return Container(
                        margin: EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            diagnosis == 'all' ? 'All Children' : diagnosis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          selected: isSelected,
                          backgroundColor: AppColors.surface,
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = selected ? diagnosis : 'all';
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.textGray.withOpacity(0.3),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Results count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredChildren.length} children found',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (filteredChildren.length != children.length)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedFilter = 'all';
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      'Clear filters',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8),

          // Children list
          Expanded(
            child: filteredChildren.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 80, color: AppColors.textLight),
                  SizedBox(height: 20),
                  Text(
                    'No children found',
                    style: TextStyle(fontSize: 18, color: AppColors.textGray, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Try adjusting your search or filters',
                    style: TextStyle(fontSize: 14, color: AppColors.textLight),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadChildren,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: 20),
                itemCount: filteredChildren.length,
                itemBuilder: (context, index) {
                  final child = filteredChildren[index];
                  return _buildChildCard(child);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}