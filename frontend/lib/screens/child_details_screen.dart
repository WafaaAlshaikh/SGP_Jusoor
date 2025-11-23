// lib/screens/child_details_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/specialist_children_service.dart';
import '../services/progress_analysis_service.dart';
import 'comparison_analysis_screen.dart';
import 'add_session_screen.dart';
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
    print('=== 🔥 FULL ANALYSIS DATA DEBUG ===');
    print('Professional Analysis: ${_progressAnalysis!['professional_analysis']}');
    
    final professionalAnalysis = _progressAnalysis!['professional_analysis'];
    if (professionalAnalysis != null) {
      print('Next Session Object: ${professionalAnalysis['next_session']}');
      print('Next Session Type: ${professionalAnalysis['next_session']?.runtimeType}');
      
      // 🔥 تحقق عميق من next_session
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

  // 🔥 دالة لتحميل التحليل الشامل
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
            CircularProgressIndicator(color: Color(0xFF7815A0)),
            SizedBox(height: 16),
            Text(
              'Generating AI Analysis...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 40),
            SizedBox(height: 12),
            Text(
              'Analysis Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800]),
            ),
            SizedBox(height: 8),
            Text(
              _analysisError,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange[700]),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadComprehensiveAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7815A0),
                foregroundColor: Colors.white,
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
            Icon(Icons.analytics, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Comprehensive Progress Analysis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Get detailed AI-powered analysis of child progress with insights and recommendations',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadComprehensiveAnalysis,
              icon: Icon(Icons.insights),
              label: Text('Generate AI Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7815A0),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    // عرض نتائج التحليل
    return _buildAnalysisResults(_progressAnalysis!);
  }

  Widget _buildAnalysisResults(Map<String, dynamic> analysis) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // رأس التقرير
          _buildReportHeader(analysis),
          SizedBox(height: 20),

          // معلومات الملف الشخصي
          _buildProfileSection(analysis['profile']),
          SizedBox(height: 16),

          // الملخص
          _buildSummarySection(analysis['summary']),
          SizedBox(height: 16),

          // مقاييس الأداء
          if (analysis['performance_metrics'] != null)
            Column(
              children: [
                _buildPerformanceMetrics(analysis['performance_metrics']),
                SizedBox(height: 16),
              ],
            ),

          // التحليل المهني
          if (analysis['professional_analysis'] != null)
            Column(
              children: [
                _buildProfessionalAnalysis(analysis['professional_analysis']),
                SizedBox(height: 16),
              ],
            ),

          // خطة العمل
          if (analysis['action_plan'] != null)
            Column(
              children: [
                _buildActionPlan(analysis['action_plan']),
                SizedBox(height: 16),
              ],
            ),

          // سجل التقييمات
          if (analysis['evaluation_history'] != null)
            Column(
              children: [
                _buildEvaluationHistory(analysis['evaluation_history']),
                SizedBox(height: 16),
              ],
            ),

          // معلومات النظام
          _buildMetadata(analysis['metadata']),
        ],
      ),
    );
  }

  Widget _buildReportHeader(Map<String, dynamic> analysis) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7815A0), Color(0xFF9C27B0)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, size: 50, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'Comprehensive Progress Report',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'AI-Powered Analysis',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Generated: ${_safeString(analysis['metadata']?['analysis_date'])}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white60,
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Color(0xFF7815A0), size: 24),
                SizedBox(width: 12),
                Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Child Info
            _buildProfileItem('Child Name', child['name']),
            _buildProfileItem('Age', '${child['age']} years'),
            _buildProfileItem('Gender', child['gender']),
            _buildProfileItem('Diagnosis', child['diagnosis']),
            if (_safeString(child['medical_history']).isNotEmpty && _safeString(child['medical_history']) != 'N/A')
              _buildProfileItem('Medical History', child['medical_history']),
            _buildProfileItem('Institution', child['institution']),

            Divider(height: 24),

            // Specialist Info
            _buildProfileItem('Specialist', specialist['name']),
            _buildProfileItem('Specialization', specialist['specialization']),
            _buildProfileItem('Experience', '${specialist['experience_years']} years'),

            Divider(height: 24),

            // Parent Contact
            _buildProfileItem('Parent Name', parent['name']),
            _buildProfileItem('Parent Phone', parent['phone']),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500),
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: Colors.blue, size: 24), // ✅ تم التصحيح هنا
                SizedBox(width: 12),
                Text(
                  'Progress Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Evaluations',
                    evaluations['total']?.toString() ?? '0',
                    Icons.assessment,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Sessions',
                    sessions['total']?.toString() ?? '0',
                    Icons.event,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: color),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDetail(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(Map<String, dynamic>? metrics) {
    if (metrics == null) return SizedBox();

    final scoreAnalysis = _safeMap(metrics['score_analysis']);
    final statisticalIndicators = _safeMap(metrics['statistical_indicators']);
    final trendAnalysis = _safeMap(metrics['trend_analysis']);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Text(
                  'Performance Metrics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Score Analysis
            Text(
              'Score Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMetricChip('Current Score', '${scoreAnalysis['current_score']}%', Colors.green),
                _buildMetricChip('Starting Score', '${scoreAnalysis['starting_score']}%', Colors.blue),
                _buildMetricChip('Average Score', '${scoreAnalysis['average_score']}%', Colors.orange),
                _buildMetricChip('Improvement', '${scoreAnalysis['improvement_percentage']}%', Colors.purple),
                _buildMetricChip('Total Change', '${scoreAnalysis['total_improvement']} points', Colors.teal),
              ],
            ),

            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 16),

            // Trend Analysis
            Text(
              'Trend Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            SizedBox(height: 12),
            _buildTrendItem('Overall Direction', trendAnalysis['overall_direction']),
            _buildTrendItem('Consistency', trendAnalysis['consistency']),
            _buildTrendItem('Plateau Status', trendAnalysis['plateau_status']),
            _buildTrendItem('Recent Trend', trendAnalysis['recent_performance']?['trend']),

            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 16),

            // Statistical Indicators
            Text(
              'Statistical Indicators',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 3, child: Text(value ?? 'N/A', style: TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value, String? interpretation) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 2, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w500))),
              Expanded(flex: 3, child: Text(value?.toString() ?? 'N/A')),
            ],
          ),
          if (interpretation != null && interpretation != 'N/A')
            Padding(
              padding: EdgeInsets.only(left: 8, top: 2),
              child: Text(
                interpretation,
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfessionalAnalysis(Map<String, dynamic>? analysis) {
    if (analysis == null) return SizedBox();

    // 🔥 التحقق من نوع التحليل
    final bool isInitialPlan = _progressAnalysis?['analysis_type'] == 'initial_plan';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple, size: 24),
                SizedBox(width: 12),
                Text(
                  isInitialPlan ? 'Initial Treatment Plan' : 'Professional Analysis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 🔥 قسم Next Session - يظهر دائماً إذا كانت البيانات متوفرة
            if (analysis['next_session'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Session',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8),
                  _buildNextSessionCard(analysis['next_session']),
                  SizedBox(height: 16),
                ],
              ),
            _buildNextSessionSection(analysis),

            // 🔥 قسم Next Evaluation - يظهر دائماً إذا كانت البيانات متوفرة
            if (analysis['next_evaluation'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Evaluation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8),
                  _buildNextEvaluationCard(analysis['next_evaluation']),
                  SizedBox(height: 16),
                ],
              ),

            // العرض العادي بناءً على نوع التحليل
            if (isInitialPlan)
              _buildInitialPlanContent(analysis) // ⬅️ محتوى الـ initial plan بدون next session
            else
              _buildComprehensiveAnalysis(analysis), // ⬅️ العرض العادي
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
        ),
        SizedBox(height: 8),

        if (nextSession != null)
          _buildNextSessionCard(nextSession)
        else
          _buildDefaultNextSessionCard(),

        SizedBox(height: 16),
      ],
    );
  }

