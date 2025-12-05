import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';

class ChildDetailedScreen extends StatefulWidget {
  final Map<String, dynamic> childData;

  ChildDetailedScreen({required this.childData});

  @override
  _ChildDetailedScreenState createState() => _ChildDetailedScreenState();
}

class _ChildDetailedScreenState extends State<ChildDetailedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> get data => widget.childData;
  Map<String, dynamic> get child => data['child'] ?? {};
  Map<String, dynamic> get stats => data['statistics'] ?? {};
  List<dynamic> get sessions => data['sessions']?['all_sessions'] ?? [];
  List<dynamic> get evaluations => data['evaluations']?['all_evaluations'] ?? [];
  Map<String, dynamic> get parents => data['parents'] ?? {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.ment.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Back button only at the top
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.textDark, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          SizedBox(height: 8),

          // Main Row with Avatar, Info, and Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    child['basic_info']?['full_name']?.toString().substring(0, 1) ?? '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Name and Status in the same row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            child['basic_info']?['full_name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Status Chip
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(child['basic_info']?['registration_status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(child['basic_info']?['registration_status']).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(child['basic_info']?['registration_status']),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                child['basic_info']?['registration_status'] ?? 'Unknown',
                                style: TextStyle(
                                  color: _getStatusColor(child['basic_info']?['registration_status']),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Other info
                    Row(
                      children: [
                        Icon(Icons.person_rounded, size: 16, color: AppColors.textLight),
                        SizedBox(width: 6),
                        Text(
                          '${child['basic_info']?['gender'] ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.cake_rounded, size: 16, color: AppColors.textLight),
                        SizedBox(width: 6),
                        Text(
                          '${_calculateAge(child['basic_info']?['date_of_birth'])} years',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.badge_rounded, size: 16, color: AppColors.textLight),
                        SizedBox(width: 6),
                        Text(
                          'ID: ${child['basic_info']?['child_id'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textGray,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        tabs: [
          Tab(text: 'Overview'),
          Tab(text: 'Sessions'),
          Tab(text: 'Progress'),
          Tab(text: 'Family'),
          Tab(text: 'Medical'),
        ],
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }

  Widget _buildOverviewTab() {
    final attendanceRate = stats['attendance_rate'] ?? '0%';
    final avgProgress = stats['average_progress_score'] ?? 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Quick Stats
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildStatCard(
                'Total Sessions',
                stats['total_sessions']?.toString() ?? '0',
                Icons.event_note_rounded,
                AppColors.primary,
              ),
              _buildStatCard(
                'Attendance Rate',
                attendanceRate,
                Icons.event_available_rounded,
                AppColors.ment,
              ),
              _buildStatCard(
                'Completed',
                stats['completed_sessions']?.toString() ?? '0',
                Icons.check_circle_rounded,
                AppColors.success,
              ),
              _buildStatCard(
                'Avg Progress',
                avgProgress is double ? '${avgProgress.toStringAsFixed(1)}%' : '$avgProgress%',
                Icons.trending_up_rounded,
                AppColors.warning,
              ),
            ],
          ),
          SizedBox(height: 20),

          // Progress Chart
          _buildProgressChart(),
          SizedBox(height: 20),

          // Recent Activity
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
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

  Widget _buildProgressChart() {
    final trend = data['evaluations']?['summary']?['progress_trend'] ?? [];

    if (trend.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Trend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timeline_rounded, size: 36, color: AppColors.textLight),
                    SizedBox(height: 8),
                    Text(
                      'No progress data available',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    try {
      // تحويل البيانات بفلاتر
      List<FlSpot> spots = [];
      List<String> dates = [];

      for (int i = 0; i < trend.length; i++) {
        final item = trend[i];
        if (item is Map<String, dynamic>) {
          final score = double.tryParse(item['score']?.toString() ?? '0') ?? 0.0;
          final dateStr = item['date']?.toString() ?? '';
          spots.add(FlSpot(i.toDouble(), score));

          // حفظ التواريخ للعرض
          if (dateStr.isNotEmpty) {
            try {
              final date = DateTime.parse(dateStr);
              dates.add('${date.day}/${date.month}');
            } catch (e) {
              dates.add('Day ${i + 1}');
            }
          } else {
            dates.add('Day ${i + 1}');
          }
        }
      }

      // حساب القيم القصوى والدنيا
      final scores = spots.map((spot) => spot.y).toList();
      final minScore = scores.isNotEmpty ? scores.reduce((a, b) => a < b ? a : b) : 0;
      final maxScore = scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 100;

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (spots.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${spots.length} evaluations',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: (minScore - 10).toDouble().clamp(0.0, double.infinity),
                  maxY: (maxScore + 10).toDouble().clamp(0.0, 100.0),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.accent1,
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < dates.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                dates[index],
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textGray,
                                ),
                              ),
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textGray,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: AppColors.accent4,
                      width: 0.5,
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.3),
                            AppColors.primary.withOpacity(0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.primary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            if (spots.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProgressStat('Start', '${spots.first.y.toInt()}%', AppColors.textGray),
                  _buildProgressStat('Current', '${spots.last.y.toInt()}%', AppColors.primary),
                  _buildProgressStat(
                      'Change',
                      '${((spots.last.y - spots.first.y)).toStringAsFixed(1)}%',
                      (spots.last.y - spots.first.y) >= 0 ? AppColors.ment : AppColors.error
                  ),
                ],
              ),
          ],
        ),
      );
    } catch (e) {
      print('Error building progress chart: $e');
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 36),
              SizedBox(height: 8),
              Text(
                'Error loading progress chart',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildProgressStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textGray,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final recentSessions = sessions.take(3).toList();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 16),
          ...recentSessions.map((session) => _buildActivityItem(session)).toList(),
          if (recentSessions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: AppColors.textLight, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> session) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getSessionColor(session['status']).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getSessionIcon(session['status']),
              color: _getSessionColor(session['status']),
              size: 18,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['session_details']?['name'] ?? 'Session',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${session['date']} • ${session['time']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getSessionColor(session['status']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              session['status'] ?? 'Unknown',
              style: TextStyle(
                fontSize: 10,
                color: _getSessionColor(session['status']),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Sessions Summary
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sessions Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildSessionStat('Total', stats['total_sessions'] ?? 0, AppColors.primary),
                    _buildSessionStat('Completed', stats['completed_sessions'] ?? 0, AppColors.ment),
                    _buildSessionStat('Upcoming', stats['upcoming_sessions'] ?? 0, AppColors.warning),
                    _buildSessionStat('Cancelled', stats['cancelled_sessions'] ?? 0, AppColors.error),
                    _buildSessionStat('Missed', stats['missed_sessions'] ?? 0, AppColors.info),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // All Sessions List
          ...sessions.map((session) => _buildSessionCard(session)).toList(),
        ],
      ),
    );
  }

  Widget _buildSessionStat(String label, dynamic value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
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

  Widget _buildSessionCard(Map<String, dynamic> session) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    session['session_details']?['name'] ?? 'Session',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getSessionColor(session['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    session['status'] ?? 'Unknown',
                    style: TextStyle(
                      color: _getSessionColor(session['status']),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),

            // Session Details
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textLight),
                SizedBox(width: 5),
                Text(
                  session['date'] ?? 'Unknown',
                  style: TextStyle(color: AppColors.textGray, fontSize: 12),
                ),
                SizedBox(width: 12),
                Icon(Icons.access_time_rounded, size: 14, color: AppColors.textLight),
                SizedBox(width: 5),
                Text(
                  session['time'] ?? 'Unknown',
                  style: TextStyle(color: AppColors.textGray, fontSize: 12),
                ),
                SizedBox(width: 12),
                Icon(Icons.person_rounded, size: 14, color: AppColors.textLight),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    session['specialist']?['name'] ?? 'No specialist',
                    style: TextStyle(color: AppColors.textGray, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Type & Duration
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    session['session_type'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.ment.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${session['session_details']?['duration'] ?? 0} mins',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.ment,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Spacer(),
                if (session['is_paid'] == true)
                  Icon(Icons.payment_rounded, color: AppColors.success, size: 16),
              ],
            ),

            if (session['notes'] != null && session['notes'].toString().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  Text(
                    'Notes:',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    session['notes'].toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Latest Progress
          if (data['evaluations']?['latest_progress'] != null)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Latest Evaluation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          data['evaluations']?['latest_progress']?['type'] ?? '',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress Score',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${data['evaluations']?['latest_progress']?['score'] ?? 0}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Evaluated by',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            data['evaluations']?['latest_progress']?['evaluated_by'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDate(data['evaluations']?['latest_progress']?['date']),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (data['evaluations']?['latest_progress']?['notes'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16),
                        Text(
                          'Notes:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          data['evaluations']?['latest_progress']?['notes'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textGray,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          // All Evaluations
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Evaluations (${evaluations.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),
                ...evaluations.map((evaluation) => _buildEvaluationCard(evaluation)).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationCard(Map<String, dynamic> evaluation) {
    final score = double.tryParse(evaluation['progress_score']?.toString() ?? '0') ?? 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getEvaluationColor(evaluation['type']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  evaluation['type'] ?? 'Evaluation',
                  style: TextStyle(
                    color: _getEvaluationColor(evaluation['type']),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textLight),
              SizedBox(width: 5),
              Text(
                _formatDate(evaluation['date']),
                style: TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
              SizedBox(width: 12),
              Icon(Icons.person_rounded, size: 13, color: AppColors.textLight),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  evaluation['evaluated_by'] ?? 'Unknown',
                  style: TextStyle(color: AppColors.textGray, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (evaluation['notes'] != null && evaluation['notes'].toString().isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                Text(
                  evaluation['notes'].toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFamilyTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Parent Info
          if (parents.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parent Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.ment.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: AppColors.ment,
                            size: 26,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parents['user_info']?['full_name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.email_rounded, size: 13, color: AppColors.textLight),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    parents['user_info']?['email'] ?? 'No email',
                                    style: TextStyle(color: AppColors.textGray, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),
                  Divider(height: 1),
                  SizedBox(height: 16),

                  // Contact Info
                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _buildContactItem('Phone', parents['contact']?['phone'] ?? 'N/A', Icons.phone_rounded),
                      _buildContactItem('Address', parents['address'] ?? 'N/A', Icons.location_on_rounded),
                      _buildContactItem('Occupation', parents['occupation'] ?? 'N/A', Icons.work_rounded),
                      _buildContactItem('City', parents['user_info']?['city'] ?? 'N/A', Icons.location_city_rounded),
                    ],
                  ),
                ],
              ),
            ),

          // Institution Info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institution Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),

                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child['institution_info']?['current_institution']?['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Enrolled: ${_formatDate(child['institution_info']?['enrollment_date'])}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Institution Details
                Column(
                  children: [
                    _buildInfoRow('Address', child['institution_info']?['current_institution']?['address'] ?? 'N/A'),
                    SizedBox(height: 10),
                    _buildInfoRow('Phone', child['institution_info']?['current_institution']?['phone'] ?? 'N/A'),
                    SizedBox(height: 10),
                    _buildInfoRow('Email', child['institution_info']?['current_institution']?['email'] ?? 'N/A'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Diagnosis
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diagnosis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),

                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              child['medical_info']?['diagnosis']?['name'] ?? 'Not specified',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Spacer(),
                          if (child['medical_info']?['risk_level'] != null)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getRiskColor(child['medical_info']?['risk_level']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _getRiskColor(child['medical_info']?['risk_level']).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getRiskColor(child['medical_info']?['risk_level']),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '${child['medical_info']?['risk_level']} Risk',
                                    style: TextStyle(
                                      color: _getRiskColor(child['medical_info']?['risk_level']),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      if (child['medical_info']?['diagnosis']?['description'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 14),
                            Text(
                              'Description:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              child['medical_info']?['diagnosis']?['description'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textGray,
                                height: 1.5,
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

          // Medical History
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),

                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    child['medical_info']?['medical_history'] ?? 'No medical history recorded.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Additional Info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Additional Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),

                Column(
                  children: [
                    if (child['medical_info']?['suspected_condition'] != null)
                      _buildInfoCard('Suspected Condition', child['medical_info']?['suspected_condition']),
                    if (child['medical_info']?['symptoms_description'] != null)
                      _buildInfoCard('Symptoms Description', child['medical_info']?['symptoms_description']),
                    if (child['personal_info']?['school_info'] != null)
                      _buildInfoCard('School Information', child['personal_info']?['school_info']),
                    if (child['personal_info']?['previous_services'] != null)
                      _buildInfoCard('Previous Services', child['personal_info']?['previous_services']),
                    if (child['personal_info']?['additional_notes'] != null)
                      _buildInfoCard('Additional Notes', child['personal_info']?['additional_notes']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
              height: 1.5,
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 160, // تصغير الارتفاع
              floating: true,
              pinned: true,
              snap: true,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(),
              ),
              leading: Container(), // إزالة الـ leading لأننا وضعنا زر الرجوع في الهيدر
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                child: _buildTabBar(),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildSessionsTab(),
            _buildProgressTab(),
            _buildFamilyTab(),
            _buildMedicalTab(),
          ],
        ),
      ),
    );
  }

  // Helper Functions
  int _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null) return 0;
    try {
      final dob = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      return now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1);
    } catch (e) {
      return 0;
    }
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'approved': return AppColors.primary;
      case 'completed': return AppColors.ment;
      case 'pending': return AppColors.warning;
      case 'inactive': return AppColors.info;
      default: return AppColors.textGray;
    }
  }

  Color _getSessionColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed': return AppColors.ment;
      case 'scheduled':
      case 'confirmed': return AppColors.primary;
      case 'pending approval': return AppColors.warning;
      case 'cancelled':
      case 'rejected': return AppColors.error;
      case 'absent': return AppColors.info;
      default: return AppColors.textGray;
    }
  }

  IconData _getSessionIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed': return Icons.check_circle_rounded;
      case 'scheduled': return Icons.event_available_rounded;
      case 'pending approval': return Icons.pending_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      case 'absent': return Icons.person_off_rounded;
      default: return Icons.event_rounded;
    }
  }

  Color _getEvaluationColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'initial': return AppColors.primary;
      case 'mid': return AppColors.warning;
      case 'final': return AppColors.ment;
      case 'follow-up': return AppColors.info;
      default: return AppColors.textGray;
    }
  }

  Color _getRiskColor(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'high': return AppColors.error;
      case 'medium': return AppColors.warning;
      case 'low': return AppColors.ment;
      default: return AppColors.textGray;
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 60; // تصغير ارتفاع التبويبات

  @override
  double get minExtent => 60;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => false;
}