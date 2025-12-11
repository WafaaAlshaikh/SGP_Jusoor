import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_specialist_service.dart';
import '../../services/manager_vacation_service.dart';
import './specialist_schedule_screen.dart';

class SpecialistReportScreen extends StatefulWidget {
  final int specialistId;
  final String specialistName;

  const SpecialistReportScreen({
    required this.specialistId,
    required this.specialistName,
  });

  @override
  _SpecialistReportScreenState createState() => _SpecialistReportScreenState();
}

class _SpecialistReportScreenState extends State<SpecialistReportScreen> {
  Map<String, dynamic> _report = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ManagerSpecialistService.getSpecialistComprehensiveReport(widget.specialistId);

      if (response['success'] == true) {
        setState(() {
          _report = response['data'] ?? {};
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load report';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading report: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // دالة لاستخراج الصورة من البيانات
  String? _getSpecialistProfilePicture() {
    try {
      // محاولة استخراج الصورة من عدة أماكن محتملة
      final profilePicture = _report['specialist_info']?['personal_info']?['profile_picture'] ??
          _report['profile_picture'] ??
          _report['specialist_info']?['profile_picture'];

      // التحقق إذا كان الرابط يحتوي على http أو مجرد اسم ملف
      if (profilePicture != null && profilePicture.toString().isNotEmpty) {
        String pictureUrl = profilePicture.toString();

        // إذا كان الرابط يحتوي على http أو https، استخدمه كما هو
        if (pictureUrl.startsWith('http')) {
          return pictureUrl;
        }

        // إذا كان يبدأ بـ uploads/، أضف الـ base URL
        if (pictureUrl.startsWith('uploads/')) {
          return 'http://10.0.2.2:5000/$pictureUrl';
        }

        // إذا كان مجرد اسم ملف، أضفه إلى المسار
        return 'http://10.0.2.2:5000/uploads/profiles/$pictureUrl';
      }

      return null;
    } catch (e) {
      print('Error extracting profile picture: $e');
      return null;
    }
  }

  // دالة لاستخراج الأحرف الأولى من الاسم لعمل Avatar
  String _getInitials() {
    try {
      final name = widget.specialistName.trim();
      if (name.isEmpty) return '??';

      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts[0].length >= 2) {
        return parts[0].substring(0, 2).toUpperCase();
      } else if (parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
      return '??';
    } catch (e) {
      return '??';
    }
  }

  Widget _buildProfileAvatar() {
    final profilePicture = _getSpecialistProfilePicture();

    if (profilePicture != null) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            profilePicture,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildFallbackAvatar();
            },
            errorBuilder: (context, error, stackTrace) {
              print('Error loading profile image: $error');
              return _buildFallbackAvatar();
            },
          ),
        ),
      );
    }

    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.7),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 110,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent2.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(icon, size: 18, color: color),
                ),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
    bool wrapWithContainer = true,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          wrapWithContainer
              ? Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent2.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // إحصائيات الجلسات التفصيلية
  Widget _buildSessionsDetailedStats() {
    final sessionsSummary = _report['statistics']?['sessions_summary'] ?? {};
    final sessionsByStatus = sessionsSummary['sessions_by_status'] ?? {};

    List<MapEntry<String, dynamic>> sessionsList = sessionsByStatus.entries.toList();

    return _buildSection(
      title: 'Session Status Breakdown',
      icon: Icons.bar_chart_rounded,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                'Total',
                '${sessionsSummary['total_sessions'] ?? 0}',
                Icons.calendar_today_rounded,
                AppColors.primary,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Completed',
                '${sessionsSummary['completed_sessions'] ?? 0}',
                Icons.check_circle_rounded,
                AppColors.success,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Upcoming',
                '${sessionsSummary['upcoming_sessions'] ?? 0}',
                Icons.upcoming_rounded,
                AppColors.blue,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Cancelled',
                '${sessionsSummary['cancelled_sessions'] ?? 0}',
                Icons.cancel_rounded,
                AppColors.error,
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        ...sessionsList.map((entry) {
          return _buildInfoRow(
            entry.key,
            '${entry.value} sessions',
          );
        }).toList(),
      ],
    );
  }

  // إحصائيات العطلات
  Widget _buildVacationStats() {
    final vacationsSummary = _report['statistics']?['vacations_summary'] ?? {};
    final vacationStats = vacationsSummary['vacation_stats'] ?? {};

    return _buildSection(
      title: 'Vacation Statistics',
      icon: Icons.beach_access_rounded,
      iconColor: AppColors.blue,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                'Total',
                '${vacationsSummary['total_requests'] ?? 0}',
                Icons.list_alt_rounded,
                AppColors.blue,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Approved',
                '${vacationStats['approved'] ?? 0}',
                Icons.check_circle_rounded,
                AppColors.success,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Pending',
                '${vacationStats['pending'] ?? 0}',
                Icons.pending_rounded,
                AppColors.warning,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Rejected',
                '${vacationStats['rejected'] ?? 0}',
                Icons.cancel_rounded,
                AppColors.error,
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                'Approved Days',
                '${vacationsSummary['approved_vacation_days'] ?? 0}',
                Icons.calendar_month_rounded,
                AppColors.success,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Upcoming',
                '${vacationsSummary['upcoming_vacations_count'] ?? 0}',
                Icons.upcoming_rounded,
                AppColors.primary,
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        if (_report['upcoming_vacations']?.isNotEmpty == true)
          ElevatedButton.icon(
            onPressed: () => _viewVacations(),
            icon: Icon(Icons.remove_red_eye_rounded, size: 20),
            label: Text('View Upcoming Vacations'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  void _viewVacations() {
    final upcomingVacations = _report['upcoming_vacations'] ?? [];
    final recentVacations = _report['recent_vacations'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DefaultTabController(
        length: 2,
        child: Container(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 20),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vacations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textGray),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textGray,
                  indicator: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tabs: [
                    Tab(text: 'Upcoming (${upcomingVacations.length})'),
                    Tab(text: 'Recent (${recentVacations.length})'),
                  ],
                ),
              ),

              SizedBox(height: 16),

              Expanded(
                child: TabBarView(
                  children: [
                    _buildUpcomingVacationList(upcomingVacations),
                    _buildRecentVacationList(recentVacations),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingVacationList(List vacations) {
    if (vacations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.beach_access_rounded,
              size: 60,
              color: AppColors.accent4,
            ),
            SizedBox(height: 16),
            Text(
              'No upcoming vacations',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: vacations.length,
      itemBuilder: (context, index) {
        final vacation = vacations[index];
        final startDate = vacation['start_date'] ?? '';
        final endDate = vacation['end_date'] ?? '';
        final status = vacation['status'] ?? '';
        final reason = vacation['reason'] ?? '';
        final totalDays = vacation['total_days'] ?? 0;
        final requestId = vacation['request_id'];

        Color statusColor = AppColors.info;
        if (status == 'Approved') statusColor = AppColors.success;
        if (status == 'Rejected') statusColor = AppColors.error;
        if (status == 'Pending') statusColor = AppColors.warning;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent2),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      status == 'Approved' ? Icons.check_rounded :
                      status == 'Rejected' ? Icons.close_rounded :
                      Icons.pending_rounded,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$startDate - $endDate ($totalDays days)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    if (reason.isNotEmpty)
                      Text(
                        reason,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              if (status == 'Pending')
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.05),
                    border: Border(
                      top: BorderSide(color: AppColors.accent2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateVacationStatus(requestId, 'Approved'),
                          icon: Icon(Icons.check_rounded, size: 18),
                          label: Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateVacationStatus(requestId, 'Rejected'),
                          icon: Icon(Icons.close_rounded, size: 18),
                          label: Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentVacationList(List vacations) {
    if (vacations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.beach_access_rounded,
              size: 60,
              color: AppColors.accent4,
            ),
            SizedBox(height: 16),
            Text(
              'No recent vacations',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: vacations.length,
      itemBuilder: (context, index) {
        final vacation = vacations[index];
        final startDate = vacation['start_date'] ?? '';
        final endDate = vacation['end_date'] ?? '';
        final status = vacation['status'] ?? '';
        final reason = vacation['reason'] ?? '';
        final totalDays = vacation['total_days'] ?? 0;

        Color statusColor = AppColors.info;
        if (status == 'Approved') statusColor = AppColors.success;
        if (status == 'Rejected') statusColor = AppColors.error;
        if (status == 'Pending') statusColor = AppColors.warning;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent2),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  status == 'Approved' ? Icons.check_rounded :
                  status == 'Rejected' ? Icons.close_rounded :
                  Icons.pending_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$startDate - $endDate ($totalDays days)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                if (reason.isNotEmpty)
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateVacationStatus(int requestId, String status) async {
    try {
      final response = await ManagerVacationService.updateVacationRequestStatus(
        requestId: requestId,
        status: status,
      );

      if (response['success'] == true) {
        Navigator.pop(context);
        await _loadReport();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vacation request ${status.toLowerCase()} successfully'),
            backgroundColor: status == 'Approved' ? AppColors.success : AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to update vacation'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildScheduleSection() {
    final schedules = _report['schedules'] ?? [];

    return _buildSection(
      title: 'Weekly Schedule',
      icon: Icons.schedule_rounded,
      children: [
        if (schedules.isEmpty)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent2),
            ),
            child: Column(
              children: [
                Icon(Icons.schedule_outlined, size: 48, color: AppColors.accent4),
                SizedBox(height: 12),
                Text(
                  'No Schedule Assigned',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGray,
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _navigateToScheduleScreen(),
                  icon: Icon(Icons.add_rounded, size: 18),
                  label: Text('Add Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: Size(150, 40),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final schedule = schedules[index];
                  String startTime = schedule['start_time']?.split(':').take(2).join(':') ?? '';
                  String endTime = schedule['end_time']?.split(':').take(2).join(':') ?? '';

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent2),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            schedule['day_of_week'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '$startTime - $endTime',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: () => _navigateToScheduleScreen(),
                icon: Icon(Icons.schedule_rounded, size: 20),
                label: Text('View & Manage Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSessionsLists() {
    final upcomingSessions = _report['upcoming_sessions'] ?? [];
    final recentCompleted = _report['recent_completed_sessions'] ?? [];
    final recentCancelled = _report['recent_cancelled_sessions'] ?? [];

    return _buildSection(
      title: 'Recent Sessions',
      icon: Icons.event_available_rounded,
      children: [
        if (upcomingSessions.isNotEmpty) ...[
          Text(
            'Upcoming Sessions (${upcomingSessions.length})',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          ...upcomingSessions.map((session) {
            return _buildSessionItem(
              session,
              Icons.upcoming_rounded,
              AppColors.primary,
            );
          }).toList(),
          SizedBox(height: 16),
        ],

        if (recentCompleted.isNotEmpty) ...[
          Text(
            'Recent Completed (${recentCompleted.length})',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          ...recentCompleted.map((session) {
            return _buildSessionItem(
              session,
              Icons.check_circle_rounded,
              AppColors.success,
            );
          }).toList(),
          SizedBox(height: 16),
        ],

        if (recentCancelled.isNotEmpty) ...[
          Text(
            'Recent Cancelled (${recentCancelled.length})',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          ...recentCancelled.map((session) {
            return _buildSessionItem(
              session,
              Icons.cancel_rounded,
              AppColors.error,
              isCancelled: true,
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session, IconData icon, Color color, {bool isCancelled = false}) {
    String time = session['time']?.split(':').take(2).join(':') ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['child_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${session['date']} ${time.isNotEmpty ? 'at $time' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
                if (isCancelled && session['reason'] != null)
                  Text(
                    'Reason: ${session['reason']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              session['session_type'] ?? 'Session',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSpecialist() async {
    final TextEditingController salaryController = TextEditingController(
      text: _report['specialist_info']?['professional_info']?['salary']?.toString() ?? '',
    );

    bool _isUpdating = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.edit_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Edit Specialist Salary',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: salaryController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Salary',
                        prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Enter salary amount (e.g., 1500.50)',
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          if (double.parse(value) < 0) {
                            return 'Salary cannot be negative';
                          }
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16),

                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Specialist: ${widget.specialistName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Current Salary: ${_report['specialist_info']?['professional_info']?['salary']?.toString() ?? 'Not set'}',
                            style: TextStyle(
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isUpdating ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                ),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isUpdating ? null : () async {
                  if (salaryController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a salary amount'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }

                  final newSalary = double.tryParse(salaryController.text);
                  if (newSalary == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid number'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }

                  if (newSalary < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Salary cannot be negative'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _isUpdating = true;
                  });

                  try {
                    final response = await ManagerSpecialistService.updateSpecialistSalary(
                      specialistId: widget.specialistId,
                      newSalary: newSalary,
                    );

                    if (response['success'] == true) {
                      Navigator.pop(context);
                      await _loadReport();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Salary updated successfully to \$$newSalary'),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    } else {
                      throw Exception(response['message'] ?? 'Failed to update salary');
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating salary: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  } finally {
                    setState(() {
                      _isUpdating = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ment,
                  foregroundColor: Colors.white,
                ),
                child: _isUpdating
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text('Update Salary'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToScheduleScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialistScheduleScreen.fromReport(
          specialistId: widget.specialistId,
          specialistName: widget.specialistName,
        ),
      ),
    );
  }

  Future<void> _archiveSpecialist() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Archive ${widget.specialistName}?'),
        content: Text('Are you sure you want to archive this specialist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ManagerSpecialistService.archiveSpecialist(
                  specialistId: widget.specialistId,
                  forceArchive: false,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Specialist archived successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.yalw),
            child: Text('Archive'),
          ),
        ],
      ),
    );
  }

  String _formatSalary(dynamic salary) {
    if (salary == null) return 'Not set';

    if (salary is double || salary is int) {
      return '\$${salary.toStringAsFixed(2)}';
    }

    if (salary is String) {
      try {
        final parsed = double.parse(salary);
        return '\$${parsed.toStringAsFixed(2)}';
      } catch (e) {
        return salary;
      }
    }

    return salary.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Specialist Report',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 20),
            Text(
              'Loading Report...',
              style: TextStyle(color: AppColors.textGray),
            ),
          ],
        ),
      )
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 60, color: AppColors.error),
            SizedBox(height: 20),
            Text(_errorMessage, textAlign: TextAlign.center),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadReport,
              child: Text('Retry'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card - استبدالها بـ _buildProfileAvatar()
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // استخدام الـ Avatar الجديد
                  _buildProfileAvatar(),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.specialistName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _report['specialist_info']?['professional_info']?['specialization'] ?? 'Not Specified',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              '${_report['specialist_info']?['professional_info']?['average_rating'] ?? 'N/A'}/5',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 12),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _report['specialist_info']?['professional_info']?['approval_status'] == 'Approved'
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _report['specialist_info']?['professional_info']?['approval_status'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _report['specialist_info']?['professional_info']?['approval_status'] == 'Approved'
                                      ? AppColors.success
                                      : AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ... باقي الكود كما هو (بدون تغيير)
            SizedBox(height: 20),

            // Quick Stats
            Text(
              'Quick Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatCard(
                    'Total Sessions',
                    '${_report['statistics']?['sessions_summary']?['total_sessions'] ?? 0}',
                    Icons.calendar_today_rounded,
                    AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  _buildStatCard(
                    'Completed',
                    '${_report['statistics']?['sessions_summary']?['completed_sessions'] ?? 0}',
                    Icons.check_circle_rounded,
                    AppColors.success,
                  ),
                  SizedBox(width: 12),
                  _buildStatCard(
                    'Upcoming',
                    '${_report['statistics']?['sessions_summary']?['upcoming_sessions'] ?? 0}',
                    Icons.upcoming_rounded,
                    AppColors.blue,
                  ),
                  SizedBox(width: 12),
                  _buildStatCard(
                    'Cancelled',
                    '${_report['statistics']?['sessions_summary']?['cancelled_sessions'] ?? 0}',
                    Icons.cancel_rounded,
                    AppColors.error,
                  ),
                ],
              ),
            ),

            // ... باقي الأقسام كما هي
            // ================== باقي الكود كما هو ==================
            SizedBox(height: 24),

            // Personal Information مع Salary
            _buildSection(
              title: 'Personal Information',
              icon: Icons.person_rounded,
              children: [
                _buildInfoRow('Email', _report['specialist_info']?['personal_info']?['email'] ?? 'N/A'),
                _buildInfoRow('Phone', _report['specialist_info']?['personal_info']?['phone'] ?? 'N/A'),
                _buildInfoRow('Experience', '${_report['specialist_info']?['professional_info']?['years_experience'] ?? 0} years'),
                _buildInfoRow('Salary',
                  _report['specialist_info']?['professional_info']?['salary']?.toString() ?? 'Not set',
                ),
                _buildInfoRow('Status', _report['specialist_info']?['professional_info']?['approval_status'] ?? 'Unknown'),
                _buildInfoRow('Institution', _report['institution_info']?['institution_name'] ?? 'N/A'),
              ],
            ),

            // Detailed Session Statistics
            _buildSessionsDetailedStats(),

            // Ratings Section
            if (_report['statistics']?['ratings_summary'] != null)
              _buildSection(
                title: 'Ratings Summary',
                icon: Icons.star_rounded,
                children: [
                  _buildInfoRow('Total Ratings', '${_report['statistics']['ratings_summary']['total_ratings'] ?? 0}'),
                  _buildInfoRow('Average Rating', '${_report['statistics']['ratings_summary']['average_rating'] ?? 'N/A'}'),
                  if (_report['statistics']['ratings_summary']['rating_distribution'] != null) ...[
                    SizedBox(height: 8),
                    Divider(),
                    SizedBox(height: 8),
                    ..._report['statistics']['ratings_summary']['rating_distribution'].entries.map((entry) {
                      return _buildInfoRow(
                        '${entry.key} stars',
                        '${entry.value} ratings',
                      );
                    }).toList(),
                  ],
                ],
              ),

            // Vacation Statistics
            _buildVacationStats(),

            // Schedule Section
            _buildScheduleSection(),

            // Sessions Lists
            _buildSessionsLists(),

            SizedBox(height: 24),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToScheduleScreen(),
                          icon: Icon(Icons.schedule_rounded, size: 20),
                          label: Text('Manage Schedule'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _archiveSpecialist,
                          icon: Icon(Icons.archive_rounded, size: 20),
                          label: Text('Archive'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _editSpecialist,
                    icon: Icon(Icons.attach_money_rounded, size: 20, color: AppColors.ment),
                    label: Text(
                      'Edit Salary',
                      style: TextStyle(color: AppColors.ment),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.ment, width: 2),
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}