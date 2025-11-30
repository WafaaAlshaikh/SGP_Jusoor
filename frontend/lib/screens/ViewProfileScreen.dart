// lib/screens/parent/view_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
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

      await Future.wait([
        _loadDashboardData(token),
        _loadSessionsData(token),
        _loadRecentEvaluations(token),
      ]);

      await _calculateAndDisplayImprovement();

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadRecentEvaluations(String token) async {
    try {
      final response = await ApiService.getChildEvaluationsForParent(token);

      if (response != null && response['success'] == true) {
        final evaluations = response['data'] ?? [];
        setState(() {
          _recentEvaluations = List.from(evaluations);
        });
      } else {
        _useDemoDataForEvaluations();
      }
    } catch (e) {
      _useDemoDataForEvaluations();
    }
  }

  void _useDemoDataForEvaluations() {
    setState(() {
      _recentEvaluations = [
        {
          'evaluation_type': 'Initial',
          'progress_score': 75,
          'child_name': 'أحمد',
          'specialist_name': 'د. محمد علي',
          'created_at': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
          'notes': 'تقدم جيد في المهارات الاجتماعية',
        },
        {
          'evaluation_type': 'Mid',
          'progress_score': 65,
          'child_name': 'فاطمة',
          'specialist_name': 'د. سارة أحمد',
          'created_at': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
          'notes': 'تحسن ملحوظ في التواصل',
        },
      ];
    });
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
    } catch (e) {
      print('❌ Error saving monthly stats: $e');
    }
  }

  Future<Map<String, dynamic>> _calculateImprovement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month}';

      final totalSessions = _userData['total_sessions'] ?? 0;
      final completedSessions = _userData['completed_sessions'] ?? 0;
      final activeSessions = _userData['active_sessions'] ?? 0;

      final currentCompletion = totalSessions > 0
          ? ((completedSessions / totalSessions) * 100).round()
          : 0;
      final currentActive = totalSessions > 0
          ? ((activeSessions / totalSessions) * 100).round()
          : 0;

      final lastMonth = DateTime(now.year, now.month - 1);
      final lastMonthKey = '${lastMonth.year}-${lastMonth.month}';

      final lastCompletion = prefs.getInt('$lastMonthKey-completionRate') ?? 0;
      final lastActive = prefs.getInt('$lastMonthKey-activeRate') ?? 0;

      final completionChange = currentCompletion - lastCompletion;
      final activeChange = currentActive - lastActive;

      return {
        'completionChange': completionChange.toDouble(),
        'activeChange': activeChange.toDouble(),
        'hasPreviousData': lastCompletion > 0,
      };
    } catch (e) {
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

      await _saveMonthlyStats();
    } catch (e) {
      setState(() {
        _completionChange = 0.0;
        _activeChange = 0.0;
        _hasHistoricalData = false;
      });
    }
  }

  void _categorizeSessions(List<Session> sessions) {
    setState(() {
      _upcomingSessions = sessions.where((s) => s.displayStatus == 'upcoming').toList();
      _completedSessions = sessions.where((s) => s.displayStatus == 'completed').toList();
      _pendingSessions = sessions.where((s) => s.displayStatus == 'pending').toList();
      _cancelledSessions = sessions.where((s) => s.displayStatus == 'cancelled').toList();

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
        'completed_sessions': 0,
        'active_sessions': 0,
        'total_sessions': 0,
        'upcoming_sessions': 0,
      };
    });
  }

  Future<void> _loadSessionsData(String token) async {
    try {
      final allSessions = await ApiService.getSessions(token);
      _categorizeSessions(allSessions);
    } catch (e) {
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
            AppColors.primary,
            AppColors.primaryLight,
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
                      blurRadius: 15,
                      offset: const Offset(0, 6),
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
                      ? Icon(Icons.person_rounded, size: 50, color: Colors.white)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: AppColors.primary,
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  value: _userData['total_children'].toString(),
                  label: 'Children',
                ),
                Container(height: 30, width: 1, color: Colors.white.withOpacity(0.3)),
                _buildStatItem(
                  value: 'Premium',
                  label: 'Status',
                ),
                Container(height: 30, width: 1, color: Colors.white.withOpacity(0.3)),
                _buildStatItem(
                  value: _userData['join_date'] ?? '2024',
                  label: 'Since',
                ),
              ],
            ),
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
            fontSize: 16,
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          _buildEnhancedStatCard(
            title: 'Children',
            value: _userData['total_children'].toString(),
            icon: Icons.child_care_rounded,
            color: AppColors.primary,
          ),
          _buildEnhancedStatCard(
            title: 'Active Sessions',
            value: _userData['active_sessions'].toString(),
            icon: Icons.calendar_today_rounded,
            color: Colors.orange,
          ),
          _buildEnhancedStatCard(
            title: 'Completed',
            value: _userData['completed_sessions'].toString(),
            icon: Icons.check_circle_rounded,
            color: Colors.green,
          ),
          _buildEnhancedStatCard(
            title: 'Upcoming',
            value: _userData['upcoming_sessions'].toString(),
            icon: Icons.schedule_rounded,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
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
          _buildSectionTitle('Performance Overview'),
          const SizedBox(height: 12),
          Container(
            height: 120,
            child: Row(
              children: [
                Expanded(
                  child: _buildPerformanceCard(
                    title: 'Total Sessions',
                    value: totalSessions.toString(),
                    subtitle: 'All time',
                    icon: Icons.assignment_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPerformanceCard(
                    title: 'Completion Rate',
                    value: '$completionRate%',
                    subtitle: _hasHistoricalData
                        ? '${_completionChange > 0 ? '+' : ''}${_completionChange.toStringAsFixed(1)}%'
                        : 'New',
                    icon: Icons.trending_up_rounded,
                    color: _completionChange > 0 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSessions() {
    final upcomingSessions = _upcomingSessions.take(2).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSectionTitle('Upcoming Sessions'),
          const SizedBox(height: 12),

          if (upcomingSessions.isEmpty)
            _buildEmptyState(
              icon: Icons.calendar_today_rounded,
              message: 'No upcoming sessions',
              subtitle: 'Book your first session to get started',
            ),

          if (upcomingSessions.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SessionsScreen()),
                  );
                },
                icon: Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text('View All Sessions (${_upcomingSessions.length})'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
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
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getSessionColor(session.status).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: _getSessionColor(session.status),
              size: 20,
            ),
          ),
          title: Text(
            session.sessionType,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          subtitle: Text(
            '${session.date} • ${session.time}',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 13,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(session.status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              session.status,
              style: TextStyle(
                fontSize: 11,
                color: _getSessionColor(session.status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (session != _upcomingSessions.last)
          Divider(height: 1, color: AppColors.accent2),
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
      case 'completed': return Colors.green.withOpacity(0.1);
      case 'confirmed': return Colors.blue.withOpacity(0.1);
      case 'scheduled': return Colors.orange.withOpacity(0.1);
      case 'cancelled': return Colors.red.withOpacity(0.1);
      case 'pending': return Colors.orange.withOpacity(0.1);
      default: return Colors.grey.withOpacity(0.1);
    }
  }

  Widget _buildEmptyState({required IconData icon, required String message, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSectionTitle('Recent Activity'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildActivityItem(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Progress Report Generated',
                    subtitle: 'View recent evaluations',
                    color: Colors.green,
                    onTap: () {
                      _showAllEvaluations(context);
                    },
                  ),
                  Divider(height: 20, color: AppColors.accent2),
                  _buildActivityItem(
                    icon: Icons.calendar_today_rounded,
                    title: 'Session Rescheduled',
                    subtitle: 'Yesterday',
                    color: Colors.orange,
                  ),
                  Divider(height: 20, color: AppColors.accent2),
                  _buildActivityItem(
                    icon: Icons.photo_camera_rounded,
                    title: 'Photo Uploaded',
                    subtitle: '2 days ago',
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                _showAllEvaluations(context);
              },
              icon: Icon(Icons.assignment_rounded, size: 18),
              label: Text('View All Reports'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  void _showEvaluationDetails(Map<String, dynamic> evaluation) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getEvaluationColor(evaluation['evaluation_type'] ?? '').withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getEvaluationIcon(evaluation['evaluation_type'] ?? ''),
                      color: _getEvaluationColor(evaluation['evaluation_type'] ?? ''),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${evaluation['evaluation_type']} Evaluation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildEvaluationDetailRow('Child', evaluation['child_name'] ?? ''),
              _buildEvaluationDetailRow('Specialist', evaluation['specialist_name'] ?? ''),
              _buildEvaluationDetailRow('Progress Score', '${evaluation['progress_score']}%'),
              if (evaluation['notes'] != null)
                _buildEvaluationDetailRow('Notes', evaluation['notes'] ?? ''),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvaluationDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
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

  void _showAllEvaluations(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.accent2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Evaluation Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _recentEvaluations.isEmpty
                  ? _buildEmptyState(
                icon: Icons.assignment_rounded,
                message: 'No evaluations yet',
                subtitle: 'Evaluations will appear here once available',
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _recentEvaluations.length,
                itemBuilder: (context, index) {
                  final evaluation = _recentEvaluations[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _getEvaluationColor(evaluation['evaluation_type'] ?? '').withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getEvaluationIcon(evaluation['evaluation_type'] ?? ''),
                          color: _getEvaluationColor(evaluation['evaluation_type'] ?? ''),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '${evaluation['child_name']} - ${evaluation['evaluation_type']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: Text(
                        'Progress: ${evaluation['progress_score']}%',
                        style: TextStyle(
                          color: AppColors.textGray,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getProgressColor((evaluation['progress_score'] ?? 0).toDouble()).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${evaluation['progress_score']}%',
                          style: TextStyle(
                            color: _getProgressColor((evaluation['progress_score'] ?? 0).toDouble()),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
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
  }

  IconData _getEvaluationIcon(String evaluationType) {
    switch (evaluationType.toLowerCase()) {
      case 'initial': return Icons.assignment_rounded;
      case 'mid': return Icons.assessment_rounded;
      case 'final': return Icons.assignment_turned_in_rounded;
      case 'follow-up': return Icons.update_rounded;
      default: return Icons.assignment_rounded;
    }
  }

  Color _getEvaluationColor(String evaluationType) {
    switch (evaluationType.toLowerCase()) {
      case 'initial': return Colors.blue;
      case 'mid': return Colors.orange;
      case 'final': return Colors.green;
      case 'follow-up': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _getProgressColor(double score) {
    if (score < 40) return Colors.red;
    if (score < 70) return Colors.orange;
    return Colors.green;
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isRefreshing)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
              onPressed: _loadAllData,
              tooltip: 'Refresh',
            ),
          IconButton(
            icon: Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              ).then((_) => _loadAllData());
            },
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
        onRefresh: _loadAllData,
        color: AppColors.primary,
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Profile...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGray,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 48,
              child: ElevatedButton(
                onPressed: _loadAllData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}