// 🔥 بطاقة افتراضية عندما لا تكون هناك توصية
  Widget _buildDefaultNextSessionCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Session Recommendation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800]),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Based on the child\'s progress analysis, we recommend scheduling the next session soon to maintain momentum.',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          SizedBox(height: 12),

          // 🔥 زر Book Now تجريبي
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
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildInitialPlanContent(Map<String, dynamic> analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baseline Assessment
        if (analysis['baseline_assessment'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Baseline Assessment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildAssessmentSection(analysis['baseline_assessment']),
              SizedBox(height: 16),
            ],
          ),

        // Treatment Goals
        if (analysis['treatment_goals'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Treatment Goals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildTreatmentGoals(analysis['treatment_goals']),
              SizedBox(height: 16),
            ],
          ),

        // Recommended Schedule
        if (analysis['recommended_schedule'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommended Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildScheduleCard(analysis['recommended_schedule']),
              SizedBox(height: 16),
            ],
          ),

        // Focus Areas
        if (analysis['initial_focus_areas'] != null && (analysis['initial_focus_areas'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Initial Focus Areas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              ...(analysis['initial_focus_areas'] as List).map((area) => _buildFocusAreaCard(area)),
              SizedBox(height: 16),
            ],
          ),

        // Parent Instructions
        if (analysis['parent_instructions'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parent Instructions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildParentInstructions(analysis['parent_instructions']),
              SizedBox(height: 16),
            ],
          ),

        // Success Indicators
        if (analysis['success_indicators'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Success Indicators',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildSuccessIndicators(analysis['success_indicators']),
            ],
          ),
      ],
    );
  }

