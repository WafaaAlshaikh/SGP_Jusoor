// lib/screens/manager/employment_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/manager/specialist_schedule_screen.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_specialist_api_service.dart';
import '../../widgets/loading_overlay.dart';
import 'interview_schedule_screen.dart';

class EmploymentRequestsScreen extends StatefulWidget {
  const EmploymentRequestsScreen({Key? key}) : super(key: key);

  @override
  _EmploymentRequestsScreenState createState() => _EmploymentRequestsScreenState();
}

class _EmploymentRequestsScreenState extends State<EmploymentRequestsScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _employmentRequests = [];
  Map<String, dynamic>? _selectedRequest;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _loadEmploymentRequests();
  }

  
  Future<void> _loadRequestDetails(int requestId) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await ManagerSpecialistApiService.getRequest(
        '/manager/employment/employment-requests/$requestId'
      );
      final data = response['data'] ?? {};

      setState(() {
        _selectedRequest = data;
        _showDetails = true;
      });
    } catch (e) {
      print('Error loading request details: $e');
      _showErrorSnackBar('Failed to load request details');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _scheduleInterview(int requestId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewScheduleScreen(
          requestId: requestId,
          specialistName: _selectedRequest?['specialist']?['full_name'],
        ),
      ),
    );

    if (result == true) {
      await _loadRequestDetails(requestId);
      await _loadEmploymentRequests();
    }
  }

  Future<void> _updateInterviewStatus(int interviewId, String status) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await ManagerSpecialistApiService.putRequest(
        '/manager/employment/interviews/$interviewId/status',
        {'status': status},
      );

      _showSuccessSnackBar('Interview marked as $status');
      await _loadRequestDetails(_selectedRequest!['request_id']);
      await _loadEmploymentRequests();
    } catch (e) {
      print('Error updating interview status: $e');
      _showErrorSnackBar('Failed to update interview status');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _approveRequest(int requestId) async {
    // Show salary input dialog
    final salary = await _showSalaryDialog();
    if (salary == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await ManagerSpecialistApiService.putRequest(
        '/manager/employment/employment-requests/$requestId/approve',
        {'salary': salary},
      );

      _showSuccessSnackBar('Employment request approved successfully');
      
      // Navigate to schedule screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SpecialistScheduleScreen.fromReport(
              specialistId: _selectedRequest!['specialist']?['user_id'],
              specialistName: _selectedRequest!['specialist']?['full_name'],
            ),
          ),
        );
      }
    } catch (e) {
      print('Error approving request: $e');
      _showErrorSnackBar('Failed to approve request: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    final reason = await _showRejectionDialog();
    if (reason == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await ManagerSpecialistApiService.putRequest(
        '/manager/employment/employment-requests/$requestId/reject',
        {'rejection_reason': reason},
      );

      _showSuccessSnackBar('Employment request rejected');
      await _loadRequestDetails(requestId);
      await _loadEmploymentRequests();
    } catch (e) {
      print('Error rejecting request: $e');
      _showErrorSnackBar('Failed to reject request');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<double?> _showSalaryDialog() async {
    TextEditingController salaryController = TextEditingController();

    return await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.attach_money_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 12),
            Text(
              'Set Salary',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please enter the monthly salary for ${_selectedRequest?['specialist']?['full_name']}',
                style: TextStyle(
                  color: AppColors.textGray,
                ),
              ),
              SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: salaryController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: InputBorder.none,
                    labelText: 'Monthly Salary *',
                    labelStyle: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.attach_money_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                    floatingLabelStyle: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent1.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Salary will be used for payroll calculations',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
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
              final salary = double.tryParse(salaryController.text);
              if (salary != null && salary > 0) {
                Navigator.pop(context, salary);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid salary amount'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRejectionDialog() async {
    TextEditingController reasonController = TextEditingController();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 12),
            Text(
              'Rejection Reason',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please provide a reason for rejecting this application',
                style: TextStyle(
                  color: AppColors.textGray,
                ),
              ),
              SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: reasonController,
                  maxLines: 4,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.all(16),
                    border: InputBorder.none,
                    hintText: 'Enter rejection reason...',
                    hintStyle: TextStyle(
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded,
                      color: AppColors.error,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This reason will be sent to the applicant',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
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
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a reason'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.ment,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // في دالة _loadEmploymentRequests، تحديث تحميل الإحصائيات:
Future<void> _loadEmploymentRequests() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final response = await ManagerSpecialistApiService.getRequest('/manager/employment/employment-requests');
    final data = response['data'] ?? {};

    // التأكد من أن القيم ليست null
    final byStatus = data['by_status'] ?? {};
    
    setState(() {
      _stats = {
        'total': data['total_requests']?.toInt() ?? 0,
        'pending': byStatus['pending']?.toInt() ?? 0,
        'interview': byStatus['interview']?.toInt() ?? 0,
        'approved': byStatus['approved']?.toInt() ?? 0,
        'rejected': byStatus['rejected']?.toInt() ?? 0,
      };

      _employmentRequests = (data['requests'] as List? ?? []).map((request) {
        // التأكد من أن البيانات موجودة
        final specialist = request['specialist'] ?? {};
        final professionalInfo = request['professional_info'] ?? {};
        final requestInfo = request['request_info'] ?? {};
        
        return {
          'request_id': request['request_id'] ?? 0,
          'specialist': {
            'user_id': specialist['user_id'] ?? 0,
            'full_name': specialist['full_name']?.toString() ?? 'Unknown',
            'email': specialist['email']?.toString() ?? '',
            'phone': specialist['phone']?.toString() ?? 'N/A',
            'profile_picture': specialist['profile_picture']?.toString(),
          },
          'professional_info': {
            'specialization': professionalInfo['specialization']?.toString() ?? '',
            'years_experience': professionalInfo['years_experience']?.toInt() ?? 0,
            'cv_url': professionalInfo['cv_url']?.toString(),
          },
          'request_info': {
            'status': requestInfo['status']?.toString() ?? 'Pending',
            'requested_at': requestInfo['requested_at']?.toString(),
            'reviewed_at': requestInfo['reviewed_at']?.toString(),
          },
          'interview': request['interview'],
        };
      }).toList();
    });
  } catch (e) {
    print('Error loading employment requests: $e');
    _showErrorSnackBar('Failed to load employment requests');
    
    // تعيين قيم افتراضية في حالة الخطأ
    setState(() {
      _stats = {
        'total': 0,
        'pending': 0,
        'interview': 0,
        'approved': 0,
        'rejected': 0,
      };
      _employmentRequests = [];
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

// تحديث دالة _buildStatsCard:
Widget _buildStatsCard() {
  // التأكد من أن القيم ليست null
  final total = _stats['total'] as int? ?? 0;
  final pending = _stats['pending'] as int? ?? 0;
  final interview = _stats['interview'] as int? ?? 0;
  final approved = _stats['approved'] as int? ?? 0;
  final rejected = _stats['rejected'] as int? ?? 0;

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Employment Requests',
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
                '$total Total',
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Pending', pending, AppColors.warning),
            _buildStatItem('Interview', interview, Color(0xFF2196F3)),
            _buildStatItem('Approved', approved, AppColors.ment),
            _buildStatItem('Rejected', rejected, AppColors.error),
          ],
        ),
      ],
    ),
  );
}

// تحديث دالة _buildStatItem:
Widget _buildStatItem(String label, int count, Color color) {
  return Column(
    children: [
      Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            count.toString(), // تحويل الـ int إلى string مباشرة
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
      SizedBox(height: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textGray,
        ),
      ),
    ],
  );
}

