// lib/screens/parent/view_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/profile_stat_card.dart';
import 'EditProfileScreen.dart';
import 'manage_children_screen.dart';
import 'sessions_screen.dart';
import '../models/session.dart';

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  double _completionChange = 0.0;
  double _activeChange = 0.0;
  bool _hasHistoricalData = false;

  // نفس المتغيرات المستخدمة في sessions_screen
  List<Session> _allSessions = [];
  List<Session> _upcomingSessions = [];
  List<Session> _completedSessions = [];
  List<Session> _pendingSessions = [];
  List<Session> _cancelledSessions = [];
  List<dynamic> _recentEvaluations = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // نفس الدالة المستخدمة في sessions_screen
  Future<void> _loadAllData() async {
    try {
      setState(() {
        _isLoading = true;
        _isRefreshing = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('Token not found');
      }

      print('🔐 Loading profile and sessions data...');

      // تحميل البيانات بالتوازي مع إضافة التقارير
      await Future.wait([
        _loadDashboardData(token),
        _loadSessionsData(token),
        _loadRecentEvaluations(token), // ⬅️ إضافة جديدة
      ]);

      await _calculateAndDisplayImprovement();

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadRecentEvaluations(String token) async {
    try {
      print('📊 Loading recent evaluations...');

      final response = await ApiService.getChildEvaluationsForParent(token);

      print('🔍 API Response: $response');

      if (response != null && response['success'] == true) {
        final evaluations = response['data'] ?? [];
        print('✅ Successfully loaded ${evaluations.length} recent evaluations');

        setState(() {
          _recentEvaluations = List.from(evaluations);
        });

      } else {
        print('ℹ️ No real evaluations found, using demo data');
        // استخدام بيانات تجريبية إذا الـ API ما شغال
        _useDemoDataForEvaluations();
      }

    } catch (e) {
      print('❌ Error loading evaluations: $e');
      // في حالة الخطأ، استخدم بيانات تجريبية
      _useDemoDataForEvaluations();
    }
  }

  void _useDemoData() {
    print('🔄 Using demo data for recent activities');
    try {
      setState(() {
        _recentEvaluations = [
          {
            'evaluation_type': 'Initial',
            'progress_score': 75,
            'child_name': 'أحمد',
            'specialist_name': 'د. محمد علي',
            'created_at': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
          },
          {
            'evaluation_type': 'Mid',
            'progress_score': 65,
            'child_name': 'فاطمة',
            'specialist_name': 'د. سارة أحمد',
            'created_at': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
          },
          {
            'evaluation_type': 'Follow-up',
            'progress_score': 85,
            'child_name': 'يوسف',
            'specialist_name': 'د. خالد محمد',
            'created_at': DateTime.now().subtract(Duration(hours: 5)).toIso8601String(),
          },
        ];
      });
      print('✅ Demo data loaded successfully');
    } catch (e) {
      print('❌ Error setting demo data: $e');
      setState(() {
        _recentEvaluations = [];
      });
    }
  }
  Future<void> _saveMonthlyStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month}';

      final totalSessions = _userData['total_sessions'] ?? 0;
      final completedSessions = _userData['completed_sessions'] ?? 0;
      final activeSessions = _userData['active_sessions'] ?? 0;

      final completionRate = totalSessions > 0
          ? ((completedSessions / totalSessions) * 100).round()
          : 0;
      final activeRate = totalSessions > 0
          ? ((activeSessions / totalSessions) * 100).round()
          : 0;

      await prefs.setInt('$monthKey-completionRate', completionRate);
      await prefs.setInt('$monthKey-activeRate', activeRate);
      await prefs.setInt('$monthKey-totalSessions', totalSessions);

      print('💾 Saved monthly stats for $monthKey');
    } catch (e) {
      print('❌ Error saving monthly stats: $e');
    }
  }

  Future<Map<String, dynamic>> _calculateImprovement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month}';

      // الحصول على البيانات الحالية
      final totalSessions = _userData['total_sessions'] ?? 0;
      final completedSessions = _userData['completed_sessions'] ?? 0;
      final activeSessions = _userData['active_sessions'] ?? 0;

      final currentCompletion = totalSessions > 0
          ? ((completedSessions / totalSessions) * 100).round()
          : 0;
      final currentActive = totalSessions > 0
          ? ((activeSessions / totalSessions) * 100).round()
          : 0;

      // الحصول على بيانات الشهر الماضي
      final lastMonth = DateTime(now.year, now.month - 1);
      final lastMonthKey = '${lastMonth.year}-${lastMonth.month}';

      final lastCompletion = prefs.getInt('$lastMonthKey-completionRate') ?? 0;
      final lastActive = prefs.getInt('$lastMonthKey-activeRate') ?? 0;

      // حساب التغير
      final completionChange = currentCompletion - lastCompletion;
      final activeChange = currentActive - lastActive;

      return {
        'completionChange': completionChange.toDouble(),
        'activeChange': activeChange.toDouble(),
        'hasPreviousData': lastCompletion > 0,
      };
    } catch (e) {
      print('❌ Error calculating improvement: $e');
      return {
        'completionChange': 0.0,
        'activeChange': 0.0,
        'hasPreviousData': false,
      };
    }
  }

  Future<void> _calculateAndDisplayImprovement() async {
    try {
      final improvement = await _calculateImprovement();

      setState(() {
        _completionChange = improvement['completionChange'] ?? 0.0;
        _activeChange = improvement['activeChange'] ?? 0.0;
        _hasHistoricalData = improvement['hasPreviousData'] ?? false;
      });

      // حفظ البيانات الحالية للمستقبل
      await _saveMonthlyStats();

    } catch (e) {
      print('❌ Error in calculate and display: $e');
      setState(() {
        _completionChange = 0.0;
        _activeChange = 0.0;
        _hasHistoricalData = false;
      });
    }
  }

  // نفس دالة التصنيف من sessions_screen
  void _categorizeSessions(List<Session> sessions) {
    setState(() {
      _upcomingSessions = sessions.where((s) => s.displayStatus == 'upcoming').toList();
      _completedSessions = sessions.where((s) => s.displayStatus == 'completed').toList();
      _pendingSessions = sessions.where((s) => s.displayStatus == 'pending').toList();
      _cancelledSessions = sessions.where((s) => s.displayStatus == 'cancelled').toList();

      // تحديث الإحصائيات في _userData
      _userData['completed_sessions'] = _completedSessions.length;
      _userData['active_sessions'] = _upcomingSessions.length + _pendingSessions.length;
      _userData['total_sessions'] = sessions.length;
      _userData['upcoming_sessions'] = _upcomingSessions.length;
    });
  }

  Future<void> _loadDashboardData(String token) async {
    final response = await ApiService.getParentDashboard(token);

    if (response == null) {
      throw Exception('Failed to load profile data');
    }

    final parentData = response['parent'] ?? {};
    final childrenList = response['children'] as List? ?? [];
    final summaries = response['summaries'] ?? {};

    setState(() {
      _userData = {
        'name': parentData['name'] ?? '',
        'email': parentData['email'] ?? '',
        'phone': parentData['phone'] ?? '',
        'address': parentData['address'] ?? '',
        'occupation': parentData['occupation'] ?? 'Not specified',
        'profile_picture': parentData['profile_picture'] ?? '',
        'join_date': '2024',
        'total_children': summaries['totalChildren'] ?? childrenList.length,
        'children': childrenList,
        'pending_registrations': summaries['pendingRegistrations'] ?? 0,

        // تهيئة الإحصائيات - راح تتحدث بعد تحميل الجلسات
        'completed_sessions': 0,
        'active_sessions': 0,
        'total_sessions': 0,
        'upcoming_sessions': 0,
      };
    });
  }

  // نفس الدالة المستخدمة في sessions_screen
  Future<void> _loadSessionsData(String token) async {
    try {
      print('🔄 Loading sessions...');
      final allSessions = await ApiService.getSessions(token);
      print('✅ Loaded ${allSessions.length} sessions');

      _categorizeSessions(allSessions);

    } catch (e) {
      print('❌ Error loading sessions: $e');
      // إذا فشل تحميل الجلسات، استخدم القيم الافتراضية
      setState(() {
        _userData['completed_sessions'] = 0;
        _userData['active_sessions'] = 0;
        _userData['total_sessions'] = 0;
        _userData['upcoming_sessions'] = 0;
      });
    }
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ParentAppColors.primaryTeal,
            ParentAppColors.primaryTeal.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: _userData['profile_picture']?.isNotEmpty == true
                      ? NetworkImage(_userData['profile_picture']) as ImageProvider
                      : const AssetImage('assets/images/default_avatar.png'),
                  child: _userData['profile_picture']?.isEmpty == true
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified,
                    color: ParentAppColors.primaryTeal,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _userData['name'] ?? 'Parent',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _userData['email'] ?? '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                value: _userData['total_children'].toString(),
                label: 'Children',
              ),
              _buildStatItem(
                value: 'Member',
                label: 'Status',
              ),
              _buildStatItem(
                value: _userData['join_date'] ?? '2024',
                label: 'Since',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsGrid() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: [
          ProfileStatCard(
            title: 'Children',
            value: _userData['total_children'].toString(),
            icon: Icons.child_care,
            color: ParentAppColors.primaryTeal,
          ),
          ProfileStatCard(
            title: 'Active Sessions',
            value: _userData['active_sessions'].toString(),
            icon: Icons.calendar_today,
            color: Colors.orange,
          ),
          ProfileStatCard(
            title: 'Completed',
            value: _userData['completed_sessions'].toString(),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          ProfileStatCard(
            title: 'Upcoming',
            value: _userData['upcoming_sessions'].toString(),
            icon: Icons.schedule,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedStatistics() {
    final totalSessions = _userData['total_sessions'] ?? 0;
    final completedSessions = _userData['completed_sessions'] ?? 0;
    final activeSessions = _userData['active_sessions'] ?? 0;

    final completionRate = totalSessions > 0
        ? ((completedSessions / totalSessions) * 100).round()
        : 0;

    final activeRate = totalSessions > 0
        ? ((activeSessions / totalSessions) * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSectionTitle('Sessions Overview'),
          const SizedBox(height: 12),
          Container(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard(
                    title: 'Total Sessions',
                    value: totalSessions.toString(),
                    change: 0.0,
                    hasHistoricalData: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStatCard(
                    title: 'Completion Rate',
                    value: '$completionRate%',
                    change: _completionChange,
                    hasHistoricalData: _hasHistoricalData,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStatCard(
                    title: 'Active Rate',
                    value: '$activeRate%',
                    change: _activeChange,
                    hasHistoricalData: _hasHistoricalData,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required double change,
    required bool hasHistoricalData,
  }) {
    final isPositive = change > 0;
    final changeText = hasHistoricalData
        ? '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%'
        : 'No data';

    final icon = hasHistoricalData
        ? (isPositive ? Icons.arrow_upward : Icons.arrow_downward)
        : Icons.horizontal_rule;

    final color = _getChangeColor(change, hasHistoricalData);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 2),
                    Text(
                      changeText,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getChangeColor(double change, bool hasHistoricalData) {
    if (!hasHistoricalData) return Colors.grey;
    return change > 0 ? Colors.green : change < 0 ? Colors.red : Colors.orange;
  }

  Widget _buildUpcomingSessions() {
    final upcomingSessions = _upcomingSessions.take(2).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSectionTitle('Upcoming Sessions'),
          const SizedBox(height: 8),

          if (upcomingSessions.isEmpty)
            _buildEmptyState('No upcoming sessions'),

          if (upcomingSessions.isNotEmpty) ...[
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (int i = 0; i < upcomingSessions.length; i++)
                      _buildSessionItem(upcomingSessions[i]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SessionsScreen()),
                );
              },
              child: const Text('View All Sessions'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionItem(Session session) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.calendar_today, color: _getSessionColor(session.status)),
          title: Text(session.sessionType),
          subtitle: Text('${session.date} at ${session.time}'),
          trailing: Chip(
            label: Text(
              session.status,
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: _getStatusColor(session.status),
          ),
        ),
        if (session != _upcomingSessions.last) const Divider(),
      ],
    );
  }

  Color _getSessionColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'confirmed': return Colors.blue;
      case 'scheduled': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green.withOpacity(0.2);
      case 'confirmed': return Colors.blue.withOpacity(0.2);
      case 'scheduled': return Colors.orange.withOpacity(0.2);
      case 'cancelled': return Colors.red.withOpacity(0.2);
      case 'pending': return Colors.orange.withOpacity(0.2);
      default: return Colors.grey.withOpacity(0.2);
    }
  }

  Widget _buildEmptyState(String message) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.calendar_today, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap, // ⬅️ إضافة onTap
    );
  }

  Widget _buildRecentActivity() {
    final hasRealEvaluations = _recentEvaluations.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSectionTitle('Recent Activity'),
          const SizedBox(height: 8),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // النشاط الأول - Progress Report (يعمل كزر لفتح التقارير)
                  _buildActivityItem(
                    icon: Icons.assignment_turned_in,
                    title: 'Progress Report Generated',
                    subtitle: 'View recent evaluations',
                    color: Colors.green,
                    onTap: () {
                      // هذا الزر يفتح كل التقييمات
                      _showAllEvaluations(context);
                    },
                  ),
                  const Divider(),

                  // باقي النشاطات الأصلية
                  _buildActivityItem(
                    icon: Icons.calendar_today,
                    title: 'Session Rescheduled',
                    subtitle: 'Yesterday',
                    color: Colors.orange,
                  ),
                  const Divider(),
                  _buildActivityItem(
                    icon: Icons.photo_camera,
                    title: 'Photo Uploaded',
                    subtitle: '2 days ago',
                    color: Colors.blue,
                  ),
                  const Divider(),
                  _buildActivityItem(
                    icon: Icons.chat,
                    title: 'New Message from Specialist',
                    subtitle: '3 days ago',
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
          ),

          // زر "View All Reports" يظهر دائماً
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _showAllEvaluations(context);
            },
            child: const Text('View All Reports'),
          ),
        ],
      ),
    );
  }


  void _showEvaluationDetails(Map<String, dynamic> evaluation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${evaluation['evaluation_type']} Evaluation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Child: ${evaluation['child_name']}'),
            Text('Specialist: ${evaluation['specialist_name']}'),
            Text('Progress: ${evaluation['progress_score']}%'),
            if (evaluation['notes'] != null)
              Text('Notes: ${evaluation['notes']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationActivityItem(dynamic evaluation) {
    try {
      final Map<String, dynamic> eval = evaluation is Map ? Map<String, dynamic>.from(evaluation) : {};

      final childName = eval['child_name'] ?? 'Unknown Child';
      final evaluationType = eval['evaluation_type'] ?? 'Evaluation';
      final progressScore = eval['progress_score'] ?? 0;
      final createdAt = eval['created_at'] ?? '';
      final specialistName = eval['specialist_name'] ?? 'Specialist';

      final timeAgo = _getTimeAgo(createdAt);
      final iconData = _getEvaluationIcon(evaluationType);
      final color = _getEvaluationColor(evaluationType);

      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: color, size: 20),
        ),
        title: Text(
          'Progress Report Generated for $childName',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$evaluationType Evaluation - ${progressScore}% progress'),
            Text(
              timeAgo,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getProgressColor(progressScore.toDouble()).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${progressScore}%',
            style: TextStyle(
              color: _getProgressColor(progressScore.toDouble()),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () {
          _showEvaluationDetails(eval);
        },
      );
    } catch (e) {
      print('❌ Error building evaluation item: $e');
      return _buildActivityItem(
        icon: Icons.assignment_turned_in,
        title: 'Progress Report Generated',
        subtitle: 'Recent evaluation',
        color: Colors.green,
      );
    }
  }


  Widget _buildEmptyActivityState() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.assignment, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No recent activity',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllEvaluations(BuildContext context) {
    // إذا في تقييمات حقيقية، عرضها
    if (_recentEvaluations.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Text(
                'All Evaluation Reports (${_recentEvaluations.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _recentEvaluations.length,
                  itemBuilder: (context, index) {
                    final evaluation = _recentEvaluations[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          _getEvaluationIcon(evaluation['evaluation_type'] ?? ''),
                          color: _getEvaluationColor(evaluation['evaluation_type'] ?? ''),
                        ),
                        title: Text('${evaluation['child_name']} - ${evaluation['evaluation_type']}'),
                        subtitle: Text('Progress: ${evaluation['progress_score']}%'),
                        trailing: Text(_getTimeAgo(evaluation['created_at'] ?? '')),
                        onTap: () {
                          Navigator.pop(context);
                          _showEvaluationDetails(evaluation);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // إذا ما في تقييمات، استخدم البيانات التجريبية
      _useDemoDataForEvaluations();
      _showAllEvaluations(context); // إعادة فتح بعد تحميل البيانات
    }
  }


  void _useDemoDataForEvaluations() {
    print('🔄 Using demo data for evaluations');
    try {
      setState(() {
        _recentEvaluations = [
          {
            'evaluation_id': 1,
            'evaluation_type': 'Initial',
            'progress_score': 75,
            'child_name': 'أحمد',
            'specialist_name': 'د. محمد علي',
            'created_at': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
            'notes': 'تقدم جيد في المهارات الاجتماعية',
          },
          {
            'evaluation_id': 2,
            'evaluation_type': 'Mid',
            'progress_score': 65,
            'child_name': 'فاطمة',
            'specialist_name': 'د. سارة أحمد',
            'created_at': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
            'notes': 'تحسن ملحوظ في التواصل',
          },
          {
            'evaluation_id': 3,
            'evaluation_type': 'Follow-up',
            'progress_score': 85,
            'child_name': 'يوسف',
            'specialist_name': 'د. خالد محمد',
            'created_at': DateTime.now().subtract(Duration(hours: 5)).toIso8601String(),
            'notes': 'مستمر في التقدم بشكل إيجابي',
          },
        ];
      });
      print('✅ Demo evaluations loaded successfully');
    } catch (e) {
      print('❌ Error setting demo evaluations: $e');
      setState(() {
        _recentEvaluations = [];
      });
    }
  }


  String _getTimeAgo(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
      return '${(difference.inDays / 30).floor()}mo ago';
    } catch (e) {
      return 'Unknown time';
    }
  }

  IconData _getEvaluationIcon(String evaluationType) {
    switch (evaluationType.toLowerCase()) {
      case 'initial':
        return Icons.assignment;
      case 'mid':
        return Icons.assessment;
      case 'final':
        return Icons.assignment_turned_in;
      case 'follow-up':
        return Icons.update;
      default:
        return Icons.assignment;
    }
  }

  Color _getEvaluationColor(String evaluationType) {
    switch (evaluationType.toLowerCase()) {
      case 'initial':
        return Colors.blue;
      case 'mid':
        return Colors.orange;
      case 'final':
        return Colors.green;
      case 'follow-up':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getProgressColor(double score) {
    if (score < 40) return Colors.red;
    if (score < 70) return Colors.orange;
    return Colors.green;
  }

  Widget _buildChildrenOverview() {
    final children = _userData['children'] ?? [];

    return Column(
      children: [
        _buildSectionTitle('My Children'),
        if (children.isNotEmpty)
          ...children.take(3).map((child) => _buildChildItem(child)).toList(),
        if (children.length > 3)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageChildrenScreen()),
                );
              },
              child: Text('View All ${children.length} Children'),
            ),
          ),
      ],
    );
  }

  Widget _buildChildItem(Map<String, dynamic> child) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: child['image']?.isNotEmpty == true
              ? NetworkImage(child['image']) as ImageProvider
              : const AssetImage('assets/images/default_avatar.png'),
          child: child['image']?.isEmpty == true
              ? Text(child['name'][0])
              : null,
        ),
        title: Text(child['name'] ?? 'Unknown'),
        subtitle: Text(child['condition'] ?? 'No diagnosis'),
        trailing: Chip(
          label: Text(
            child['registration_status'] ?? 'Not Registered',
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: _getChildStatusColor(child['registration_status']),
        ),
      ),
    );
  }

  Color _getChildStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved': return Colors.green.withOpacity(0.2);
      case 'pending': return Colors.orange.withOpacity(0.2);
      case 'not registered': return Colors.grey.withOpacity(0.2);
      default: return Colors.grey.withOpacity(0.2);
    }
  }

  Widget _buildInfoCard({required String title, required String value, required IconData icon}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ParentAppColors.primaryTeal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: ParentAppColors.primaryTeal,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value.isNotEmpty ? value : 'Not specified',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: ParentAppColors.textDark,
        ),
      ),
    );
  }

  Future<void> _loadEvaluationsOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No token found')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading evaluations...')),
      );

      await _loadRecentEvaluations(token);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded ${_recentEvaluations.length} activities')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentAppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isRefreshing)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllData,
              tooltip: 'Refresh All',
            ),
          IconButton(
            icon: const Icon(Icons.assignment),
            onPressed: _loadEvaluationsOnly,
            tooltip: 'Load Reports',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              ).then((_) {
                _loadAllData();
              });
            },
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadAllData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildProfileHeader(),
              _buildStatisticsGrid(),
              _buildAdvancedStatistics(),
              const SizedBox(height: 24),
              _buildUpcomingSessions(),
              const SizedBox(height: 24),
              _buildRecentActivity(),
              const SizedBox(height: 24),
              _buildSectionTitle('Personal Information'),
              _buildInfoCard(
                title: 'Full Name',
                value: _userData['name'] ?? '',
                icon: Icons.person,
              ),
              _buildInfoCard(
                title: 'Email Address',
                value: _userData['email'] ?? '',
                icon: Icons.email,
              ),
              _buildInfoCard(
                title: 'Phone Number',
                value: _userData['phone'] ?? '',
                icon: Icons.phone,
              ),
              _buildInfoCard(
                title: 'Address',
                value: _userData['address'] ?? '',
                icon: Icons.location_on,
              ),
              _buildInfoCard(
                title: 'Occupation',
                value: _userData['occupation'] ?? '',
                icon: Icons.work,
              ),
              _buildSectionTitle('Account Information'),
              _buildInfoCard(
                title: 'Member Since',
                value: _userData['join_date'] ?? '2024',
                icon: Icons.calendar_today,
              ),
              _buildInfoCard(
                title: 'Account Type',
                value: 'Parent',
                icon: Icons.family_restroom,
              ),
              _buildInfoCard(
                title: 'Status',
                value: 'Active',
                icon: Icons.verified_user,
              ),
              _buildChildrenOverview(),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.share),
                        label: const Text('Share Profile'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: ParentAppColors.primaryTeal),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download),
                        label: const Text('Export Data'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}