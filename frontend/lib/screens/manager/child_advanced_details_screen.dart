// child_advanced_details_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/manager/child_team_room_screen.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_service.dart';

class ChildAdvancedDetailsScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ChildAdvancedDetailsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildAdvancedDetailsScreen> createState() => _ChildAdvancedDetailsScreenState();
}

class _ChildAdvancedDetailsScreenState extends State<ChildAdvancedDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _advancedStats;
  Map<String, dynamic>? _multidisciplinaryInsights;
  bool _isLoadingAdvancedStats = true;
  bool _isLoadingInsights = true;

  @override
void initState() {
  super.initState();
  _tabController = TabController(length: 4, vsync: this); // ⬅️ غيرنا من 3 إلى 4
  _loadAdvancedData();
}

  Future<void> _loadAdvancedData() async {
    await Future.wait([
      _loadAdvancedStatistics(),
      _loadMultidisciplinaryInsights(),
    ]);
  }

  Future<void> _loadAdvancedStatistics() async {
    try {
      final response = await ManagerService.getAdvancedChildStatistics(widget.childId);
      if (response['success'] == true) {
        setState(() {
          _advancedStats = response['data'];
        });
      } else {
        print('Error loading advanced stats: ${response['message']}');
      }
    } catch (e) {
      print('Error loading advanced statistics: $e');
    } finally {
      setState(() {
        _isLoadingAdvancedStats = false;
      });
    }
  }

  Future<void> _loadMultidisciplinaryInsights() async {
    try {
      final response = await ManagerService.getChildMultidisciplinaryInsights(widget.childId);
      if (response['success'] == true) {
        setState(() {
          _multidisciplinaryInsights = response['data'];
        });
      } else {
        print('Error loading insights: ${response['message']}');
      }
    } catch (e) {
      print('Error loading multidisciplinary insights: $e');
    } finally {
      setState(() {
        _isLoadingInsights = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.childName),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'التقدم'),
            Tab(text: 'الفريق'),
            Tab(text: 'التحليل'),
            Tab(text: 'غرفة الفريق'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProgressTab(),
          _buildTeamTab(),
          _buildAnalysisTab(),
          _buildTeamRoomTab(),
        ],
      ),
    );
  }

  Widget _buildTeamRoomTab() {
  return ChildTeamRoomScreen(
    childId: widget.childId,
    childName: widget.childName,
  );
}

  Widget _buildProgressTab() {
    if (_isLoadingAdvancedStats) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_advancedStats == null) {
      return Center(child: Text('لا توجد بيانات متاحة'));
    }

    final stats = _advancedStats!['statistics'];
    if (stats == null) {
      return Center(child: Text('بيانات الإحصائيات غير متاحة'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stats['session_analytics'] != null) ...[
            _buildSectionTitle('📊 إحصائيات الجلسات'),
            _buildSessionAnalytics(stats['session_analytics']),
            SizedBox(height: 20),
          ],
          
          if (stats['progress_analytics'] != null) ...[
            _buildSectionTitle('📈 تحليل التقدم'),
            _buildProgressAnalytics(stats['progress_analytics']),
            SizedBox(height: 20),
          ],
          
          if (stats['kpis'] != null) ...[
            _buildSectionTitle('🎯 مؤشرات الأداء الرئيسية'),
            _buildKPIs(stats['kpis']),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamTab() {
    if (_isLoadingInsights) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_multidisciplinaryInsights == null) {
      return Center(child: Text('لا توجد بيانات متاحة'));
    }

    final team = _multidisciplinaryInsights!['multidisciplinary_team'];
    final analysis = _multidisciplinaryInsights!['team_analysis'];
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (team != null && team is List) ...[
            _buildSectionTitle('👥 أعضاء الفريق العلاجي'),
            ...team.map((specialist) => _buildSpecialistCard(specialist)).toList(),
            SizedBox(height: 20),
          ],
          
          if (analysis != null) ...[
            _buildSectionTitle('🔍 تحليل الفريق'),
            _buildTeamAnalysis(analysis),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    if (_isLoadingInsights) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_multidisciplinaryInsights == null) {
      return Center(child: Text('لا توجد بيانات متاحة'));
    }

    final decisions = _multidisciplinaryInsights!['decisions_recommendations'];
    final actionPlan = _multidisciplinaryInsights!['comprehensive_action_plan'];
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (decisions != null) ...[
            _buildSectionTitle('💡 القرارات والتوصيات'),
            _buildDecisions(decisions),
            SizedBox(height: 20),
          ],
          
          if (actionPlan != null) ...[
            _buildSectionTitle('📋 خطة العمل الشاملة'),
            _buildActionPlan(actionPlan),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSessionAnalytics(Map<String, dynamic> analytics) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatItem('إجمالي الجلسات', _safeToString(analytics['total_sessions'])),
            _buildStatItem('المدة الإجمالية', '${_safeToString(analytics['total_duration'])} دقيقة'),
            _buildStatItem('معدل الالتزام', '${_safeToDouble(analytics['commitment_rate'])?.toStringAsFixed(1)}%'),
            
            SizedBox(height: 12),
            Text('حالة الجلسات:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._safeList(analytics['by_status']).map((status) => 
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(_safeToString(status['status']))),
                    Text('${_safeToString(status['count'])} جلسة'),
                  ],
                ),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressAnalytics(Map<String, dynamic> analytics) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatItem('متوسط التقدم الحالي', '${_safeToDouble(analytics['current_avg_progress'])?.toStringAsFixed(1) ?? '0'}%'),
            _buildStatItem('اتساق التقدم', '${_safeToDouble(analytics['progress_consistency'])?.toStringAsFixed(1) ?? '0'}%'),
            
            if (analytics['strength_weakness'] != null) ...[
              SizedBox(height: 12),
              Text('نقاط القوة والضعف:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._safeList(analytics['strength_weakness']).map((sw) => 
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: (_safeToDouble(sw['avg_score']) ?? 0) > 50 ? AppColors.success : AppColors.error,
                    child: Text(
                      '${(_safeToDouble(sw['avg_score']) ?? 0).toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 10, color: AppColors.textWhite),
                    ),
                  ),
                  title: Text(_safeToString(sw['evaluation_type'])),
                  subtitle: Text('${_safeToString(sw['assessment_count'])} تقييم'),
                )
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKPIs(Map<String, dynamic> kpis) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildKPIItem('معدل الحضور', kpis['attendance_rate'], 70),
            _buildKPIItem('سرعة التقدم', kpis['progress_velocity'], 0),
            _buildKPIItem('الالتزام بالعلاج', kpis['treatment_adherence'], 80),
            _buildKPIItem('فعالية الأخصائيين', kpis['specialist_effectiveness'], 60),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIItem(String label, dynamic value, double target) {
    double numValue;
    if (value is num) {
      numValue = value.toDouble();
    } else if (value is String) {
      numValue = double.tryParse(value) ?? 0.0;
    } else {
      numValue = 0.0;
    }
    
    final percentage = numValue.toStringAsFixed(1);
    final isGood = numValue >= target;
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isGood ? AppColors.success.withOpacity(0.2) : AppColors.error.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isGood ? AppColors.success : AppColors.error,
            ),
          ),
        ),
      ),
      title: Text(label),
      subtitle: Text('الهدف: $target%'),
      trailing: Icon(
        isGood ? Icons.check_circle : Icons.warning,
        color: isGood ? AppColors.success : AppColors.error,
      ),
    );
  }

  Widget _buildSpecialistCard(Map<String, dynamic> specialist) {
    final personalInfo = specialist['personal_info'] ?? {};
    final performance = specialist['performance'] ?? {};
    final engagement = specialist['engagement'] ?? {};
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: _safeToString(personalInfo['profile_picture']).isNotEmpty 
                      ? NetworkImage(_safeToString(personalInfo['profile_picture'])) 
                      : null,
                  child: _safeToString(personalInfo['profile_picture']).isEmpty 
                      ? Icon(Icons.person, color: AppColors.textWhite)
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _safeToString(personalInfo['name']),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(_safeToString(personalInfo['specialization'])),
                      Text('${_safeToString(personalInfo['experience'])} سنوات خبرة'),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPerformanceColor(_safeToDouble(performance['effectiveness_score']) ?? 0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(_safeToDouble(performance['effectiveness_score']) ?? 0).toStringAsFixed(0)}%',
                    style: TextStyle(color: AppColors.textWhite, fontSize: 12),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('الجلسات', _safeToString(engagement['total_sessions'])),
                _buildMiniStat('مكتملة', _safeToString(engagement['completed_sessions'])),
                _buildMiniStat('الحضور', '${_safeToDouble(engagement['attendance_rate'])?.toStringAsFixed(0) ?? '0'}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamAnalysis(Map<String, dynamic> analysis) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatItem('قوة الفريق', '${_safeToDouble(analysis['overall_effectiveness']?['team_strength'])?.toStringAsFixed(1) ?? '0'}%'),
            _buildStatItem('جودة التنسيق', '${_safeToDouble(analysis['collaboration_patterns']?['coordination_score'])?.toStringAsFixed(1) ?? '0'}%'),
            _buildStatItem('التغطية بالتخصصات', '${_safeToDouble(analysis['gaps_and_overlaps']?['coverage_score'])?.toStringAsFixed(1) ?? '0'}%'),
            
            if (analysis['gaps_and_overlaps']?['missing_specializations'] != null) ...[
              SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التخصصات المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._safeList(analysis['gaps_and_overlaps']['missing_specializations']).map((spec) => 
                    Text('• ${_safeToString(spec)}')
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDecisions(Map<String, dynamic> decisions) {
    final priorityActions = decisions['priority_actions'];
    if (priorityActions == null || priorityActions is! List) {
      return Text('لا توجد قرارات متاحة');
    }

    return Column(
      children: priorityActions.map((action) => 
        Card(
          margin: EdgeInsets.only(bottom: 8),
          color: _getPriorityColor(_safeToString(action['priority'])),
          child: ListTile(
            leading: Icon(_getPriorityIcon(_safeToString(action['priority'])), color: AppColors.textWhite),
            title: Text(_safeToString(action['title']), style: TextStyle(color: AppColors.textWhite)),
            subtitle: Text(_safeToString(action['description']), style: TextStyle(color: AppColors.textWhite.withOpacity(0.8))),
          ),
        )
      ).toList(),
    );
  }

  Widget _buildActionPlan(Map<String, dynamic> actionPlan) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (actionPlan['overview']?['primary_goals'] != null) ...[
              Text('الأهداف الرئيسية:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._safeList(actionPlan['overview']['primary_goals']).map((goal) => 
                Text('• ${_safeToString(goal)}')
              ),
              SizedBox(height: 16),
            ],
            
            if (actionPlan['phases'] != null) ...[
              Text('مراحل التنفيذ:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._safeList(actionPlan['phases']).map((phase) => 
                ExpansionTile(
                  title: Text(_safeToString(phase['phase'])),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الأهداف: ${_safeList(phase['objectives']).join(', ')}'),
                          SizedBox(height: 8),
                          Text('الإجراءات:'),
                          ..._safeList(phase['actions']).map((action) => 
                            Text('• ${_safeToString(action['action'])}')
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textGray)),
      ],
    );
  }

  // دوال مساعدة للتعامل مع البيانات بشكل آمن
  String _safeToString(dynamic value) {
    if (value == null) return 'غير محدد';
    if (value is String) return value;
    return value.toString();
  }

  double? _safeToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  List<dynamic> _safeList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    return [];
  }

  Color _getPerformanceColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'HIGH': return AppColors.error;
      case 'MEDIUM': return AppColors.warning;
      case 'LOW': return AppColors.info;
      default: return AppColors.primary;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'HIGH': return Icons.error;
      case 'MEDIUM': return Icons.warning;
      case 'LOW': return Icons.info;
      default: return Icons.flag;
    }
  }
}