// إضافة دالة مساعدة لتحويل البيانات:
int _safeInt(dynamic value) {
  if (value == null) return 0;
  
  if (value is int) {
    return value;
  }
  
  if (value is double) {
    return value.toInt();
  }
  
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  
  return 0;
}

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final specialist = request['specialist'];
    final professionalInfo = request['professional_info'];
    final requestInfo = request['request_info'];
    final interview = request['interview'];

    Color statusColor = _getStatusColor(requestInfo['status']);

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
        border: Border.all(
          color: statusColor.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _loadRequestDetails(request['request_id']),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
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
                          (specialist['full_name'] as String)
                              .split(' ')
                              .map((n) => n.isNotEmpty ? n[0] : '')
                              .take(2)
                              .join(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
                          Text(
                            specialist['full_name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            professionalInfo['specialization'],
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        requestInfo['status'],
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Details
                Row(
                  children: [
                    _buildInfoChip(
                      '${professionalInfo['years_experience']} yrs',
                      Icons.work_history_rounded,
                    ),
                    SizedBox(width: 8),
                    if (interview != null)
                      _buildInfoChip(
                        'Interview Scheduled',
                        Icons.calendar_today_rounded,
                      ),
                  ],
                ),

                SizedBox(height: 12),

                // Request Date
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.textLight,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Applied: ${_formatDate(requestInfo['requested_at'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Action Button
                if (requestInfo['status'] == 'Pending')
                  _buildActionButton(
                    'Schedule Interview',
                    Icons.calendar_today_rounded,
                    AppColors.primary,
                    () => _scheduleInterview(request['request_id']),
                  )
                else if (requestInfo['status'] == 'Interview' && interview != null)
                  _buildInterviewActions(request, interview),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textGray),
          SizedBox(width: 4),
          Text(
            text,
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

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInterviewActions(Map<String, dynamic> request, Map<String, dynamic> interview) {
    return Column(
      children: [
        // Interview Info
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interview: ${_formatDateTime(interview['interview_date'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Status: ${interview['status']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        // Action Buttons
        Row(
          children: [
            if (interview['status'] == 'Scheduled')
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateInterviewStatus(interview['interview_id'], 'Completed'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.ment),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Icons.check_circle_rounded, size: 18, color: AppColors.ment),
                  label: Text(
                    'Mark Complete',
                    style: TextStyle(
                      color: AppColors.ment,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (interview['status'] == 'Completed')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveRequest(request['request_id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ment,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(
                    'Approve & Set Salary',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rejectRequest(request['request_id']),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error),
                  padding: EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.cancel_rounded, size: 18, color: AppColors.error),
                label: Text(
                  'Reject',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequestDetails() {
    if (_selectedRequest == null) return SizedBox();

    final specialist = _selectedRequest!['specialist'];
    final application = _selectedRequest!['application'];
    final interview = _selectedRequest!['interview'];
    final institution = _selectedRequest!['institution'] ?? {};

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _showDetails = false;
                      _selectedRequest = null;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Application Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Specialist Info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (specialist['full_name'] as String)
                          .split(' ')
                          .map((n) => n.isNotEmpty ? n[0] : '')
                          .take(2)
                          .join(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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
                    children: [
                      Text(
                        specialist['full_name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        specialist['email'],
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGray,
                        ),
                      ),
                      SizedBox(height: 4),
                      if (specialist['phone'] != null)
                        Text(
                          specialist['phone'],
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
          ),

          SizedBox(height: 20),

          // Application Details
          Text(
            'Application Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 12),

          _buildDetailItem('Specialization', application['specialization']),
          _buildDetailItem('Years of Experience', '${application['years_experience']} years'),
          _buildDetailItem('Application Status', application['status']),
          _buildDetailItem('Applied Date', _formatDate(application['requested_at'])),

          if (application['reviewed_at'] != null)
            _buildDetailItem('Reviewed Date', _formatDate(application['reviewed_at'])),

          SizedBox(height: 20),

          // Institution Info
          if (institution.isNotEmpty) ...[
            Text(
              'Institution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            _buildDetailItem('Name', institution['name']),
            if (institution['location'] != null)
              _buildDetailItem('Location', institution['location']),
          ],

          SizedBox(height: 20),

          // Interview Details (if exists)
          if (interview != null) ...[
            Text(
              'Interview Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            _buildDetailItem('Date & Time', _formatDateTime(interview['interview_date'])),
            _buildDetailItem('Type', interview['interview_type']),
            if (interview['location'] != null)
              _buildDetailItem('Location', interview['location']),
            if (interview['meeting_link'] != null)
              _buildDetailItem('Meeting Link', interview['meeting_link']),
            if (interview['notes'] != null)
              _buildDetailItem('Notes', interview['notes']),
            _buildDetailItem('Status', interview['status']),
          ],

          SizedBox(height: 20),

          // CV Download Button
          if (application['cv_url'] != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Handle CV download
                  _showCVOptions(application['cv_url']);
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.download_rounded, size: 18),
                label: Text(
                  'Download CV',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          SizedBox(height: 20),

          // Action Buttons
          if (application['status'] == 'Pending')
            _buildActionButton(
              'Schedule Interview',
              Icons.calendar_today_rounded,
              AppColors.primary,
              () => _scheduleInterview(_selectedRequest!['request_id']),
            )
          else if (application['status'] == 'Interview' && interview != null)
            _buildInterviewActions(_selectedRequest!, interview),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, dynamic value) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: EdgeInsets.only(top: 8, right: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGray,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value?.toString() ?? 'N/A',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCVOptions(String cvUrl) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CV Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.visibility_rounded, color: AppColors.primary),
              title: Text('View CV'),
              onTap: () {
                Navigator.pop(context);
                _viewCV(cvUrl);
              },
            ),
            ListTile(
              leading: Icon(Icons.download_rounded, color: AppColors.primary),
              title: Text('Download CV'),
              onTap: () {
                Navigator.pop(context);
                _downloadCV(cvUrl);
              },
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewCV(String cvUrl) {
    // Implement CV viewing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening CV...'),
      ),
    );
  }

  void _downloadCV(String cvUrl) {
    // Implement CV download
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading CV...'),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'interview': return Color(0xFF2196F3);
      case 'approved': return AppColors.ment;
      case 'rejected': return AppColors.error;
      default: return AppColors.textGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'Employment Requests',
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
                onPressed: _loadEmploymentRequests,
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
                        'Loading employment requests...',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : _showDetails
                  ? SingleChildScrollView(
                      child: _buildRequestDetails(),
                    )
                  : Column(
                      children: [
                        _buildStatsCard(),
                        Expanded(
                          child: _employmentRequests.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.assignment_turned_in_rounded,
                                        size: 80,
                                        color: AppColors.accent4,
                                      ),
                                      SizedBox(height: 20),
                                      Text(
                                        'No Employment Requests',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textGray,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'New specialist applications will appear here',
                                        style: TextStyle(
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _employmentRequests.length,
                                  itemBuilder: (context, index) {
                                    return _buildRequestCard(_employmentRequests[index]);
                                  },
                                ),
                        ),
                      ],
                    ),
        ),
        if (_isProcessing) LoadingOverlay(),
      ],
    );
  }
}