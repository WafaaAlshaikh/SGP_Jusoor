import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_vacation_service.dart';
import 'package:intl/intl.dart';

class VacationScreen extends StatefulWidget {
  @override
  _VacationScreenState createState() => _VacationScreenState();
}

class _VacationScreenState extends State<VacationScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _vacationData = {};
  List<Map<String, dynamic>> _vacationRequests = [];
  Map<String, dynamic> _statistics = {};
  Map<String, dynamic> _institution = {};

  // فلترة
  String _selectedFilter = 'all'; // all, pending, approved, rejected
  String _selectedDateFilter = 'all'; // all, today, upcoming, past

  @override
  void initState() {
    super.initState();
    _loadVacationData();
  }

  Future<void> _loadVacationData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ManagerVacationService.getAllVacationRequests();
      final data = response['data'] ?? {};

      setState(() {
        _vacationData = data;
        _institution = data['institution'] ?? {};
        _statistics = data['statistics'] ?? {};
        _vacationRequests = List<Map<String, dynamic>>.from(data['vacation_requests'] ?? []);
      });
    } catch (e) {
      print('Error loading vacation data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load vacation data'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVacationStatus(int requestId, String status, {String? notes}) async {
    try {
      await ManagerVacationService.updateVacationRequestStatus(
        requestId: requestId,
        status: status,
        managerNotes: notes,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vacation request $status successfully'),
          backgroundColor: status == 'Approved' ? AppColors.success : AppColors.error,
        ),
      );

      await _loadVacationData();
    } catch (e) {
      print('Error updating vacation status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update vacation request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredRequests() {
    List<Map<String, dynamic>> filtered = List.from(_vacationRequests);

    // فلترة حسب الحالة
    if (_selectedFilter != 'all') {
      filtered = filtered.where((request) {
        final status = (request['status'] as String? ?? '').toLowerCase();
        return status == _selectedFilter.toLowerCase();
      }).toList();
    }

    // فلترة حسب التاريخ
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedDateFilter == 'today') {
      filtered = filtered.where((request) {
        final startDateStr = request['start_date'] as String?;
        final endDateStr = request['end_date'] as String?;
        if (startDateStr == null || endDateStr == null) return false;

        final startDate = DateTime.parse(startDateStr);
        final endDate = DateTime.parse(endDateStr);

        return (startDate.isBefore(today) || startDate.isAtSameMomentAs(today)) &&
            (endDate.isAfter(today) || endDate.isAtSameMomentAs(today));
      }).toList();
    } else if (_selectedDateFilter == 'upcoming') {
      filtered = filtered.where((request) {
        final startDateStr = request['start_date'] as String?;
        if (startDateStr == null) return false;

        final startDate = DateTime.parse(startDateStr);
        return startDate.isAfter(today);
      }).toList();
    } else if (_selectedDateFilter == 'past') {
      filtered = filtered.where((request) {
        final endDateStr = request['end_date'] as String?;
        if (endDateStr == null) return false;

        final endDate = DateTime.parse(endDateStr);
        return endDate.isBefore(today);
      }).toList();
    }

    // ترتيب حسب التاريخ (الأحدث أولاً)
    filtered.sort((a, b) {
      final aDate = DateTime.parse(b['start_date'] ?? '');
      final bDate = DateTime.parse(a['start_date'] ?? '');
      return aDate.compareTo(bDate);
    });

    return filtered;
  }

  List<Map<String, dynamic>> _getTodayVacations() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _vacationRequests.where((request) {
      final status = (request['status'] as String? ?? '').toLowerCase();
      if (status != 'approved') return false;

      final startDateStr = request['start_date'] as String?;
      final endDateStr = request['end_date'] as String?;
      if (startDateStr == null || endDateStr == null) return false;

      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);

      return (startDate.isBefore(today) || startDate.isAtSameMomentAs(today)) &&
          (endDate.isAfter(today) || endDate.isAtSameMomentAs(today));
    }).toList();
  }

  Widget _buildStatisticsCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Institution Info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _institution['name'] ?? 'Institution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Vacation Management',
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

          SizedBox(height: 30),

          // Statistics Grid
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.65, // ⬅️ جرب هذه النسبة
            children: [
              _buildStatItem('Total', _statistics['total']?.toString() ?? '0',
                  AppColors.primary, Icons.assignment_rounded),
              _buildStatItem('Pending', _statistics['pending']?.toString() ?? '0',
                  AppColors.warning, Icons.pending_actions_rounded),
              _buildStatItem('Approved', _statistics['approved']?.toString() ?? '0',
                  AppColors.success, Icons.check_circle_rounded),
              _buildStatItem('Rejected', _statistics['rejected']?.toString() ?? '0',
                  AppColors.error, Icons.cancel_rounded),
            ],
          ),

          SizedBox(height: 30),

          // Today's Vacations
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent2,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.beach_access_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'On Vacation Today',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_getTodayVacations().length} specialist${_getTodayVacations().length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 30,
              margin: EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Filter
          Text(
            'Filter by Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', _selectedFilter),
                SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending', _selectedFilter),
                SizedBox(width: 8),
                _buildFilterChip('Approved', 'approved', _selectedFilter),
                SizedBox(width: 8),
                _buildFilterChip('Rejected', 'rejected', _selectedFilter),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Date Filter
          Text(
            'Filter by Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', _selectedDateFilter),
                SizedBox(width: 8),
                _buildFilterChip('Today', 'today', _selectedDateFilter),
                SizedBox(width: 8),
                _buildFilterChip('Upcoming', 'upcoming', _selectedDateFilter),
                SizedBox(width: 8),
                _buildFilterChip('Past', 'past', _selectedDateFilter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String selectedValue) {
    final isSelected = selectedValue == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (value == 'all') {
            _selectedFilter = 'all';
          } else if (value == 'pending' || value == 'approved' || value == 'rejected') {
            _selectedFilter = value;
          } else {
            _selectedDateFilter = value;
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.accent2,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildVacationRequestCard(Map<String, dynamic> request) {
    final specialist = request['specialist'] ?? {};
    final status = request['status'] as String? ?? 'Pending';
    final startDate = request['start_date'] as String? ?? '';
    final endDate = request['end_date'] as String? ?? '';
    final reason = request['reason'] as String?;
    final totalDays = request['total_days'] ?? 0;

    Color statusColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = AppColors.ment;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.pending_rounded;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateTime = DateTime.parse(startDate);
    final endDateTime = DateTime.parse(endDate);

    bool isToday = (startDateTime.isBefore(today) || startDateTime.isAtSameMomentAs(today)) &&
        (endDateTime.isAfter(today) || endDateTime.isAtSameMomentAs(today));
    bool isUpcoming = startDateTime.isAfter(today);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Specialist Info
          ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (specialist['full_name'] ?? '').split(' ').map((n) => n[0]).take(2).join(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            title: Text(
              specialist['full_name'] ?? 'Unknown Specialist',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  specialist['specialization'] ?? 'Specialist',
                  style: TextStyle(color: AppColors.textGray),
                ),
              ],
            ),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  SizedBox(width: 6),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Vacation Details
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDate(startDate),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'End Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDate(endDate),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Duration and Status
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent1,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '$totalDays day${totalDays != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 8),

                    if (isToday)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ),

                    if (isUpcoming && !isToday)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.ment.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Upcoming',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ment,
                          ),
                        ),
                      ),
                  ],
                ),

                // Reason if exists
                if (reason != null && reason.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent2,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note_rounded,
                              size: 16,
                              color: AppColors.textGray,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Reason',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          reason,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons for Pending requests
          if (status.toLowerCase() == 'pending') ...[
            Divider(height: 1, color: AppColors.accent2),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(request['request_id']),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.close_rounded, size: 18),
                      label: Text('Reject'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateVacationStatus(request['request_id'], 'Approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.check_rounded, size: 18),
                      label: Text('Approve'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRejectDialog(int requestId) async {
    TextEditingController notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 12),
            Text(
              'Reject Vacation Request',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_rounded,
                    size: 20,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Are you sure you want to reject this vacation request?',
                      style: TextStyle(
                        color: AppColors.textGray,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Reason for rejection (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.all(16),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textGray,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateVacationStatus(requestId, 'Rejected', notes: notesController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.beach_access_rounded,
            size: 100,
            color: AppColors.accent4,
          ),
          SizedBox(height: 20),
          Text(
            'No vacation requests found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When specialists request vacations,\nthey will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadVacationData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.refresh_rounded),
            label: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRequests = _getFilteredRequests();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Vacation Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
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
            onPressed: _loadVacationData,
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
              'Loading vacation data...',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadVacationData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Statistics Card
              _buildStatisticsCard(),

              SizedBox(height: 16),

              // Filters
              _buildFilters(),

              SizedBox(height: 20),

              // Vacation Requests List
              if (filteredRequests.isNotEmpty)
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Vacation Requests',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${filteredRequests.length} request${filteredRequests.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    ...filteredRequests.map((request) => _buildVacationRequestCard(request)).toList(),
                  ],
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: _buildEmptyState(),
                ),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}