// lib/screens/child_details_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/specialist_children_service.dart';
import '../services/progress_analysis_service.dart';
import 'comparison_analysis_screen.dart';
import 'add_session_screen.dart';
import '../theme/app_colors.dart';

class ChildDetailsScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ChildDetailsScreen({
    Key? key,
    required this.childId,
    required this.childName,
  }) : super(key: key);

  @override
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen> {
  Map<String, dynamic>? childData;
  bool isLoading = true;
  String errorMessage = '';

  // Progress Analysis State
  Map<String, dynamic>? _progressAnalysis;
  bool _isAnalyzing = false;
  String _analysisError = '';

  @override
  void initState() {
    super.initState();
    _loadChildDetails();
  }

  void _debugCheckAnalysisData() {
    if (_progressAnalysis != null) {
      print('=== FULL ANALYSIS DATA DEBUG ===');
      print('Professional Analysis: ${_progressAnalysis!['professional_analysis']}');

      final professionalAnalysis = _progressAnalysis!['professional_analysis'];
      if (professionalAnalysis != null) {
        print('Next Session Object: ${professionalAnalysis['next_session']}');
        print('Next Session Type: ${professionalAnalysis['next_session']?.runtimeType}');

        if (professionalAnalysis['next_session'] != null) {
          final nextSession = professionalAnalysis['next_session'];
          print('Suggested Date: ${nextSession['suggested_date']}');
          print('Suggested Date Type: ${nextSession['suggested_date']?.runtimeType}');
        }
      }
      print('Analysis Full Structure:');
      _progressAnalysis!.forEach((key, value) {
        print('$key: $value');
      });
      print('==============================');
    }
  }

  Future<void> _loadChildDetails() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
        _analysisError = '';
      });

      final response = await SpecialistChildrenService.getChildDetails(widget.childId);

      if (response['success'] == true) {
        setState(() {
          childData = response['data'];
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load child details';
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

  Future<void> _loadComprehensiveAnalysis() async {
    try {
      setState(() {
        _isAnalyzing = true;
        _analysisError = '';
      });

      final analysis = await ProgressAnalysisService.analyzeChildProgress(widget.childId);

      setState(() {
        _progressAnalysis = analysis;
      });
      _debugCheckAnalysisData();
    } catch (e) {
      setState(() {
        _analysisError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // Helper Functions
  List<dynamic> _safeList(dynamic list) => list is List ? list : [];
  Map<String, dynamic> _safeMap(dynamic map) => map is Map<String, dynamic> ? map : {};
  String _safeString(dynamic value) => value?.toString() ?? 'N/A';

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatDate(String date) {
    try {
      if (date.isEmpty || date == 'N/A') return date;
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  // ========== UI COMPONENTS FOR ANALYSIS ==========

  Widget _buildAnalysisSection() {
    if (_isAnalyzing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Generating AI Analysis...',
              style: TextStyle(fontSize: 16, color: AppColors.textGray),
            ),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    if (_analysisError.isNotEmpty) {
      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning),
        ),
        child: Column(
          children: [
            Icon(Icons.warning, color: AppColors.warning, size: 40),
            SizedBox(height: 12),
            Text(
              'Analysis Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.warning),
            ),
            SizedBox(height: 8),
            Text(
              _analysisError,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.warning),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadComprehensiveAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_progressAnalysis == null) {
      return Container(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.analytics, size: 80, color: AppColors.textLight),
            SizedBox(height: 16),
            Text(
              'Comprehensive Progress Analysis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Get detailed AI-powered analysis of child progress with insights and recommendations',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textGray, height: 1.4),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadComprehensiveAnalysis,
              icon: Icon(Icons.insights),
              label: Text('Generate AI Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ],
        ),
      );
    }

    return _buildAnalysisResults(_progressAnalysis!);
  }

  Widget _buildAnalysisResults(Map<String, dynamic> analysis) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildReportHeader(analysis),
          SizedBox(height: 20),
          _buildProfileSection(analysis['profile']),
          SizedBox(height: 16),
          _buildSummarySection(analysis['summary']),
          SizedBox(height: 16),
          if (analysis['performance_metrics'] != null)
            Column(
              children: [
                _buildPerformanceMetrics(analysis['performance_metrics']),
                SizedBox(height: 16),
              ],
            ),
          if (analysis['professional_analysis'] != null)
            Column(
              children: [
                _buildProfessionalAnalysis(analysis['professional_analysis']),
                SizedBox(height: 16),
              ],
            ),
          if (analysis['action_plan'] != null)
            Column(
              children: [
                _buildActionPlan(analysis['action_plan']),
                SizedBox(height: 16),
              ],
            ),
          if (analysis['evaluation_history'] != null)
            Column(
              children: [
                _buildEvaluationHistory(analysis['evaluation_history']),
                SizedBox(height: 16),
              ],
            ),
          _buildMetadata(analysis['metadata']),
        ],
      ),
    );
  }

  Widget _buildReportHeader(Map<String, dynamic> analysis) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, size: 40, color: Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            'Comprehensive Progress Report',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'AI-Powered Analysis',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Generated: ${_safeString(analysis['metadata']?['analysis_date'])}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(Map<String, dynamic>? profile) {
    if (profile == null) return SizedBox();

    final child = _safeMap(profile['child']);
    final specialist = _safeMap(profile['specialist']);
    final parent = _safeMap(profile['parent_contact']);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: AppColors.primary, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildProfileItem('Child Name', child['name']),
            _buildProfileItem('Age', '${child['age']} years'),
            _buildProfileItem('Gender', child['gender']),
            _buildProfileItem('Diagnosis', child['diagnosis']),
            if (_safeString(child['medical_history']).isNotEmpty && _safeString(child['medical_history']) != 'N/A')
              _buildProfileItem('Medical History', child['medical_history']),
            _buildProfileItem('Institution', child['institution']),
            SizedBox(height: 16),
            Divider(color: AppColors.accent2),
            SizedBox(height: 16),
            _buildProfileItem('Specialist', specialist['name']),
            _buildProfileItem('Specialization', specialist['specialization']),
            _buildProfileItem('Experience', '${specialist['experience_years']} years'),
            SizedBox(height: 16),
            Divider(color: AppColors.accent2),
            SizedBox(height: 16),
            _buildProfileItem('Parent Name', parent['name']),
            _buildProfileItem('Parent Phone', parent['phone']),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(Map<String, dynamic>? summary) {
    if (summary == null) return SizedBox();

    final evaluations = _safeMap(summary['evaluations']);
    final sessions = _safeMap(summary['sessions']);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assessment, color: AppColors.info, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Progress Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Evaluations',
                    evaluations['total']?.toString() ?? '0',
                    Icons.assessment,
                    AppColors.success,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Sessions',
                    sessions['total']?.toString() ?? '0',
                    Icons.event,
                    AppColors.info,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildSummaryDetail('First Evaluation', evaluations['first_date']),
            _buildSummaryDetail('Latest Evaluation', evaluations['latest_date']),
            _buildSummaryDetail('Evaluation Types', (evaluations['types_used'] as List?)?.join(', ') ?? 'N/A'),
            _buildSummaryDetail('Duration', '${evaluations['duration_days']} days'),
            _buildSummaryDetail('Completed Sessions', sessions['completed']?.toString() ?? '0'),
            _buildSummaryDetail('Last Session', sessions['last_session_date'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDetail(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(Map<String, dynamic>? metrics) {
    if (metrics == null) return SizedBox();

    final scoreAnalysis = _safeMap(metrics['score_analysis']);
    final statisticalIndicators = _safeMap(metrics['statistical_indicators']);
    final trendAnalysis = _safeMap(metrics['trend_analysis']);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.trending_up, color: AppColors.success, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Performance Metrics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Score Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMetricChip('Current Score', '${scoreAnalysis['current_score']}%', AppColors.success),
                _buildMetricChip('Starting Score', '${scoreAnalysis['starting_score']}%', AppColors.info),
                _buildMetricChip('Average Score', '${scoreAnalysis['average_score']}%', AppColors.warning),
                _buildMetricChip('Improvement', '${scoreAnalysis['improvement_percentage']}%', AppColors.primary),
                _buildMetricChip('Total Change', '${scoreAnalysis['total_improvement']} points', AppColors.accent3),
              ],
            ),
            SizedBox(height: 24),
            Divider(color: AppColors.accent2),
            SizedBox(height: 16),
            Text(
              'Trend Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            _buildTrendItem('Overall Direction', trendAnalysis['overall_direction']),
            _buildTrendItem('Consistency', trendAnalysis['consistency']),
            _buildTrendItem('Plateau Status', trendAnalysis['plateau_status']),
            _buildTrendItem('Recent Trend', trendAnalysis['recent_performance']?['trend']),
            SizedBox(height: 24),
            Divider(color: AppColors.accent2),
            SizedBox(height: 16),
            Text(
              'Statistical Indicators',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            _buildStatItem('Standard Deviation',
                statisticalIndicators['standard_deviation']?['value'],
                statisticalIndicators['standard_deviation']?['interpretation']),
            _buildStatItem('R² Value',
                statisticalIndicators['r_squared']?['value'],
                statisticalIndicators['r_squared']?['interpretation']),
            _buildStatItem('Improvement Rate',
                statisticalIndicators['improvement_rate']?['value'],
                statisticalIndicators['improvement_rate']?['interpretation']),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, String? value) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value, String? interpretation) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  '$label:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value?.toString() ?? 'N/A',
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (interpretation != null && interpretation != 'N/A')
            Padding(
              padding: EdgeInsets.only(left: 18, top: 4),
              child: Text(
                interpretation,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfessionalAnalysis(Map<String, dynamic>? analysis) {
    if (analysis == null) return SizedBox();

    final bool isInitialPlan = _progressAnalysis?['analysis_type'] == 'initial_plan';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.psychology, color: AppColors.primary, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  isInitialPlan ? 'Initial Treatment Plan' : 'Professional Analysis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (analysis['next_session'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Session',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildNextSessionCard(analysis['next_session']),
                  SizedBox(height: 20),
                ],
              ),
            _buildNextSessionSection(analysis),
            if (analysis['next_evaluation'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Evaluation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildNextEvaluationCard(analysis['next_evaluation']),
                  SizedBox(height: 20),
                ],
              ),
            if (isInitialPlan)
              _buildInitialPlanContent(analysis)
            else
              _buildComprehensiveAnalysis(analysis),
          ],
        ),
      ),
    );
  }

  Widget _buildNextSessionSection(Map<String, dynamic> analysis) {
    final nextSession = analysis['next_session'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next Session Recommendation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 12),
        if (nextSession != null)
          _buildNextSessionCard(nextSession)
        else
          _buildDefaultNextSessionCard(),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDefaultNextSessionCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb_outline, color: AppColors.info, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'AI Session Recommendation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Based on the child\'s progress analysis, we recommend scheduling the next session soon to maintain momentum.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
              height: 1.5,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _onBookNowPressed({
                'suggested_date': _getNextAvailableDate(),
                'focus_areas': ['Continue current progress', 'Reinforce learned skills'],
                'preparation': 'Review previous session notes and prepare materials'
              }),
              icon: Icon(Icons.event_available, size: 20),
              label: Text('Book Recommended Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _convertDateFormat(String? inputDate) {
    print('Converting date: $inputDate');

    if (inputDate == null || inputDate.isEmpty || inputDate == 'N/A') {
      return _getNextAvailableDate();
    }

    try {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(inputDate)) {
        final date = DateTime.parse(inputDate);
        if (date.isAfter(DateTime.now())) {
          return inputDate;
        }
      }

      if (inputDate.contains(RegExp(r'[a-zA-Z]'))) {
        return _parseTextDateToIso(inputDate);
      }

      final date = DateTime.parse(inputDate);
      final formatted = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      if (date.isBefore(DateTime.now())) {
        return _getNextAvailableDate();
      }

      return formatted;

    } catch (e) {
      print('Error converting date "$inputDate": $e');
      return _getNextAvailableDate();
    }
  }

  String _parseTextDateToIso(String textDate) {
    try {
      final months = {
        'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
        'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
      };

      final lowerDate = textDate.toLowerCase();

      for (final month in months.keys) {
        if (lowerDate.contains(month)) {
          final regex = RegExp(r'(\d{1,2})\s*,?\s*(\d{4})?');
          final match = regex.firstMatch(textDate);

          if (match != null) {
            final day = int.parse(match.group(1)!);
            final year = match.group(2) != null ? int.parse(match.group(2)!) : DateTime.now().year;
            final monthNumber = months[month]!;

            final date = DateTime(year, monthNumber, day);

            if (date.isBefore(DateTime.now())) {
              return _getNextAvailableDate();
            }

            return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          }
        }
      }

      return _getNextAvailableDate();
    } catch (e) {
      print('Error in _parseTextDateToIso: $e');
      return _getNextAvailableDate();
    }
  }

  String _getNextAvailableDate() {
    final now = DateTime.now();
    DateTime nextDate = now.add(Duration(days: 1));

    int attempts = 0;
    while (attempts < 14) {
      if (nextDate.weekday != DateTime.friday &&
          nextDate.weekday != DateTime.saturday &&
          nextDate.isAfter(now)) {
        final formatted = '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';
        print('Generated next available date: $formatted');
        return formatted;
      }
      nextDate = nextDate.add(Duration(days: 1));
      attempts++;
    }

    final fallbackDate = now.add(Duration(days: 7));
    final formatted = '${fallbackDate.year}-${fallbackDate.month.toString().padLeft(2, '0')}-${fallbackDate.day.toString().padLeft(2, '0')}';
    print('Using fallback date: $formatted');
    return formatted;
  }

  Widget _buildNextSessionCard(Map<String, dynamic> nextSession) {
    _debugFullAnalysis();
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.calendar_today, color: AppColors.success, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Suggested Date: ${nextSession['suggested_date'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (nextSession['focus_areas'] != null && (nextSession['focus_areas'] as List).isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Focus Areas:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (nextSession['focus_areas'] as List).map((area) => Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      area.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
                SizedBox(height: 12),
              ],
            ),
          if (nextSession['preparation'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preparation:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  nextSession['preparation'].toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _onBookNowPressed(nextSession),
              icon: Icon(Icons.event_available, size: 20),
              label: Text('Book Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onBookNowPressed(Map<String, dynamic> nextSession) {
    print('Book Now Pressed - FULL ANALYSIS DATA:');

    final aiNextSession = _progressAnalysis?['professional_analysis']?['recommendations']?['next_session'];

    print('AI Next Session from professional_analysis: $aiNextSession');
    print('Raw nextSession data from action_plan: $nextSession');

    final Map<String, dynamic> sessionData;
    if (aiNextSession != null && aiNextSession['suggested_date'] != null) {
      print('Using AI data from professional_analysis');
      sessionData = {
        'suggested_date': aiNextSession['suggested_date'],
        'focus_areas': aiNextSession['focus_areas'] ?? ['General skill development'],
        'preparation': aiNextSession['preparation'] ?? 'Review progress analysis'
      };
    } else {
      print('Using fallback data from action_plan');
      sessionData = nextSession;
    }

    final suggestedDate = sessionData['suggested_date'];
    final focusAreas = sessionData['focus_areas'] as List<dynamic>?;

    print('FINAL - Using date: $suggestedDate');
    print('FINAL - Using focus areas: $focusAreas');

    final convertedDate = _convertDateFormat(suggestedDate?.toString());
    final finalFocusAreas = focusAreas?.cast<String>() ?? ['General skill development'];

    print('Converted Date: $convertedDate');
    print('Focus Areas: $finalFocusAreas');
    print('Child: ${widget.childName} (ID: ${widget.childId})');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSessionScreen(
          preSelectedDate: convertedDate,
          preSelectedFocusAreas: finalFocusAreas,
          childId: widget.childId,
          childName: widget.childName,
        ),
      ),
    ).then((_) {
      _loadChildDetails();
    });
  }

  void _debugFullAnalysis() {
    if (_progressAnalysis != null) {
      print('=== FULL AI ANALYSIS STRUCTURE ===');
      print('Professional Analysis: ${_progressAnalysis!['professional_analysis']}');
      print('Recommendations: ${_progressAnalysis!['professional_analysis']?['recommendations']}');
      print('Next Session in Recommendations: ${_progressAnalysis!['professional_analysis']?['recommendations']?['next_session']}');
      print('Action Plan: ${_progressAnalysis!['action_plan']}');
      print('====================================');
    }
  }

  Widget _buildInitialPlanContent(Map<String, dynamic> analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis['baseline_assessment'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Baseline Assessment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              _buildAssessmentSection(analysis['baseline_assessment']),
              SizedBox(height: 20),
            ],
          ),
        if (analysis['treatment_goals'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Treatment Goals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              _buildTreatmentGoals(analysis['treatment_goals']),
              SizedBox(height: 20),
            ],
          ),
        if (analysis['recommended_schedule'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommended Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              _buildScheduleCard(analysis['recommended_schedule']),
              SizedBox(height: 20),
            ],
          ),
        if (analysis['initial_focus_areas'] != null && (analysis['initial_focus_areas'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Initial Focus Areas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              ...(analysis['initial_focus_areas'] as List).map((area) => _buildFocusAreaCard(area)),
              SizedBox(height: 20),
            ],
          ),
        if (analysis['parent_instructions'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parent Instructions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              _buildParentInstructions(analysis['parent_instructions']),
              SizedBox(height: 20),
            ],
          ),
        if (analysis['success_indicators'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Success Indicators',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              _buildSuccessIndicators(analysis['success_indicators']),
            ],
          ),
      ],
    );
  }

  Widget _buildComprehensiveAnalysis(Map<String, dynamic> analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis['overall_assessment'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Assessment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis['overall_assessment']?['summary'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGray,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            analysis['overall_assessment']?['trend'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            analysis['overall_assessment']?['progress_level'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.info,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        if (analysis['strengths'] != null && (analysis['strengths'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Strengths',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              ...(analysis['strengths'] as List).map((strength) => _buildAnalysisItem(strength, AppColors.success)),
              SizedBox(height: 20),
            ],
          ),
        if (analysis['challenges'] != null && (analysis['challenges'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Challenges',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              ...(analysis['challenges'] as List).map((challenge) => _buildAnalysisItem(challenge, AppColors.warning)),
              SizedBox(height: 20),
            ],
          ),
        if (analysis['recommendations'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              _buildRecommendationsSection(analysis['recommendations']),
            ],
          ),
      ],
    );
  }

  Widget _buildAssessmentSection(Map<String, dynamic> assessment) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListSection('Current Abilities', assessment['current_abilities']),
          SizedBox(height: 16),
          _buildListSection('Main Challenges', assessment['main_challenges']),
          SizedBox(height: 16),
          _buildListSection('Behavioral Observations', assessment['behavioral_observations']),
          SizedBox(height: 16),
          if (assessment['initial_score_interpretation'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score Interpretation:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  assessment['initial_score_interpretation'],
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<dynamic>? items) {
    if (items == null || items.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildTreatmentGoals(Map<String, dynamic> goals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (goals['short_term'] != null && (goals['short_term'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Short Term Goals:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
              SizedBox(height: 12),
              ...(goals['short_term'] as List).map((goal) => _buildGoalCard(goal, AppColors.success)),
              SizedBox(height: 16),
            ],
          ),
        if (goals['long_term'] != null && (goals['long_term'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Long Term Goals:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
              SizedBox(height: 12),
              ...(goals['long_term'] as List).map((goal) => _buildGoalCard(goal, AppColors.info)),
            ],
          ),
      ],
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal['goal'] ?? 'N/A',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Timeline: ${goal['timeline'] ?? 'N/A'}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGray,
            ),
          ),
          if (goal['success_criteria'] != null)
            Text(
              'Success: ${goal['success_criteria']}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScheduleItem('Frequency', schedule['frequency']),
          _buildScheduleItem('Duration', schedule['duration']),
          _buildScheduleItem('Best Timing', schedule['best_timing']),
          if (schedule['rationale'] != null) ...[
            SizedBox(height: 12),
            Text(
              'Rationale: ${schedule['rationale']}',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textGray,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusAreaCard(Map<String, dynamic> area) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(area['priority']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  area['priority']?.toString().toUpperCase() ?? 'N/A',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  area['skill'] ?? 'N/A',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Approach: ${area['approach'] ?? 'N/A'}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGray,
            ),
          ),
          if (area['activities'] != null && (area['activities'] as List).isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              'Activities: ${(area['activities'] as List).join(', ')}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
              ),
            ),
          ],
          if (area['expected_progress'] != null) ...[
            SizedBox(height: 6),
            Text(
              'Expected: ${area['expected_progress']}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high': return AppColors.error;
      case 'medium': return AppColors.warning;
      case 'low': return AppColors.success;
      default: return AppColors.textLight;
    }
  }

  Widget _buildNextEvaluationCard(Map<String, dynamic> nextEval) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested Date: ${nextEval['suggested_date'] ?? 'N/A'}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 12),
          _buildListSection('What to Assess', nextEval['what_to_assess']),
          SizedBox(height: 12),
          _buildListSection('Expected Improvements', nextEval['expected_improvements']),
        ],
      ),
    );
  }

  Widget _buildParentInstructions(Map<String, dynamic> instructions) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListSection('Daily Activities', instructions['daily_activities']),
          SizedBox(height: 16),
          _buildListSection('Environment Modifications', instructions['environment_modifications']),
          SizedBox(height: 16),
          _buildListSection('What to Monitor', instructions['what_to_monitor']),
          SizedBox(height: 16),
          _buildListSection('Communication Tips', instructions['communication_tips']),
        ],
      ),
    );
  }

  Widget _buildSuccessIndicators(Map<String, dynamic> indicators) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (indicators['week_1'] != null) _buildTimelineIndicator('Week 1', indicators['week_1']),
          if (indicators['week_2'] != null) _buildTimelineIndicator('Week 2', indicators['week_2']),
          if (indicators['week_4'] != null) _buildTimelineIndicator('Week 4', indicators['week_4']),
          if (indicators['month_3'] != null) _buildTimelineIndicator('Month 3', indicators['month_3']),
        ],
      ),
    );
  }

  Widget _buildTimelineIndicator(String timeline, List<dynamic>? indicators) {
    if (indicators == null || indicators.isEmpty) return SizedBox();

    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeline,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 8),
          ...indicators.map((indicator) => Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, size: 16, color: AppColors.success),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    indicator.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(Map<String, dynamic> item, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['area'] ?? 'N/A',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            item['description'] ?? 'N/A',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGray,
              height: 1.4,
            ),
          ),
          if (item['progress'] != null) ...[
            SizedBox(height: 6),
            Text(
              'Progress: ${item['progress']}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(Map<String, dynamic>? recommendations) {
    if (recommendations == null) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recommendations['session_schedule'] != null)
          _buildRecommendationCard(
            'Session Schedule',
            recommendations['session_schedule'],
            Icons.schedule,
            AppColors.info,
          ),
        if (recommendations['next_session'] != null)
          _buildRecommendationCard(
            'Next Session',
            recommendations['next_session'],
            Icons.event,
            AppColors.success,
          ),
        if (recommendations['intensity_adjustment'] != null)
          _buildRecommendationCard(
            'Intensity Adjustment',
            recommendations['intensity_adjustment'],
            Icons.trending_up,
            AppColors.warning,
          ),
      ],
    );
  }

  Widget _buildRecommendationCard(String title, Map<String, dynamic> data, IconData icon, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...data.entries.map((entry) => Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '${_capitalize(entry.key)}: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value?.toString() ?? 'N/A',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).replaceAll('_', ' ');
  }

  Widget _buildActionPlan(Map<String, dynamic>? actionPlan) {
    if (actionPlan == null) return SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assignment, color: AppColors.warning, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Action Plan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (actionPlan['next_session'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Session',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildNextSessionCard(actionPlan['next_session']),
                  SizedBox(height: 20),
                ],
              ),
            if (actionPlan['quick_recommendations'] != null && (actionPlan['quick_recommendations'] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Recommendations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  ...(actionPlan['quick_recommendations'] as List).map((rec) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.arrow_right, size: 20, color: AppColors.success),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            rec.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textGray,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _onBookNowPressed({
                        'suggested_date': _getNextAvailableDate(),
                        'focus_areas': ['Implement action plan recommendations'],
                        'preparation': 'Review the complete action plan before the session'
                      }),
                      icon: Icon(Icons.event_available, size: 20),
                      label: Text('Schedule Action Plan Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationHistory(List<dynamic>? history) {
    if (history == null || history.isEmpty) return SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.history, color: AppColors.primary, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Evaluation History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ...history.map((eval) => _buildEvaluationCard(eval)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationCard(Map<String, dynamic> eval) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session ${eval['session_number']}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getScoreColor(_safeDouble(eval['score'])).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${eval['score']}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _getScoreColor(_safeDouble(eval['score'])),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            eval['date'] ?? 'N/A',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Type: ${eval['type'] ?? 'N/A'}',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 13,
            ),
          ),
          if (eval['score_change'] != null && eval['score_change'] != 0) ...[
            SizedBox(height: 4),
            Text(
              'Change: ${eval['score_change'] > 0 ? '+' : ''}${eval['score_change']}%',
              style: TextStyle(
                color: eval['score_change'] > 0 ? AppColors.success : AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (eval['notes'] != null && eval['notes'].toString().isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Notes: ${eval['notes']}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 75) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis Information',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            _buildMetadataItem('Model', metadata['analysis_model']),
            _buildMetadataItem('Analysis Date', metadata['analysis_date']),
            if (metadata['data_quality'] != null)
              _buildMetadataItem('Data Quality', metadata['data_quality']?['recommendation']),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataItem(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== EXISTING TABS ==========

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          value.isNotEmpty ? value : 'Not available',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textGray,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(dynamic session) {
    final safeSession = _safeMap(session);
    final date = _safeString(safeSession['date']);
    final time = _safeString(safeSession['time']);
    final sessionType = _safeString(safeSession['session_type']);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.event, color: AppColors.primary, size: 24),
        ),
        title: Text(
          'Session ${_formatDate(date)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          'Time: ${time.isNotEmpty ? time : "Not specified"} - Type: ${sessionType.isNotEmpty ? sessionType : "Not specified"}',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textGray,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    final child = _safeMap(childData?['child']);
    final parent = _safeMap(child['parent']);
    final diagnosis = _safeMap(child['diagnosis']);
    final institution = _safeMap(child['current_institution']);

    return SingleChildScrollView(
      padding: EdgeInsets.all(8),
      child: Column(
        children: [
          _buildInfoCard('Full Name', _safeString(child['full_name']), Icons.person),
          _buildInfoCard('Date of Birth', _formatDate(_safeString(child['date_of_birth'])), Icons.cake),
          _buildInfoCard('Gender', _safeString(child['gender']), Icons.people),
          _buildInfoCard('Diagnosis', _safeString(diagnosis['name']), Icons.medical_services),
          _buildInfoCard('Institution', _safeString(institution['name']), Icons.school),
          _buildInfoCard('Parent', _safeString(parent['full_name']), Icons.family_restroom),
          _buildInfoCard('Email', _safeString(parent['email']), Icons.email),
          _buildInfoCard('Phone', _safeString(parent['phone']), Icons.phone),
          if (_safeString(child['medical_history']).isNotEmpty && _safeString(child['medical_history']) != 'N/A')
            _buildInfoCard('Medical History', _safeString(child['medical_history']), Icons.medical_information),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    final sessions = _safeList(childData?['sessions']);

    return sessions.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event, size: 64, color: AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'No sessions available',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    )
        : ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        return _buildSessionCard(sessions[index]);
      },
    );
  }

  Widget _buildEvaluationsTab() {
    return _buildAnalysisSection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.childName.isNotEmpty ? widget.childName : 'Child Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComparisonAnalysisScreen(
                childId: widget.childId,
                childName: widget.childName,
              ),
            ),
          );
        },
        icon: Icon(Icons.compare_arrows, size: 20),
        label: Text(
          'Compare',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading child details...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 64, color: AppColors.warning),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadChildDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 2,
              ),
              child: Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      )
          : childData == null
          ? Center(
        child: Text(
          'No data available',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textGray,
            fontWeight: FontWeight.w500,
          ),
        ),
      )
          : DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(
                    icon: Icon(Icons.person_outline, size: 20),
                    text: 'Information',
                  ),
                  Tab(
                    icon: Icon(Icons.analytics_outlined, size: 20),
                    text: 'Progress Analysis',
                  ),
                  Tab(
                    icon: Icon(Icons.event_outlined, size: 20),
                    text: 'Sessions',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildInfoTab(),
                  _buildEvaluationsTab(),
                  _buildSessionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}