// 🔥 دالة محسنة ومبسطة لتحويل التاريخ
String _convertDateFormat(String? inputDate) {
  print('🔄 Converting date: $inputDate');
  
  if (inputDate == null || inputDate.isEmpty || inputDate == 'N/A') {
    return _getNextAvailableDate();
  }
  
  try {
    // الحالة 1: إذا كان التاريخ بالفعل بصيغة YYYY-MM-DD
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(inputDate)) {
      final date = DateTime.parse(inputDate);
      if (date.isAfter(DateTime.now())) {
        return inputDate;
      }
    }
    
    // الحالة 2: التواريخ النصية (November 19, 2025)
    if (inputDate.contains(RegExp(r'[a-zA-Z]'))) {
      return _parseTextDateToIso(inputDate);
    }
    
    // الحالة 3: أي تنسيق آخر - نحاول التحليل
    final date = DateTime.parse(inputDate);
    final formatted = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    // إذا كان التاريخ في الماضي، نستخدم تاريخ مستقبلي
    if (date.isBefore(DateTime.now())) {
      return _getNextAvailableDate();
    }
    
    return formatted;
    
  } catch (e) {
    print('❌ Error converting date "$inputDate": $e');
    return _getNextAvailableDate();
  }
}

// 🔥 دالة مساعدة لتحويل التواريخ النصية
String _parseTextDateToIso(String textDate) {
  try {
    final months = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
    };
    
    final lowerDate = textDate.toLowerCase();
    
    for (final month in months.keys) {
      if (lowerDate.contains(month)) {
        // استخراج اليوم والسنة باستخدام regex محسن
        final regex = RegExp(r'(\d{1,2})\s*,?\s*(\d{4})?');
        final match = regex.firstMatch(textDate);
        
        if (match != null) {
          final day = int.parse(match.group(1)!);
          final year = match.group(2) != null ? int.parse(match.group(2)!) : DateTime.now().year;
          final monthNumber = months[month]!;
          
          final date = DateTime(year, monthNumber, day);
          
          // التحقق من أن التاريخ ليس في الماضي
          if (date.isBefore(DateTime.now())) {
            return _getNextAvailableDate();
          }
          
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      }
    }
    
    // إذا فشل التحليل النصي
    return _getNextAvailableDate();
  } catch (e) {
    print('❌ Error in _parseTextDateToIso: $e');
    return _getNextAvailableDate();
  }
}

