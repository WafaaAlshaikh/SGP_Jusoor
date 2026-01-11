import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/manager_children_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import 'child_detailed_screen.dart';

class ChildrenListScreen extends StatefulWidget {
  // لم نعد نحتاج initialChildren
  ChildrenListScreen();

  @override
  _ChildrenListScreenState createState() => _ChildrenListScreenState();
}

class _ChildrenListScreenState extends State<ChildrenListScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<dynamic> _childrenList = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  List<String> _filters = ['All', 'Active', 'Completed', 'Pending', 'Inactive','Archived'];
  Map<String, dynamic>? _institutionInfo;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
    ));
    _loadChildrenData();
  }

  Future<void> _loadChildrenData() async {
    setState(() => _isLoading = true);

    try {
      final response = await ManagerChildrenService.getChildrenManagementData();

      if (response['success'] == true) {
        final data = response['data'];
        _institutionInfo = data['institution'];
        final rawChildren = data['children'] ?? [];

        // تحويل البيانات مباشرة من API
        _childrenList = _convertApiChildren(rawChildren);

        print('=== DEBUG: Loaded ${_childrenList.length} children from API ===');
        _debugChildrenData();
      } else {
        throw Exception(response['message'] ?? 'Failed to load data');
      }
    } catch (e) {
      print('Error loading children data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load children: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _convertApiChildren(List<dynamic> rawChildren) {
    return rawChildren.map((rawChild) {
      // تحويل البيانات مباشرة من API
      final childName = rawChild['full_name']?.toString() ?? 'Unknown';

      final rawStatus = rawChild['registration_status']?.toString() ?? 'Unknown';
      final diagnosis = rawChild['Diagnosis']?['name']?.toString() ?? 'Not specified';
      final age = _calculateAge(rawChild['date_of_birth']?.toString());
      final gender = rawChild['gender']?.toString() ?? 'Unknown';

      // الحصول على التقدم من latest_progress
      final latestProgress = rawChild['latest_progress'];
      double progressScore = 0.0;
      String? lastSessionDate;

      if (latestProgress != null && latestProgress is Map) {
        progressScore = double.tryParse(latestProgress['score']?.toString() ?? '0') ?? 0.0;
        lastSessionDate = latestProgress['date']?.toString();
      }

      return {
        'child_id': rawChild['child_id'] ?? 0,
        'name': childName,
        'photo': rawChild['photo']?.toString() ?? '',
        'age': age,
        'diagnosis': diagnosis,
        'gender': gender,
        'rawStatus': rawStatus,
        'status': _translateStatus(rawStatus),
        'progressScore': progressScore,
        'progress': progressScore / 100, // تحويل 0-100 إلى 0-1
        'lastSession': lastSessionDate,
        'registrationDate': rawChild['created_at']?.toString(),
        'parent_name': rawChild['Parent']?['User']?['full_name']?.toString(),
        'parent_phone': rawChild['parent_phone']?.toString() ??
            rawChild['Parent']?['User']?['phone']?.toString(),
        'rawData': rawChild, // حفظ البيانات الأصلية
      };
    }).toList();
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadChildrenData();
    setState(() => _isRefreshing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Children list updated'),
        backgroundColor: AppColors.ment,
      ),
    );
  }

  int _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return 0;
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
      case 'Archived': return 'Archived';
      default: return status;
    }
  }

  Color _getStatusColor(String? status) {
    final statusStr = status?.toLowerCase() ?? 'unknown';
    switch (statusStr) {
      case 'active':
      case 'approved':
        return AppColors.primary;
      case 'completed':
        return AppColors.ment;
      case 'pending':
        return AppColors.warning;
      case 'inactive':
        return AppColors.info;
      case 'Archived':
        return AppColors.textGray;

      default:
        return AppColors.textGray;
    }
  }

  List<dynamic> get _filteredChildren {
    List<dynamic> result = _childrenList;

    if (_searchQuery.isNotEmpty) {
      result = result.where((child) {
        final name = child['name']?.toString().toLowerCase() ?? '';
        final diagnosis = child['diagnosis']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || diagnosis.contains(query);
      }).toList();
    }

    if (_selectedFilter != 'All') {
      result = result.where((child) {
        final childStatus = child['status']?.toString() ?? '';
        return childStatus == _selectedFilter;
      }).toList();
    }

    return result;
  }

  void _navigateToChildDetails(Map<String, dynamic> child) async {
    setState(() => _isLoading = true);

    try {
      final response = await ManagerChildrenService.getChildDetailedInfo(child['child_id']);

      if (response['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChildDetailedScreen(
              childData: response['data'],
            ),
          ),
        );
      } else {
        throw Exception('Failed to load child details');
      }
    } catch (e) {
      print('Error loading child details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load details: ${e.toString()}'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final childName = child['name']?.toString() ?? 'Unknown';
    final status = child['status']?.toString() ?? 'Unknown';
    final diagnosis = child['diagnosis']?.toString() ?? 'Not specified';

    final age = child['age']?.toString() ?? '0';
    final gender = child['gender']?.toString() ?? 'Unknown';
    final progress = child['progress'] is num ? child['progress'].toDouble() : 0.0;
    final childId = child['child_id'] ?? 0;

    final statusColor = _getStatusColor(status);
    final progressPercentage = (progress * 100).round();
    final firstLetter = childName.isNotEmpty ? childName.substring(0, 1) : '?';
    final photoUrl = ApiService.buildFileUrl(child['photo']?.toString());
    final lastSession = _formatDate(child['lastSession']?.toString());
    final registrationDate = _formatDate(child['registrationDate']?.toString());

    // Check if child is archived
    final bool isArchived = status == 'Archived';

    return GestureDetector(
      onTap: () => _navigateToChildDetails(child),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.08),
              blurRadius: 15,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: statusColor.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: photoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    firstLetter,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: statusColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Text(
                              firstLetter,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                childName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.cake_rounded, size: 14, color: AppColors.textLight),
                            SizedBox(width: 4),
                            Text(
                              '$age years',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.medical_services_rounded, size: 14, color: AppColors.textLight),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                diagnosis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textGray,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        if (child['parent_name'] != null)
                          Row(
                            children: [
                              Icon(Icons.family_restroom_rounded, size: 12, color: AppColors.textLight),
                              SizedBox(width: 4),
                              Text(
                                'Parent: ${child['parent_name']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Progress Section (لا تظهر للأرشيف)
              if (!isArchived) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress Score',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '$progressPercentage%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: AppColors.accent1,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      borderRadius: BorderRadius.circular(10),
                      minHeight: 10,
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],

              // Stats Row
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Last Session', lastSession),
                    Container(
                      height: 30,
                      width: 1,
                      color: AppColors.accent4,
                    ),
                    _buildStatItem('Registered', registrationDate),
                    Container(
                      height: 30,
                      width: 1,
                      color: AppColors.accent4,
                    ),
                    _buildStatItem('Gender', gender),
                  ],
                ),
              ),
              SizedBox(height: 10),

              // Buttons Row (مختلف حسب الحالة)
              Row(
                children: [
                  // View Details Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToChildDetails(child),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor.withOpacity(0.1),
                        foregroundColor: statusColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      icon: Icon(Icons.visibility_rounded, size: 18),
                      label: Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),

                  // Conditional Button: Archive or Restore
                  SizedBox(
                    width: 48,
                    child: ElevatedButton(
                      onPressed: isArchived
                          ? () => _showRestoreConfirmationDialog(childId, childName)
                          : () => _showArchiveConfirmationDialog(childId, childName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isArchived
                            ? AppColors.ment.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                        foregroundColor: isArchived
                            ? AppColors.ment
                            : AppColors.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Icon(
                        isArchived
                            ? Icons.restore_from_trash_rounded
                            : Icons.delete_outline_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRestoreConfirmationDialog(int childId, String childName) async {
    bool? shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restore_from_trash_rounded, color: AppColors.ment),
            SizedBox(width: 10),
            Text(
              'Restore Child',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to restore "$childName"?',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This action will:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Change child status from "Archived" to "Active"'),
                  Text('• Make child visible in active list'),
                  Text('• Child can now have new sessions'),
                  Text('• Parents will be notified'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ment,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Yes, Restore',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldRestore == true) {
      await _performRestore(childId, childName);
    }
  }
  Future<void> _performRestore(int childId, String childName) async {
    setState(() => _isLoading = true);

    try {
      // استخدمي دالة restore المخصصة
      final response = await ManagerChildrenService.restoreArchivedChild(childId);

      if (response['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored "$childName"'),
            backgroundColor: AppColors.ment,
            duration: Duration(seconds: 3),
          ),
        );

        // Refresh the list
        await _refreshData();

        // Show success dialog
        await _showRestoreSuccessDialog(childName);
      }
    } catch (e) {
      print('Error restoring child: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore child: ${e.toString()}'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showRestoreSuccessDialog(String childName) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.ment),
            SizedBox(width: 10),
            Text(
              'Restore Completed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully restored "$childName"',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ment.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Steps:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ment,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('• Child is now visible in Active list'),
                  Text('• You can now schedule new sessions'),
                  Text('• Parents have been notified'),
                  Text('• Progress tracking resumed'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColors.ment,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showArchiveConfirmationDialog(int childId, String childName) async {
    bool? shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Text(
              'Archive Child',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to archive "$childName"?',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This action will:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Cancel all upcoming sessions'),
                  Text('• Change child status to "Archived"'),
                  // Text('• Remove from active children list'),
                  Text('• Can be restored later if needed'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Yes, Archive',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldContinue == true) {
      await _startArchiveProcess(childId, childName);
    }
  }

  Future<void> _startArchiveProcess(int childId, String childName) async {
    setState(() => _isLoading = true);

    try {
      // Step 1: Check if child can be archived
      final checkResponse = await ManagerChildrenService.checkChildArchiveEligibility(childId);

      if (checkResponse['success'] == true) {
        final data = checkResponse['data'];
        final canArchiveDirectly = data['eligibility_check']['can_archive_directly'] ?? false;
        final hasUpcomingSessions = data['eligibility_check']['has_upcoming_sessions'] ?? false;
        final upcomingCount = data['eligibility_check']['upcoming_sessions_count'] ?? 0;
        final sessionDetails = data['session_details'];

        if (canArchiveDirectly) {
          // No upcoming sessions - archive directly
          await _showFinalConfirmationDialog(childId, childName, upcomingCount: 0);
        } else if (hasUpcomingSessions) {
          // Has upcoming sessions - show warning
          await _showUpcomingSessionsWarning(
              childId,
              childName,
              upcomingCount,
              sessionDetails
          );
        }
      }
    } catch (e) {
      print('Error checking archive eligibility: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showUpcomingSessionsWarning(
      int childId,
      String childName,
      int upcomingCount,
      Map<String, dynamic> sessionDetails
      ) async {
    final scheduled = sessionDetails['scheduled'] as List? ?? [];
    final rescheduled = sessionDetails['rescheduled'] as List? ?? [];
    final pending = sessionDetails['pending'] as List? ?? [];

    bool? proceedWithForce = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Text(
              'Upcoming Sessions Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$childName" has $upcomingCount upcoming session(s):',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 12),

            if (scheduled.isNotEmpty) ...[
              Text(
                'Scheduled Sessions:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              ...scheduled.take(3).map((session) =>
                  Text('• ${session['formatted_date']} at ${session['formatted_time']}')
              ),
              if (scheduled.length > 3)
                Text('... and ${scheduled.length - 3} more'),
              SizedBox(height: 8),
            ],

            if (rescheduled.isNotEmpty) ...[
              Text(
                'Rescheduled Sessions:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              ...rescheduled.take(3).map((session) =>
                  Text('• ${session['formatted_date']} at ${session['formatted_time']}')
              ),
              if (rescheduled.length > 3)
                Text('... and ${rescheduled.length - 3} more'),
              SizedBox(height: 8),
            ],

            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                      SizedBox(width: 4),
                      Text(
                        'Warning:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'If you proceed, all upcoming sessions will be cancelled automatically.',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Cancel Sessions & Archive',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (proceedWithForce == true) {
      await _showFinalConfirmationDialog(childId, childName, upcomingCount: upcomingCount);
    }
  }

  Future<void> _showFinalConfirmationDialog(
      int childId,
      String childName,
      {int upcomingCount = 0}
      ) async {
    bool? confirmArchive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text(
              'Final Confirmation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you absolutely sure?',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 12),
            if (upcomingCount > 0) ...[
              Text(
                '$upcomingCount session(s) will be cancelled.',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
            ],
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action is irreversible and will:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('• Remove "$childName" from active list'),
                  Text('• Cancel all associated sessions'),
                  Text('• Update specialist statistics'),
                  Text('• Notify parents automatically'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No, Go Back',
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Yes, Archive Child',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmArchive == true) {
      await _performForceArchive(childId, childName);
    }
  }

  Future<void> _performForceArchive(int childId, String childName) async {
    setState(() => _isLoading = true);

    try {
      final response = await ManagerChildrenService.forceArchiveChild(childId);

      if (response['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully archived "$childName"'),
            backgroundColor: AppColors.ment,
            duration: Duration(seconds: 3),
          ),
        );

        // Refresh the list
        await _refreshData();

        // Show detailed success dialog
        await _showArchiveSuccessDialog(response['data']);
      }
    } catch (e) {
      print('Error archiving child: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to archive child: ${e.toString()}'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showArchiveSuccessDialog(Map<String, dynamic> data) async {
    final childInfo = data['child_info'];
    final sessionsCancelled = data['sessions_cancelled'];
    final summary = data['summary'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.ment),
            SizedBox(width: 10),
            Text(
              'Archive Completed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully archived "${childInfo['child_name']}"',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ment.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ment,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('• ${sessionsCancelled['total_cancelled']} session(s) cancelled'),
                  Text('• ${sessionsCancelled['upcoming_cancelled']} were upcoming'),
                  Text('• ${sessionsCancelled['past_cancelled']} were past/current'),
                  Text('• Child status changed to "Archived"'),
                ],
              ),
            ),
            SizedBox(height: 8),

            Text(
              summary['message'],
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColors.ment,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty || date == 'N/A') return 'N/A';
    try {
      final dt = DateTime.parse(date);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _debugChildrenData() {
    print('=== DEBUG CHILDREN DATA ===');
    print('Total children: ${_childrenList.length}');

    for (int i = 0; i < _childrenList.length; i++) {
      final child = _childrenList[i];
      print('\nChild $i:');
      print('  Name: ${child['name']}');
      print('  Status: ${child['status']}');
      print('  Diagnosis: ${child['diagnosis']}');
      print('  Age: ${child['age']}');
      print('  Gender: ${child['gender']}');
      print('  Progress: ${child['progress']} (${child['progressScore']})');
      print('  Parent: ${child['parent_name']}');
    }
    print('=== END DEBUG ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(),
            SizedBox(height: 16),

            // Search and Filter
            _buildSearchFilter(),
            SizedBox(height: 16),

            // Children List
            Expanded(
              child: _isLoading ? _buildLoadingScreen() : _buildChildrenList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Children List',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                if (_institutionInfo != null)
                  Text(
                    _institutionInfo!['name'] ?? 'Institution',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _refreshData,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search children...',
                hintStyle: TextStyle(color: AppColors.textLight),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          SizedBox(height: 12),

          // Filter Chips
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;

                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = selected ? filter : 'All';
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textGray,
                      fontWeight: FontWeight.w600,
                    ),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.accent4,
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
            'Loading Children...',
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

  Widget _buildChildrenList() {
    if (_isRefreshing) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final filteredChildren = _filteredChildren;

    if (filteredChildren.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.child_care_rounded,
              size: 80,
              color: AppColors.textLight.withOpacity(0.5),
            ),
            SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty ? 'No children found' : 'No children available',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textGray,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Check back later for updates',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              child: Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: _refreshData,
      child: ListView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '${filteredChildren.length} Children Found',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...filteredChildren.map((child) => _buildChildCard(child)),
          SizedBox(height: 30),
        ],
      ),
    );
  }
}