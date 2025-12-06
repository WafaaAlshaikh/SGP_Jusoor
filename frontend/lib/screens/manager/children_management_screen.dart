import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/manager_children_service.dart';
import '../../theme/app_colors.dart';
import 'children_list_screen.dart';
import 'add_child_screen.dart'; // تأكد من المسار الصحيح
class ChildrenManagementScreen extends StatefulWidget {
  @override
  _ChildrenManagementScreenState createState() => _ChildrenManagementScreenState();
}

class _ChildrenManagementScreenState extends State<ChildrenManagementScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _apiData = {};
  List<dynamic> _childrenList = [];
  List<dynamic> _pendingRequests = [];
  Map<String, dynamic> _statistics = {};

  int _selectedChartIndex = 0;
  List<bool> _chartTypeSelected = [true, false, false];

  @override
  void initState() {
    super.initState();
    _loadChildrenData();
  }

  Future<void> _loadChildrenData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ManagerChildrenService.getChildrenManagementData();

      if (response['success'] == true) {
        setState(() {
          _apiData = response['data'];
          _statistics = _apiData['statistics'] ?? {};
          _childrenList = _apiData['children'] ?? [];
          _pendingRequests = _apiData['latest_registration_requests'] ?? [];

          // تحويل البيانات إلى التنسيق المطلوب
          _prepareDataForUI();
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load data');
      }
    } catch (e) {
      print('Error loading children data: $e');
      _showErrorDialog(e.toString());
      setState(() => _isLoading = false);
    }
  }

  void _prepareDataForUI() {
    // تحضير الإحصائيات للعرض
    _statistics = {
      'children_by_status': _apiData['statistics']['children_by_status'] ?? {},
      'children_updated_today': _apiData['statistics']['children_updated_today'] ?? 0,
      'children_with_sessions_today': _apiData['statistics']['children_with_sessions_today'] ?? 0,
      'absent_children_today': _apiData['statistics']['absent_children_today'] ?? 0,
      'registration_requests_today': _apiData['statistics']['registration_requests_today'] ?? 0,
      'total_children': _apiData['statistics']['total_children'] ?? 0,
    };

    // تحضير قائمة الأطفال
    _childrenList = _childrenList.map((child) {
      final status = child['registration_status'] ?? 'Unknown';
      final progress = double.tryParse(child['latest_progress']?['score']?.toString() ?? '0') ?? 0.0;

      return {
        'id': child['child_id']?.toString() ?? '',
        'name': child['full_name'] ?? 'Unknown',
        'age': _calculateAge(child['date_of_birth']),
        'diagnosis': child['Diagnosis']?['name'] ?? 'Not specified',
        'specialist': 'To be assigned', // يمكن إضافة من API في المستقبل
        'status': _translateStatus(status),
        'progress': progress / 100, // تحويل من 0-100 إلى 0-1
        'lastSession': _formatDate(child['latest_progress']?['date']),
        'nextSession': 'Check schedule',
        'rawData': child, // حفظ البيانات الأصلية
      };
    }).toList();

    // تحضير طلبات التسجيل
    _pendingRequests = _pendingRequests.map((request) {
      final child = request['Child'] ?? {};
      return {
        'request_id': request['request_id'],
        'child_id': child['child_id'],
        'childName': child['full_name'] ?? 'Unknown',
        'parentName': 'Parent', // يمكن إضافة من API
        'age': _calculateAge(child['date_of_birth']),
        'diagnosis': 'Pending assessment',
        'requestDate': _formatRequestDate(request['requested_at']),
        'priority': _determinePriority(request['requested_at']),
        'rawData': request, // حفظ البيانات الأصلية
      };
    }).toList();
  }

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

  String _translateStatus(String status) {
    switch (status) {
      case 'Pending': return 'Pending';
      case 'Approved': return 'Active';
      case 'Inactive': return 'Inactive';
      case 'Completed': return 'Completed';
      default: return 'Unknown';
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

  String _formatRequestDate(String? date) {
    if (date == null) return 'Unknown';
    try {
      final requestDate = DateTime.parse(date);
      final now = DateTime.now();
      final difference = now.difference(requestDate);

      if (difference.inDays == 0) return 'Today';
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      return _formatDate(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  String _determinePriority(String? requestDate) {
    if (requestDate == null) return 'Medium';
    try {
      final date = DateTime.parse(requestDate);
      final daysAgo = DateTime.now().difference(date).inDays;
      if (daysAgo <= 1) return 'High';
      if (daysAgo <= 3) return 'Medium';
      return 'Low';
    } catch (e) {
      return 'Medium';
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApproveRequest(int requestId) async {
    try {
      setState(() => _isLoading = true);
      await ManagerChildrenService.approveRegistrationRequest(requestId);
      await _loadChildrenData(); // Refresh data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request approved successfully'),
          backgroundColor: AppColors.ment,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRejectRequest(int requestId) async {
    try {
      setState(() => _isLoading = true);
      await ManagerChildrenService.rejectRegistrationRequest(requestId);
      await _loadChildrenData(); // Refresh data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingScreen() : _buildContent(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Children Management',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      actions: [
        // زر إضافة طفل جديد
        IconButton(
          icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
          onPressed: _navigateToAddChildScreen,
          tooltip: 'Add New Child',
        ),
        // زر التحديث
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
          onPressed: _loadChildrenData,
          tooltip: 'Refresh',
        ),
        if (_apiData['institution'] != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _apiData['institution']?['name'] ?? 'Institution',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        SizedBox(width: 8),
      ],
    );
  }


  void _navigateToAddChildScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddChildScreen(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Loading Children Data...',
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

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Column(
        children: [
          // Statistics Section with Charts
          _buildStatisticsCharts(),
          SizedBox(height: 20),

          // Quick Stats Cards
          _buildQuickStats(),
          SizedBox(height: 20),

          // Recent Children
          if (_childrenList.isNotEmpty) ...[
            _buildRecentChildren(),
            SizedBox(height: 20),
          ],

          // Pending Requests
          if (_pendingRequests.isNotEmpty) ...[
            _buildPendingRequests(),
            SizedBox(height: 30),
          ],

          // Empty State Messages
          if (_childrenList.isEmpty && _pendingRequests.isEmpty)
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCharts() {
    final statusCounts = _statistics['children_by_status'] ?? {};
    final total = _statistics['total_children'] ?? 0;

    // تحضير بيانات الـ Pie Chart
    final active = (statusCounts['Approved'] ?? 0).toDouble();
    final completed = (statusCounts['Completed'] ?? 0).toDouble();
    final pending = (statusCounts['Pending'] ?? 0).toDouble();
    final inactive = (statusCounts['Inactive'] ?? 0).toDouble();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
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
                'Children Analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Live Data',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Chart Type Selector
          _buildChartTypeSelector(),
          SizedBox(height: 20),

          // Chart Container
          Container(
            height: 220,
            child: _selectedChartIndex == 0
                ? _buildPieChart(active, completed, pending, inactive, total)
                : _selectedChartIndex == 1
                ? _buildBarChart(active, completed, pending, inactive)
                : _buildLineChart(),
          ),
          SizedBox(height: 20),

          // Chart Legend
          _buildChartLegend(statusCounts),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildChartTypeButton('Distribution', 0),
        SizedBox(width: 8),
        _buildChartTypeButton('Comparison', 1),
        SizedBox(width: 8),
        _buildChartTypeButton('Trend', 2),
      ],
    );
  }

  Widget _buildChartTypeButton(String label, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChartIndex = index;
          _chartTypeSelected = List.generate(3, (i) => i == index);
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: _chartTypeSelected[index]
              ? AppColors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _chartTypeSelected[index]
                ? AppColors.primary
                : AppColors.accent4,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _chartTypeSelected[index]
                ? Colors.white
                : AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(double active, double completed, double pending, double inactive, int total) {
    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            color: AppColors.primary,
            value: active,
            title: total > 0 ? '${((active / total) * 100).round()}%' : '0%',
            radius: 50,
            titleStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: AppColors.ment,
            value: completed,
            title: total > 0 ? '${((completed / total) * 100).round()}%' : '0%',
            radius: 50,
            titleStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: AppColors.warning,
            value: pending,
            title: total > 0 ? '${((pending / total) * 100).round()}%' : '0%',
            radius: 50,
            titleStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: AppColors.info,
            value: inactive,
            title: total > 0 ? '${((inactive / total) * 100).round()}%' : '0%',
            radius: 50,
            titleStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(double active, double completed, double pending, double inactive) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (active + completed + pending + inactive) * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                List<String> titles = ['Active', 'Completed', 'Pending', 'Inactive'];
                final index = value.toInt();
                if (index >= 0 && index < titles.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      titles[index],
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textGray,
                        fontWeight: FontWeight.w500,
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
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.accent1,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: active,
                color: AppColors.primary,
                width: 20,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: completed,
                color: AppColors.ment,
                width: 20,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(
                toY: pending,
                color: AppColors.warning,
                width: 20,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
          BarChartGroupData(
            x: 3,
            barRods: [
              BarChartRodData(
                toY: inactive,
                color: AppColors.info,
                width: 20,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    // بيانات افتراضية للرسم الخطي
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.accent1,
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final index = value.toInt();
                if (index >= 0 && index < days.length) {
                  return Text(
                    days[index],
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textGray,
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: false,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              FlSpot(0, 5),
              FlSpot(1, 7),
              FlSpot(2, 6),
              FlSpot(3, 8),
              FlSpot(4, 10),
              FlSpot(5, 9),
              FlSpot(6, 12),
            ],
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.1),
            ),
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(Map<String, dynamic> statusCounts) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem('Active', AppColors.primary, statusCounts['Approved'] ?? 0),
        _buildLegendItem('Completed', AppColors.ment, statusCounts['Completed'] ?? 0),
        _buildLegendItem('Pending', AppColors.warning, statusCounts['Pending'] ?? 0),
        _buildLegendItem('Inactive', AppColors.info, statusCounts['Inactive'] ?? 0),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, dynamic value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4),
          Text(
            '($value)',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _buildStatCard(
            'Today Registered',
            _statistics['children_updated_today']?.toString() ?? '0',
            Icons.person_add_rounded,
            AppColors.primary,
          ),
          _buildStatCard(
            'Today Sessions',
            _statistics['children_with_sessions_today']?.toString() ?? '0',
            Icons.event_available_rounded,
            AppColors.ment,
          ),
          _buildStatCard(
            'Absent Today',
            _statistics['absent_children_today']?.toString() ?? '0',
            Icons.person_off_rounded,
            AppColors.error,
          ),
          _buildStatCard(
            'New Requests',
            _statistics['registration_requests_today']?.toString() ?? '0',
            Icons.pending_actions_rounded,
            AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color cardColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: cardColor, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: cardColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentChildren() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
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
                'Children (${_statistics['total_children'] ?? 0})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              // عدل الـ View All Button فقط
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChildrenListScreen(), // بدون تمرير بيانات
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(50, 30),
                ),
                child: Text(
                  'View All →',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ..._childrenList.map((child) => _buildChildItem(child)).toList(),
        ],
      ),
    );
  }

  Widget _buildChildItem(Map<String, dynamic> child) {
    Color statusColor = _getStatusColor(child['status']);

    return GestureDetector(
      onTap: () {
        // Navigate to child details
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.03),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  child['name'].toString().substring(0, 1),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          child['name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          child['status'],
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '${child['diagnosis']} • Age ${child['age']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress Score',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: child['progress'],
                              backgroundColor: AppColors.accent1,
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                              borderRadius: BorderRadius.circular(10),
                              minHeight: 8,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '${(child['progress'] * 100).round()}%',
                        style: TextStyle(
                          fontSize: 16,
                          color: statusColor,
                          fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildPendingRequests() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
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
                'Pending Registration Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${_pendingRequests.length} New',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ..._pendingRequests.map((request) => _buildRequestItem(request)).toList(),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to all requests screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              icon: Icon(Icons.approval_rounded, size: 18),
              label: Text(
                'Review All Requests',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request) {
    Color priorityColor = request['priority'] == 'High'
        ? Color(0xFFFF6B6B)
        : request['priority'] == 'Medium'
        ? Color(0xFFFFA726)
        : Color(0xFF42A5F5);

    Color cardColor = priorityColor.withOpacity(0.1);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: priorityColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: priorityColor,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '${request['priority']} Priority',
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: AppColors.textLight),
                    SizedBox(width: 4),
                    Text(
                      request['requestDate'],
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.child_care_rounded,
                      color: priorityColor,
                      size: 24,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['childName'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Age: ${request['age']} years',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Request ID: ${request['request_id']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.medical_services_rounded,
                      size: 16, color: priorityColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diagnosis: ${request['diagnosis']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApproveRequest(request['request_id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ment,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.check, size: 18),
                    label: Text(
                      'Approve',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleRejectRequest(request['request_id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppColors.error, width: 1.5),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.close, size: 18),
                    label: Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.child_care_rounded,
            size: 80,
            color: AppColors.textLight.withOpacity(0.5),
          ),
          SizedBox(height: 20),
          Text(
            'No Children Data Available',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Start by adding children to your institution',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadChildrenData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: Icon(Icons.refresh_rounded),
            label: Text('Refresh Data'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return AppColors.primary;
      case 'approved': return AppColors.primary;
      case 'completed': return AppColors.ment;
      case 'pending': return AppColors.warning;
      case 'inactive': return AppColors.info;
      case 'absent': return AppColors.error;
      default: return AppColors.textGray;
    }
  }
}