// 🔥 دالة مساعدة لتحليل التواريخ النصية مثل "November 19, 2025"
DateTime _parseTextDate(String dateText) {
  try {
    // قائمة بالأشهر الإنجليزية
    final months = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    
    final lowerDate = dateText.toLowerCase();
    
    // البحث عن الشهر في النص
    for (final month in months.keys) {
      if (lowerDate.contains(month)) {
        // استخراج اليوم والسنة
        final regex = RegExp(r'(\d{1,2}),?\s*(\d{4})?');
        final match = regex.firstMatch(dateText);
        
        if (match != null) {
          final day = int.parse(match.group(1)!);
          final year = match.group(2) != null ? int.parse(match.group(2)!) : DateTime.now().year;
          final monthNumber = months[month]!;
          
          return DateTime(year, monthNumber, day);
        }
      }
    }
    
    // إذا فشل التحليل، نستخدم التحليل العادي
    return DateTime.parse(dateText);
  } catch (e) {
    print('❌ Error in _parseTextDate: $e');
    rethrow;
  }
}



String _getNextAvailableDate() {
  final now = DateTime.now();
  
  // نبحث عن أول يوم إثنين قادم (أو أي يوم عمل)
  DateTime nextDate = now.add(Duration(days: 1));
  
  // نتأكد من أن التاريخ في المستقبل وليس عطلة نهاية الأسبوع
  int attempts = 0;
  while (attempts < 14) { // نبحث لمدة أسبوعين
    if (nextDate.weekday != DateTime.friday && 
        nextDate.weekday != DateTime.saturday &&
        nextDate.isAfter(now)) {
      final formatted = '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';
      print('📅 Generated next available date: $formatted');
      return formatted;
    }
    nextDate = nextDate.add(Duration(days: 1));
    attempts++;
  }
  
  // إذا لم نجد، نستخدم تاريخ بعد أسبوع
  final fallbackDate = now.add(Duration(days: 7));
  final formatted = '${fallbackDate.year}-${fallbackDate.month.toString().padLeft(2, '0')}-${fallbackDate.day.toString().padLeft(2, '0')}';
  print('📅 Using fallback date: $formatted');
  return formatted;
}


  Widget _buildNextSessionCard(Map<String, dynamic> nextSession) {
    _debugFullAnalysis();
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.green[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.green.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              'Suggested Date: ${nextSession['suggested_date'] ?? 'N/A'}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800]),
            ),
          ],
        ),
        SizedBox(height: 12),

        if (nextSession['focus_areas'] != null && (nextSession['focus_areas'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus Areas:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: (nextSession['focus_areas'] as List).map((area) => Chip(
                  label: Text(area.toString()),
                  backgroundColor: Colors.green[100],
                  labelStyle: TextStyle(fontSize: 12),
                )).toList(),
              ),
              SizedBox(height: 8),
            ],
          ),

        if (nextSession['preparation'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preparation:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                nextSession['preparation'].toString(),
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        
        // 🔥 إضافة زر Book Now
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _onBookNowPressed(nextSession),
            icon: Icon(Icons.event_available, size: 20),
            label: Text('Book Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  void _onBookNowPressed(Map<String, dynamic> nextSession) {
    print('🎯 Book Now Pressed - FULL ANALYSIS DATA:');

    // 🔥 الإصلاح: استخدام بيانات الـ AI من الـ professional_analysis بدلاً من action_plan
    final aiNextSession = _progressAnalysis?['professional_analysis']?['recommendations']?['next_session'];

    print('📊 AI Next Session from professional_analysis: $aiNextSession');
    print('📋 Raw nextSession data from action_plan: $nextSession');

    // 🔥 الأولوية: استخدام بيانات الـ AI إذا موجودة
    final Map<String, dynamic> sessionData;
    if (aiNextSession != null && aiNextSession['suggested_date'] != null) {
      print('✅ Using AI data from professional_analysis');
      sessionData = {
        'suggested_date': aiNextSession['suggested_date'],
        'focus_areas': aiNextSession['focus_areas'] ?? ['General skill development'],
        'preparation': aiNextSession['preparation'] ?? 'Review progress analysis'
      };
    } else {
      print('⚠️ Using fallback data from action_plan');
      sessionData = nextSession;
    }

    final suggestedDate = sessionData['suggested_date'];
    final focusAreas = sessionData['focus_areas'] as List<dynamic>?;

    print('🎯 FINAL - Using date: $suggestedDate');
    print('🎯 FINAL - Using focus areas: $focusAreas');

    // تحويل التاريخ للتنسيق الصحيح
    final convertedDate = _convertDateFormat(suggestedDate?.toString());
    final finalFocusAreas = focusAreas?.cast<String>() ?? ['General skill development'];

    print('✅ Converted Date: $convertedDate');
    print('✅ Focus Areas: $finalFocusAreas');
    print('✅ Child: ${widget.childName} (ID: ${widget.childId})');

    // الانتقال لصفحة Add Session
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
      print('=== 🔥 FULL AI ANALYSIS STRUCTURE ===');
      print('Professional Analysis: ${_progressAnalysis!['professional_analysis']}');
      print('Recommendations: ${_progressAnalysis!['professional_analysis']?['recommendations']}');
      print('Next Session in Recommendations: ${_progressAnalysis!['professional_analysis']?['recommendations']?['next_session']}');
      print('Action Plan: ${_progressAnalysis!['action_plan']}');
      print('====================================');
    }
  }


// 🔥 دالة جديدة لعرض الـ Initial Plan
  Widget _buildInitialPlan(Map<String, dynamic> analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baseline Assessment
        if (analysis['baseline_assessment'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Baseline Assessment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildAssessmentSection(analysis['baseline_assessment']),
              SizedBox(height: 16),
            ],
          ),

        // Treatment Goals
        if (analysis['treatment_goals'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Treatment Goals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildTreatmentGoals(analysis['treatment_goals']),
              SizedBox(height: 16),
            ],
          ),

        // Recommended Schedule
        if (analysis['recommended_schedule'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommended Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildScheduleCard(analysis['recommended_schedule']),
              SizedBox(height: 16),
            ],
          ),

        // Focus Areas
        if (analysis['initial_focus_areas'] != null && (analysis['initial_focus_areas'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Initial Focus Areas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              ...(analysis['initial_focus_areas'] as List).map((area) => _buildFocusAreaCard(area)),
              SizedBox(height: 16),
            ],
          ),

        // Next Evaluation
        if (analysis['next_evaluation'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next Evaluation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildNextEvaluationCard(analysis['next_evaluation']),
              SizedBox(height: 16),
            ],
          ),

        // Parent Instructions
        if (analysis['parent_instructions'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parent Instructions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildParentInstructions(analysis['parent_instructions']),
              SizedBox(height: 16),
            ],
          ),

        // Success Indicators
        if (analysis['success_indicators'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Success Indicators',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildSuccessIndicators(analysis['success_indicators']),
            ],
          ),
      ],
    );
  }

// 🔥 دالة العرض العادي (Comprehensive Analysis)
  Widget _buildComprehensiveAnalysis(Map<String, dynamic> analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Assessment
        if (analysis['overall_assessment'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Assessment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis['overall_assessment']?['summary'] ?? 'N/A',
                      style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(
                          label: Text(analysis['overall_assessment']?['trend'] ?? 'N/A'),
                          backgroundColor: Colors.green[100],
                        ),
                        SizedBox(width: 8),
                        Chip(
                          label: Text(analysis['overall_assessment']?['progress_level'] ?? 'N/A'),
                          backgroundColor: Colors.blue[100],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
          ),

        // Strengths
        if (analysis['strengths'] != null && (analysis['strengths'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Strengths',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              ...(analysis['strengths'] as List).map((strength) => _buildAnalysisItem(strength, Colors.green)),
              SizedBox(height: 16),
            ],
          ),

        // Challenges
        if (analysis['challenges'] != null && (analysis['challenges'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Challenges',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              ...(analysis['challenges'] as List).map((challenge) => _buildAnalysisItem(challenge, Colors.orange)),
              SizedBox(height: 16),
            ],
          ),

        // Recommendations
        if (analysis['recommendations'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommendations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              _buildRecommendationsSection(analysis['recommendations']),
            ],
          ),
      ],
    );
  }

// 🔥 دوال مساعدة للـ Initial Plan
  Widget _buildAssessmentSection(Map<String, dynamic> assessment) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListSection('Current Abilities', assessment['current_abilities']),
          SizedBox(height: 12),
          _buildListSection('Main Challenges', assessment['main_challenges']),
          SizedBox(height: 12),
          _buildListSection('Behavioral Observations', assessment['behavioral_observations']),
          SizedBox(height: 12),
          if (assessment['initial_score_interpretation'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score Interpretation:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  assessment['initial_score_interpretation'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        ...items.map((item) => Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.arrow_right, size: 16, color: Colors.grey[600]),
              SizedBox(width: 4),
              Expanded(child: Text(item.toString())),
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
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
              ),
              SizedBox(height: 8),
              ...(goals['short_term'] as List).map((goal) => _buildGoalCard(goal, Colors.green)),
              SizedBox(height: 12),
            ],
          ),

        if (goals['long_term'] != null && (goals['long_term'] as List).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Long Term Goals:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
              ),
              SizedBox(height: 8),
              ...(goals['long_term'] as List).map((goal) => _buildGoalCard(goal, Colors.blue)),
            ],
          ),
      ],
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal['goal'] ?? 'N/A',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(height: 4),
          Text('Timeline: ${goal['timeline'] ?? 'N/A'}'),
          if (goal['success_criteria'] != null)
            Text('Success: ${goal['success_criteria']}'),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScheduleItem('Frequency', schedule['frequency']),
          _buildScheduleItem('Duration', schedule['duration']),
          _buildScheduleItem('Best Timing', schedule['best_timing']),
          if (schedule['rationale'] != null) ...[
            SizedBox(height: 8),
            Text(
              'Rationale: ${schedule['rationale']}',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }

  Widget _buildFocusAreaCard(Map<String, dynamic> area) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getPriorityColor(area['priority']),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  area['priority']?.toString().toUpperCase() ?? 'N/A',
                  style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 8),
              Text(
                area['skill'] ?? 'N/A',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text('Approach: ${area['approach'] ?? 'N/A'}'),
          if (area['activities'] != null && (area['activities'] as List).isNotEmpty) ...[
            SizedBox(height: 4),
            Text('Activities: ${(area['activities'] as List).join(', ')}'),
          ],
          if (area['expected_progress'] != null) ...[
            SizedBox(height: 4),
            Text('Expected: ${area['expected_progress']}'),
          ],
        ],
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildNextEvaluationCard(Map<String, dynamic> nextEval) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested Date: ${nextEval['suggested_date'] ?? 'N/A'}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          _buildListSection('What to Assess', nextEval['what_to_assess']),
          SizedBox(height: 8),
          _buildListSection('Expected Improvements', nextEval['expected_improvements']),
        ],
      ),
    );
  }

  Widget _buildParentInstructions(Map<String, dynamic> instructions) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListSection('Daily Activities', instructions['daily_activities']),
          SizedBox(height: 12),
          _buildListSection('Environment Modifications', instructions['environment_modifications']),
          SizedBox(height: 12),
          _buildListSection('What to Monitor', instructions['what_to_monitor']),
          SizedBox(height: 12),
          _buildListSection('Communication Tips', instructions['communication_tips']),
        ],
      ),
    );
  }

  Widget _buildSuccessIndicators(Map<String, dynamic> indicators) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(12),
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
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeline,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[700]),
          ),
          SizedBox(height: 4),
          ...indicators.map((indicator) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text(indicator.toString())),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['area'] ?? 'N/A',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(height: 4),
          Text(
            item['description'] ?? 'N/A',
            style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
          ),
          if (item['progress'] != null) ...[
            SizedBox(height: 4),
            Text(
              'Progress: ${item['progress']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
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
            Colors.blue,
          ),

        if (recommendations['next_session'] != null)
          _buildRecommendationCard(
            'Next Session',
            recommendations['next_session'],
            Icons.event,
            Colors.green,
          ),

        if (recommendations['intensity_adjustment'] != null)
          _buildRecommendationCard(
            'Intensity Adjustment',
            recommendations['intensity_adjustment'],
            Icons.trending_up,
            Colors.orange,
          ),
      ],
    );
  }

  Widget _buildRecommendationCard(String title, Map<String, dynamic> data, IconData icon, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...data.entries.map((entry) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_capitalize(entry.key)}: ',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Expanded(
                  child: Text(
                    entry.value?.toString() ?? 'N/A',
                    style: TextStyle(fontSize: 14),
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: Colors.amber, size: 24),
                SizedBox(width: 12),
                Text(
                  'Action Plan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Next Session مع زر Book Now
            if (actionPlan['next_session'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Session',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8),
                  _buildNextSessionCard(actionPlan['next_session']),
                  SizedBox(height: 16),
                ],
              ),

            // Quick Recommendations
            if (actionPlan['quick_recommendations'] != null && (actionPlan['quick_recommendations'] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Recommendations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8),
                  ...(actionPlan['quick_recommendations'] as List).map((rec) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.arrow_right, size: 20, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rec.toString(),
                            style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),

                  // 🔥 زر إضافي في الـ Action Plan
                  SizedBox(height: 16),
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
                        backgroundColor: Colors.amber[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.purple, size: 24),
                SizedBox(width: 12),
                Text(
                  'Evaluation History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session ${eval['session_number']}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7815A0)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getScoreColor(_safeDouble(eval['score'])).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${eval['score']}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _getScoreColor(_safeDouble(eval['score']))),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            eval['date'] ?? 'N/A',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'Type: ${eval['type'] ?? 'N/A'}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          if (eval['score_change'] != null && eval['score_change'] != 0) ...[
            SizedBox(height: 4),
            Text(
              'Change: ${eval['score_change'] > 0 ? '+' : ''}${eval['score_change']}%',
              style: TextStyle(
                color: eval['score_change'] > 0 ? Colors.green : Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (eval['notes'] != null && eval['notes'].toString().isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Notes: ${eval['notes']}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis Information',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
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
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('$label:', style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          Expanded(flex: 3, child: Text(value ?? 'N/A', style: TextStyle(fontSize: 12, color: Colors.grey[800]))),
        ],
      ),
    );
  }

  // ========== EXISTING TABS ==========

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF7815A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFF7815A0)),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
        subtitle: Text(value.isNotEmpty ? value : 'Not available', style: TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildSessionCard(dynamic session) {
    final safeSession = _safeMap(session);
    final date = _safeString(safeSession['date']);
    final time = _safeString(safeSession['time']);
    final sessionType = _safeString(safeSession['session_type']);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF7815A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.event, color: Color(0xFF7815A0)),
        ),
        title: Text('Session ${_formatDate(date)}', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Time: ${time.isNotEmpty ? time : "Not specified"} - Type: ${sessionType.isNotEmpty ? sessionType : "Not specified"}'),
      ),
    );
  }

  Widget _buildInfoTab() {
    final child = _safeMap(childData?['child']);
    final parent = _safeMap(child['parent']);
    final diagnosis = _safeMap(child['diagnosis']);
    final institution = _safeMap(child['current_institution']);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
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
          Icon(Icons.event, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No sessions available',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    )
        : ListView.builder(
      padding: EdgeInsets.all(16),
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
      backgroundColor: Colors.grey[50],

      appBar: AppBar(
        title: Text(
          widget.childName.isNotEmpty ? widget.childName : 'Child Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF7815A0),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      // في الجزء العلوي من build method، بعد AppBar
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
        icon: Icon(Icons.compare_arrows),
        label: Text('Compare'),
        backgroundColor: Color(0xFF7815A0),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7815A0)),
            SizedBox(height: 16),
            Text(
              'Loading child details...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage,
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChildDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7815A0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      )
          : childData == null
          ? Center(child: Text('No data available', style: TextStyle(fontSize: 16, color: Colors.grey[600])))
          : DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF7815A0),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: TabBar(
                labelColor: Color(0xFF7815A0),
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                tabs: [
                  Tab(text: 'Information'),
                  Tab(text: 'Progress Analysis'),
                  Tab(text: 'Sessions'),
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