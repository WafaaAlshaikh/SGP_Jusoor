// lib/screens/admin/institution_management.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/admin_api_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../map_screen.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class InstitutionManagement extends StatefulWidget {
  @override
  _InstitutionManagementState createState() => _InstitutionManagementState();
}

class _InstitutionManagementState extends State<InstitutionManagement> {
  List<Map<String, dynamic>> _institutions = [];
  bool _isLoading = true;
  bool _isAnalyticsLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'Pending';
  int _analyticsRangeDays = 90;
  int _topAnalyticsRangeDays = 90;
  int _topAnalyticsLimit = 10;
  String _topAnalyticsMetric = 'score';

  Map<String, dynamic>? _institutionsAnalytics;
  Map<String, dynamic>? _institutionsAnalyticsTop;
  Map<String, dynamic>? _institutionsAnalyticsHistory;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRows = 0;
  int _rowsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // New state for analytics sections
  bool _showTopAnalytics = true;
  bool _showHistoryAnalytics = false;
  String _historyBucket = 'day';

  final List<String> _statusOptions = [
    'Pending',
    'Approved',
    'Rejected',
    'Suspended',
    'All'
  ];

  final List<String> _topMetricOptions = ['score', 'child_requests', 'rating'];

  final List<String> _bucketOptions = ['day', 'month'];

  @override
  void initState() {
    super.initState();
    _loadInstitutions(page: 1);
    _loadInstitutionsAnalytics();
    _loadInstitutionsAnalyticsTop();
    _loadInstitutionsAnalyticsHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInstitutions({int page = 1}) async {
    try {
      setState(() => _isLoading = true);

      final response = await AdminApiService.getInstitutions(
        page: page,
        limit: _rowsPerPage,
        status: _statusFilter == 'All' ? null : _statusFilter,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      );

      if (response['success'] == true) {
        final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? {};
        final list = (data['institutions'] as List?) ?? const [];

        setState(() {
          _institutions =
              list.map((e) => (e as Map).cast<String, dynamic>()).toList();
          _currentPage = (data['page'] as int?) ?? page;
          _totalPages = (data['totalPages'] as int?) ?? 1;
          _totalRows = (data['total'] as int?) ?? _institutions.length;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading institutions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInstitutionsAnalytics() async {
    try {
      setState(() => _isAnalyticsLoading = true);

      final resp = await AdminApiService.getInstitutionsAnalyticsOverview(
        rangeDays: _analyticsRangeDays,
        limit: 5,
      );

      if (!mounted) return;

      if (resp['success'] == true) {
        setState(() {
          _institutionsAnalytics =
              (resp['data'] as Map?)?.cast<String, dynamic>();
          _isAnalyticsLoading = false;
        });
      } else {
        setState(() => _isAnalyticsLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAnalyticsLoading = false);
    }
  }

  Future<void> _loadInstitutionsAnalyticsTop() async {
    try {
      final resp = await AdminApiService.getInstitutionsAnalyticsTop(
        rangeDays: _topAnalyticsRangeDays,
        limit: _topAnalyticsLimit,
        metric: _topAnalyticsMetric,
      );

      if (!mounted) return;

      if (resp['success'] == true) {
        setState(() {
          _institutionsAnalyticsTop =
              (resp['data'] as Map?)?.cast<String, dynamic>();
        });
      }
    } catch (_) {
      print('Error loading top analytics');
    }
  }

  Future<void> _loadInstitutionsAnalyticsHistory() async {
    try {
      final resp = await AdminApiService.getInstitutionsAnalyticsHistory(
        rangeDays: _topAnalyticsRangeDays,
        bucket: _historyBucket,
      );

      if (!mounted) return;

      if (resp['success'] == true) {
        setState(() {
          _institutionsAnalyticsHistory =
              (resp['data'] as Map?)?.cast<String, dynamic>();
        });
      }
    } catch (_) {
      print('Error loading history analytics');
    }
  }

  Future<void> _approveInstitution(int institutionId) async {
    final ok = await AdminApiService.approveInstitution(institutionId,
        notes: 'Approved by admin');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Institution approved successfully'
            : 'Failed to approve institution'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    if (ok) _loadInstitutions(page: _currentPage);
  }

  Future<void> _rejectInstitution(int institutionId) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.do_not_disturb, color: AppColors.error),
            SizedBox(width: 10),
            Text('Reject Institution',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ],
        ),
        backgroundColor: AppColors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please provide a reason for rejection:',
                style: TextStyle(color: AppColors.textGray)),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent1),
              ),
              child: TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  hintStyle: TextStyle(color: AppColors.textLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Reject'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    if (result != null) {
      final ok = await AdminApiService.rejectInstitution(institutionId,
          reason: result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ok ? 'Institution rejected' : 'Failed to reject institution'),
          backgroundColor: ok ? AppColors.warning : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (ok) _loadInstitutions(page: _currentPage);
    }
  }

  Future<void> _suspendInstitution(int institutionId) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pause_circle, color: AppColors.warning),
            SizedBox(width: 10),
            Text('Suspend Institution',
                style: TextStyle(color: AppColors.textDark)),
          ],
        ),
        backgroundColor: AppColors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Optional: provide a suspension reason.',
                style: TextStyle(color: AppColors.textGray)),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent1),
              ),
              child: TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Reason (optional)',
                  hintStyle: TextStyle(color: AppColors.textLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'reason': reasonController.text.trim().isEmpty
                  ? null
                  : reasonController.text.trim(),
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Suspend'),
          ),
        ],
      ),
    );

    if (result != null) {
      final ok = await AdminApiService.suspendInstitution(
        institutionId,
        reason: result['reason'] as String?,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ok ? 'Institution suspended' : 'Failed to suspend institution'),
          backgroundColor: ok ? AppColors.warning : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (ok) _loadInstitutions(page: _currentPage);
    }
  }

  Future<void> _archiveInstitution(int institutionId, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive institution?',
            style: TextStyle(color: AppColors.textDark)),
        content: Text(
            'This will disable "$name" (soft delete). You can re-enable it later by editing the institution.',
            style: TextStyle(color: AppColors.textGray)),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Archive'),
          ),
        ],
      ),
    );

    if (result == true) {
      final ok = await AdminApiService.deleteInstitution(institutionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ok ? 'Institution archived' : 'Failed to archive institution'),
          backgroundColor: ok ? AppColors.error : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (ok) _loadInstitutions(page: _currentPage);
    }
  }

  Future<void> _showInstitutionForm({Map<String, dynamic>? institution}) async {
    final isEdit = institution != null;
    final nameController =
        TextEditingController(text: institution?['name']?.toString() ?? '');
    final emailController = TextEditingController(
        text: institution?['contact_email']?.toString() ?? '');
    final phoneController = TextEditingController(
        text: institution?['contact_phone']?.toString() ?? '');
    final cityController =
        TextEditingController(text: institution?['city']?.toString() ?? '');
    final regionController =
        TextEditingController(text: institution?['region']?.toString() ?? '');
    final addressController = TextEditingController(
        text: institution?['location_address']?.toString() ?? '');
    final websiteController =
        TextEditingController(text: institution?['website']?.toString() ?? '');
    final licenseController = TextEditingController(
        text: institution?['license_number']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    double? locationLat = institution?['location_lat'] != null
        ? double.tryParse(institution!['location_lat'].toString())
        : null;
    double? locationLng = institution?['location_lng'] != null
        ? double.tryParse(institution!['location_lng'].toString())
        : null;

    bool useExistingManager = true;
    final managerSearchController = TextEditingController();
    List<Map<String, dynamic>> managerSearchResults = [];
    Map<String, dynamic>? selectedManagerUser;

    final managerNameController = TextEditingController();
    final managerEmailController = TextEditingController();
    final managerPhoneController = TextEditingController();
    final managerDepartmentController = TextEditingController();

    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          Future<void> searchManagers() async {
            final q = managerSearchController.text.trim();
            if (q.isEmpty) {
              setLocalState(() {
                managerSearchResults = [];
              });
              return;
            }
            try {
              final resp =
                  await AdminApiService.getUsers(page: 1, limit: 10, search: q);
              final data =
                  (resp['data'] as Map?)?.cast<String, dynamic>() ?? {};
              final list = (data['users'] as List?) ?? const [];
              setLocalState(() {
                managerSearchResults = list
                    .map((e) => (e as Map).cast<String, dynamic>())
                    .toList();
              });
            } catch (_) {
              setLocalState(() {
                managerSearchResults = [];
              });
            }
          }

          Future<void> pickLocation() async {
            final locationResult = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapScreen(
                  initialLat: locationLat,
                  initialLng: locationLng,
                  initialAddress: addressController.text.trim().isEmpty
                      ? null
                      : addressController.text.trim(),
                ),
              ),
            );

            if (locationResult != null &&
                locationResult is Map<String, dynamic>) {
              setLocalState(() {
                locationLat = (locationResult['lat'] as num?)?.toDouble();
                locationLng = (locationResult['lng'] as num?)?.toDouble();
              });
              cityController.text = (locationResult['city']?.toString() ?? '');
              regionController.text =
                  (locationResult['region']?.toString() ?? '');
              addressController.text =
                  (locationResult['address']?.toString() ?? '');
            }
          }

          return Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: EdgeInsets.all(24),
              width: 560,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Institution' : 'Add Institution',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: Icon(Icons.close_rounded,
                              color: AppColors.textLight),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormField(
                              controller: nameController,
                              label: 'Name',
                              icon: Icons.business_rounded,
                              isRequired: true,
                            ),
                            SizedBox(height: 12),
                            _buildFormField(
                              controller: emailController,
                              label: 'Contact Email',
                              icon: Icons.email_rounded,
                            ),
                            SizedBox(height: 12),
                            _buildFormField(
                              controller: phoneController,
                              label: 'Contact Phone',
                              icon: Icons.phone_rounded,
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    controller: cityController,
                                    label: 'City',
                                    icon: Icons.location_city_rounded,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildFormField(
                                    controller: regionController,
                                    label: 'Region',
                                    icon: Icons.map_rounded,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildFormField(
                              controller: addressController,
                              label: 'Address',
                              icon: Icons.home_work_rounded,
                              maxLines: 2,
                            ),
                            SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: pickLocation,
                              icon: Icon(Icons.map_rounded,
                                  color: AppColors.primary),
                              label: Text(
                                (locationLat != null && locationLng != null)
                                    ? 'Change location (${locationLat!.toStringAsFixed(4)}, ${locationLng!.toStringAsFixed(4)})'
                                    : 'Pick location from map',
                                style: TextStyle(color: AppColors.primary),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildFormField(
                              controller: websiteController,
                              label: 'Website',
                              icon: Icons.language_rounded,
                            ),
                            SizedBox(height: 12),
                            _buildFormField(
                              controller: licenseController,
                              label: 'License Number',
                              icon: Icons.badge_rounded,
                            ),
                            if (!isEdit) ...[
                              SizedBox(height: 18),
                              Text(
                                'Manager',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.accent1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: RadioListTile<bool>(
                                            value: true,
                                            groupValue: useExistingManager,
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: Text('Existing user',
                                                style: TextStyle(
                                                    color: AppColors.textDark)),
                                            onChanged: (v) {
                                              if (v == null) return;
                                              setLocalState(() {
                                                useExistingManager = v;
                                                selectedManagerUser = null;
                                              });
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<bool>(
                                            value: false,
                                            groupValue: useExistingManager,
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: Text('New manager',
                                                style: TextStyle(
                                                    color: AppColors.textDark)),
                                            onChanged: (v) {
                                              if (v == null) return;
                                              setLocalState(() {
                                                useExistingManager = v;
                                                selectedManagerUser = null;
                                                managerSearchResults = [];
                                                managerSearchController.clear();
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (useExistingManager) ...[
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFormField(
                                              controller:
                                                  managerSearchController,
                                              label:
                                                  'Search user (name/email/phone)',
                                              icon: Icons.search,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: searchManagers,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor:
                                                  AppColors.textWhite,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 18, vertical: 14),
                                            ),
                                            child: Text('Search'),
                                          ),
                                        ],
                                      ),
                                      if (managerSearchResults.isNotEmpty) ...[
                                        SizedBox(height: 10),
                                        Container(
                                          constraints:
                                              BoxConstraints(maxHeight: 180),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: AppColors.accent1),
                                          ),
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            itemCount:
                                                managerSearchResults.length,
                                            separatorBuilder: (_, __) =>
                                                Divider(
                                                    height: 1,
                                                    color: AppColors.accent1),
                                            itemBuilder: (context, i) {
                                              final u = managerSearchResults[i];
                                              final uid = u['user_id'];
                                              final isSelected =
                                                  selectedManagerUser?[
                                                          'user_id'] ==
                                                      uid;
                                              return ListTile(
                                                dense: true,
                                                title: Text(u['full_name']
                                                        ?.toString() ??
                                                    'Unknown'),
                                                subtitle: Text(
                                                    u['email']?.toString() ??
                                                        ''),
                                                trailing: isSelected
                                                    ? Icon(Icons.check_circle,
                                                        color:
                                                            AppColors.success)
                                                    : null,
                                                onTap: () {
                                                  setLocalState(() {
                                                    selectedManagerUser = u;
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                      if (selectedManagerUser != null) ...[
                                        SizedBox(height: 10),
                                        Text(
                                          'Selected: ${selectedManagerUser!['full_name'] ?? ''} (${selectedManagerUser!['email'] ?? ''})',
                                          style: TextStyle(
                                              color: AppColors.success,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ]
                                    ] else ...[
                                      SizedBox(height: 8),
                                      _buildFormField(
                                        controller: managerNameController,
                                        label: 'Manager Full Name',
                                        icon: Icons.person,
                                        isRequired: true,
                                      ),
                                      SizedBox(height: 12),
                                      _buildFormField(
                                        controller: managerEmailController,
                                        label: 'Manager Email',
                                        icon: Icons.email,
                                        isRequired: true,
                                      ),
                                      SizedBox(height: 12),
                                      _buildFormField(
                                        controller: managerPhoneController,
                                        label: 'Manager Phone',
                                        icon: Icons.phone,
                                      ),
                                      SizedBox(height: 12),
                                      _buildFormField(
                                        controller: managerDepartmentController,
                                        label: 'Department (optional)',
                                        icon: Icons.apartment,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'A password will be generated automatically and emailed to the manager.',
                                        style: TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text('Cancel',
                              style: TextStyle(color: AppColors.textGray)),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState?.validate() != true)
                              return;
                            if (!isEdit) {
                              if (locationLat == null || locationLng == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Please pick the institution location from map'),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              if (useExistingManager &&
                                  selectedManagerUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Please select an existing manager user'),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                            }
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                          ),
                          child: Text(
                              isEdit ? 'Save Changes' : 'Create Institution'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result == true) {
      final institutionData = {
        'name': nameController.text.trim(),
        'contact_email': emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        'contact_phone': phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        'city': cityController.text.trim().isEmpty
            ? null
            : cityController.text.trim(),
        'region': regionController.text.trim().isEmpty
            ? null
            : regionController.text.trim(),
        'location_address': addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        'location_lat': locationLat,
        'location_lng': locationLng,
        'website': websiteController.text.trim().isEmpty
            ? null
            : websiteController.text.trim(),
        'license_number': licenseController.text.trim().isEmpty
            ? null
            : licenseController.text.trim(),
      };

      final payload = isEdit
          ? institutionData
          : {
              'institution': institutionData,
              'manager': useExistingManager
                  ? {
                      'existing_user_id': selectedManagerUser?['user_id'],
                    }
                  : {
                      'new_manager': {
                        'full_name': managerNameController.text.trim(),
                        'email': managerEmailController.text.trim(),
                        'phone': managerPhoneController.text.trim().isEmpty
                            ? null
                            : managerPhoneController.text.trim(),
                        'department':
                            managerDepartmentController.text.trim().isEmpty
                                ? null
                                : managerDepartmentController.text.trim(),
                      }
                    },
            };

      try {
        if (isEdit) {
          final id =
              int.tryParse(institution!['institution_id'].toString()) ?? 0;
          await AdminApiService.updateInstitution(id, payload);
        } else {
          await AdminApiService.createInstitution(payload);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Institution updated successfully'
                : 'Institution created successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadInstitutions(page: 1);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operation failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textLight),
          hintText: 'Enter $label',
          hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.accent1, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: isRequired
            ? (v) =>
                (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 210,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent1),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInstitutionDetails(Map<String, dynamic> institution) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 500,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    institution['name']?.toString() ?? 'Institution Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textLight),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(institution['approval_status'])
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(institution['approval_status'])
                        .withOpacity(0.3),
                  ),
                ),
                child: Text(
                  institution['approval_status']?.toString() ?? 'N/A',
                  style: TextStyle(
                    color: _getStatusColor(institution['approval_status']),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value:
                            institution['contact_email']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value:
                            institution['contact_phone']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.location_city_rounded,
                        label: 'City',
                        value: institution['city']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.map_rounded,
                        label: 'Region',
                        value: institution['region']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.home_work_rounded,
                        label: 'Address',
                        value: institution['location_address']?.toString() ??
                            'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.language_rounded,
                        label: 'Website',
                        value: institution['website']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.badge_rounded,
                        label: 'License Number',
                        value:
                            institution['license_number']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Created',
                        value:
                            institution['created_at']?.split('T')[0] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.update_rounded,
                        label: 'Last Updated',
                        value:
                            institution['updated_at']?.split('T')[0] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.check_circle_rounded,
                        label: 'Active',
                        value:
                            (institution['is_active'] == true) ? 'Yes' : 'No',
                      ),
                      if (institution['managers'] != null &&
                          institution['managers'].isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 16),
                            Text(
                              'MANAGERS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textLight,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 8),
                            ...institution['managers'].map<Widget>((manager) {
                              return Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.accent1),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          AppColors.primary.withOpacity(0.1),
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            manager['full_name'] ?? 'Unknown',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            manager['email'] ?? 'No email',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textGray),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
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

  // New widgets for analytics sections
  Widget _buildTopInstitutionsAnalytics() {
    final data = _institutionsAnalyticsTop ?? {};
    final topInstitutions = (data['top_institutions'] as List?) ?? [];
    final metric = data['metric']?.toString() ?? 'score';
    final rangeDays = data['range_days']?.toString() ?? '90';

    if (_isAnalyticsLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (topInstitutions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined,
                size: 60, color: AppColors.textLight),
            SizedBox(height: 16),
            Text(
              'No analytics data available',
              style: TextStyle(color: AppColors.textGray),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with filters
        Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Institutions Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              // Filters row with Wrap to prevent overflow
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Metric Filter
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent1),
                    ),
                    child: DropdownButton<String>(
                      value: _topAnalyticsMetric,
                      items: _topMetricOptions.map((metric) {
                        String displayText;
                        switch (metric) {
                          case 'score':
                            displayText = 'Demand Score';
                            break;
                          case 'child_requests':
                            displayText = 'Child Requests';
                            break;
                          case 'rating':
                            displayText = 'Rating';
                            break;
                          default:
                            displayText = metric;
                        }
                        return DropdownMenuItem<String>(
                          value: metric,
                          child:
                              Text(displayText, style: TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _topAnalyticsMetric = value;
                          });
                          _loadInstitutionsAnalyticsTop();
                        }
                      },
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down,
                          size: 16, color: AppColors.primary),
                    ),
                  ),

                  // Range Days Filter
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent1),
                    ),
                    child: DropdownButton<int>(
                      value: _topAnalyticsRangeDays,
                      items: const [30, 60, 90, 180].map((days) {
                        return DropdownMenuItem<int>(
                          value: days,
                          child: Text('$days days',
                              style: TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _topAnalyticsRangeDays = value;
                          });
                          _loadInstitutionsAnalyticsTop();
                        }
                      },
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down,
                          size: 16, color: AppColors.primary),
                    ),
                  ),

                  // Refresh Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent1),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.refresh, size: 16),
                      onPressed: _loadInstitutionsAnalyticsTop,
                      tooltip: 'Refresh',
                      color: AppColors.primary,
                      padding: EdgeInsets.all(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Institutions List
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: topInstitutions.length,
          separatorBuilder: (context, index) => SizedBox(height: 12),
          itemBuilder: (context, index) {
            final institution = topInstitutions[index] as Map<String, dynamic>;
            final metrics =
                institution['metrics'] as Map<String, dynamic>? ?? {};
            final rank = index + 1;

            Color rankColor;
            if (rank == 1) {
              rankColor = Color(0xFFFFD700); // Gold
            } else if (rank == 2) {
              rankColor = Color(0xFFC0C0C0); // Silver
            } else if (rank == 3) {
              rankColor = Color(0xFFCD7F32); // Bronze
            } else {
              rankColor = AppColors.primary;
            }

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent1),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: rankColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  institution['name']?.toString() ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    // Wrap metrics chips to prevent overflow
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildMetricChip(
                          icon: Icons.child_care,
                          value: '${metrics['child_requests'] ?? 0}',
                          color: AppColors.success,
                        ),
                        _buildMetricChip(
                          icon: Icons.medical_services,
                          value: '${metrics['specialist_requests'] ?? 0}',
                          color: AppColors.warning,
                        ),
                        _buildMetricChip(
                          icon: Icons.star,
                          value:
                              '${(metrics['avg_rating'] ?? 0).toStringAsFixed(1)}',
                          color: Color(0xFFFFA000),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Score: ${(institution['score'] ?? 0).toStringAsFixed(1)}',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(institution['approval_status'] ?? '')
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    institution['approval_status']?.toString() ?? 'Unknown',
                    style: TextStyle(
                      color:
                          _getStatusColor(institution['approval_status'] ?? ''),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricChip(
      {required IconData icon, required String value, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryAnalytics() {
    final data = _institutionsAnalyticsHistory ?? {};
    final series = (data['series'] as Map<String, dynamic>?) ?? {};
    final childRequests = (series['child_requests'] as List?) ?? [];
    final specialistRequests = (series['specialist_requests'] as List?) ?? [];
    final sessions = (series['sessions'] as List?) ?? [];
    final reviews = (series['reviews'] as List?) ?? [];

    if (_isAnalyticsLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    // Prepare data for chart
    List<Map<String, dynamic>> chartData = [];

    // Combine all series into single list for chart
    Map<String, Map<String, dynamic>> combinedData = {};

    void addToCombined(String bucket, String type, dynamic value) {
      if (!combinedData.containsKey(bucket)) {
        combinedData[bucket] = {
          'bucket': bucket,
          'Child Requests': 0,
          'Specialist Requests': 0,
          'Sessions': 0,
          'Reviews': 0,
        };
      }
      combinedData[bucket]![type] =
          (combinedData[bucket]![type] as int) + (value as int);
    }

    for (var item in childRequests) {
      final map = item as Map<String, dynamic>;
      addToCombined(
          map['bucket'].toString(), 'Child Requests', map['count'] ?? 0);
    }

    for (var item in specialistRequests) {
      final map = item as Map<String, dynamic>;
      addToCombined(
          map['bucket'].toString(), 'Specialist Requests', map['count'] ?? 0);
    }

    for (var item in sessions) {
      final map = item as Map<String, dynamic>;
      addToCombined(map['bucket'].toString(), 'Sessions', map['count'] ?? 0);
    }

    for (var item in reviews) {
      final map = item as Map<String, dynamic>;
      addToCombined(map['bucket'].toString(), 'Reviews', map['count'] ?? 0);
    }

    chartData = combinedData.values.toList();
    chartData.sort((a, b) => a['bucket'].compareTo(b['bucket']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with filters
        Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activity History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              // Filters row with Wrap to prevent overflow
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Bucket Filter
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent1),
                    ),
                    child: DropdownButton<String>(
                      value: _historyBucket,
                      items: _bucketOptions.map((bucket) {
                        return DropdownMenuItem<String>(
                          value: bucket,
                          child: Text(bucket == 'day' ? 'Daily' : 'Monthly',
                              style: TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _historyBucket = value;
                          });
                          _loadInstitutionsAnalyticsHistory();
                        }
                      },
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down,
                          size: 16, color: AppColors.primary),
                    ),
                  ),

                  // Range Days Filter
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent1),
                    ),
                    child: DropdownButton<int>(
                      value: _topAnalyticsRangeDays,
                      items: const [30, 60, 90, 180].map((days) {
                        return DropdownMenuItem<int>(
                          value: days,
                          child: Text('$days days',
                              style: TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _topAnalyticsRangeDays = value;
                          });
                          _loadInstitutionsAnalyticsHistory();
                        }
                      },
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down,
                          size: 16, color: AppColors.primary),
                    ),
                  ),

                  // Refresh Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent1),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.refresh, size: 16),
                      onPressed: _loadInstitutionsAnalyticsHistory,
                      tooltip: 'Refresh',
                      color: AppColors.primary,
                      padding: EdgeInsets.all(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Chart
        if (chartData.isNotEmpty)
          Container(
            height: 300,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent1),
            ),
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(
                labelRotation: 45,
                labelStyle: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 11,
                ),
              ),
              primaryYAxis: NumericAxis(
                labelStyle: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 11,
                ),
              ),
              legend: Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                textStyle: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 12,
                ),
              ),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries>[
                ColumnSeries<Map<String, dynamic>, String>(
                  name: 'Child Requests',
                  dataSource: chartData,
                  xValueMapper: (data, _) => data['bucket'],
                  yValueMapper: (data, _) =>
                      data['Child Requests']?.toDouble() ?? 0,
                  color: AppColors.success,
                ),
                ColumnSeries<Map<String, dynamic>, String>(
                  name: 'Specialist Requests',
                  dataSource: chartData,
                  xValueMapper: (data, _) => data['bucket'],
                  yValueMapper: (data, _) =>
                      data['Specialist Requests']?.toDouble() ?? 0,
                  color: AppColors.warning,
                ),
                LineSeries<Map<String, dynamic>, String>(
                  name: 'Sessions',
                  dataSource: chartData,
                  xValueMapper: (data, _) => data['bucket'],
                  yValueMapper: (data, _) => data['Sessions']?.toDouble() ?? 0,
                  color: AppColors.primary,
                  markerSettings: MarkerSettings(isVisible: true),
                ),
                LineSeries<Map<String, dynamic>, String>(
                  name: 'Reviews',
                  dataSource: chartData,
                  xValueMapper: (data, _) => data['bucket'],
                  yValueMapper: (data, _) => data['Reviews']?.toDouble() ?? 0,
                  color: Color(0xFF9C27B0),
                  markerSettings: MarkerSettings(isVisible: true),
                ),
              ],
            ),
          )
        else
          Container(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timeline_outlined,
                      size: 60, color: AppColors.textLight),
                  SizedBox(height: 16),
                  Text(
                    'No history data available',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                ],
              ),
            ),
          ),

        // Summary Statistics
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Period Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              // Use Wrap or SingleChildScrollView for summary stats
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSummaryStat(
                      label: 'Total Requests',
                      value: (childRequests.fold(
                                  0,
                                  (sum, item) =>
                                      sum +
                                      ((((item as Map)['count'] as num?) ?? 0)
                                          .toInt())) +
                              specialistRequests.fold(
                                  0,
                                  (sum, item) =>
                                      sum +
                                      ((((item as Map)['count'] as num?) ?? 0)
                                          .toInt())))
                          .toString(),
                      icon: Icons.request_quote,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 12),
                    _buildSummaryStat(
                      label: 'Total Sessions',
                      value: sessions
                          .fold(
                              0,
                              (sum, item) =>
                                  sum +
                                  ((((item as Map)['count'] as num?) ?? 0)
                                      .toInt()))
                          .toString(),
                      icon: Icons.event,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 12),
                    _buildSummaryStat(
                      label: 'Total Reviews',
                      value: reviews
                          .fold(
                              0,
                              (sum, item) =>
                                  sum +
                                  ((((item as Map)['count'] as num?) ?? 0)
                                      .toInt()))
                          .toString(),
                      icon: Icons.reviews,
                      color: Color(0xFF9C27B0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: BoxConstraints(minWidth: 120),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = kIsWeb && width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Institution Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => _loadInstitutions(page: _currentPage),
            tooltip: 'Refresh',
            color: AppColors.primary,
          ),
          SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showInstitutionForm(),
            icon: Icon(Icons.add_business_rounded, size: 20),
            label: Text('Add Institution'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Institutions Analytics Dashboard
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.accent1, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights_rounded, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Institution Insights (last $_analyticsRangeDays days)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent1),
                        ),
                        child: DropdownButton<int>(
                          value: _analyticsRangeDays,
                          items: const [30, 90].map((d) {
                            return DropdownMenuItem<int>(
                              value: d,
                              child: Text('$d days',
                                  style: TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _analyticsRangeDays = v);
                            _loadInstitutionsAnalytics();
                          },
                          underline: SizedBox(),
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor: AppColors.surface,
                          icon: Icon(Icons.arrow_drop_down_rounded,
                              size: 18, color: AppColors.primary),
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        onPressed: _loadInstitutionsAnalytics,
                        icon: Icon(Icons.refresh_rounded,
                            size: 20, color: AppColors.primary),
                        tooltip: 'Refresh insights',
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (_isAnalyticsLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          ),
                          SizedBox(width: 10),
                          Text('Loading insights...',
                              style: TextStyle(color: AppColors.textGray)),
                        ],
                      ),
                    )
                  else ...[
                    Builder(builder: (context) {
                      final data = _institutionsAnalytics ?? {};
                      final totals =
                          (data['totals'] as Map?)?.cast<String, dynamic>() ??
                              {};
                      final statuses = (data['institution_statuses'] as Map?)
                              ?.cast<String, dynamic>() ??
                          {};
                      final top =
                          (data['top_institutions'] as List?) ?? const [];

                      String n(dynamic v) => (v == null) ? '0' : v.toString();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Wrap stat cards to prevent overflow
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildStatCard(
                                title: 'Total Requests',
                                value: n(totals['total_requests']),
                                icon: Icons.how_to_reg_rounded,
                                color: AppColors.primary,
                              ),
                              _buildStatCard(
                                title: 'Child Requests',
                                value: n(totals['child_requests']),
                                icon: Icons.child_care_rounded,
                                color: AppColors.success,
                              ),
                              _buildStatCard(
                                title: 'Specialist Requests',
                                value: n(totals['specialist_requests']),
                                icon: Icons.medical_services_rounded,
                                color: AppColors.warning,
                              ),
                              _buildStatCard(
                                title: 'Approved Institutions',
                                value: n(statuses['Approved']),
                                icon: Icons.verified_rounded,
                                color: AppColors.success,
                              ),
                            ],
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Top institutions by demand score',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 8),
                          if (top.isEmpty)
                            Text('No data yet for this period.',
                                style: TextStyle(color: AppColors.textGray))
                          else
                            Column(
                              children: top.take(5).map((e) {
                                final row = (e as Map).cast<String, dynamic>();
                                final metrics = (row['metrics'] as Map?)
                                        ?.cast<String, dynamic>() ??
                                    {};
                                final score =
                                    (row['score'] as num?)?.toDouble() ?? 0;
                                final name =
                                    row['name']?.toString() ?? 'Unknown';
                                return Container(
                                  margin: EdgeInsets.only(bottom: 10),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(14),
                                    border:
                                        Border.all(color: AppColors.accent1),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.trending_up_rounded,
                                            color: AppColors.primary, size: 18),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                  color: AppColors.textDark,
                                                  fontWeight: FontWeight.w700),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Score: ${score.toStringAsFixed(1)} | Requests: ${(metrics['total_requests'] ?? 0)} | Rating: ${(metrics['avg_rating'] ?? 0)}',
                                              style: TextStyle(
                                                  color: AppColors.textGray,
                                                  fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),

            // Advanced Analytics Tabs
            Container(
              margin: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.accent1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _showTopAnalytics = true;
                                _showHistoryAnalytics = false;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                ),
                              ),
                              backgroundColor: _showTopAnalytics
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.leaderboard,
                                  size: 18,
                                  color: _showTopAnalytics
                                      ? AppColors.primary
                                      : AppColors.textLight,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Top Institutions',
                                  style: TextStyle(
                                    color: _showTopAnalytics
                                        ? AppColors.primary
                                        : AppColors.textLight,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _showTopAnalytics = false;
                                _showHistoryAnalytics = true;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              backgroundColor: _showHistoryAnalytics
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timeline,
                                  size: 18,
                                  color: _showHistoryAnalytics
                                      ? AppColors.primary
                                      : AppColors.textLight,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Activity History',
                                  style: TextStyle(
                                    color: _showHistoryAnalytics
                                        ? AppColors.primary
                                        : AppColors.textLight,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Container(
                    padding: EdgeInsets.all(16),
                    constraints: BoxConstraints(
                      minHeight: 400,
                    ),
                    child: _showTopAnalytics
                        ? _buildTopInstitutionsAnalytics()
                        : _buildHistoryAnalytics(),
                  ),
                ],
              ),
            ),

            // Search and Filter Section
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.accent1, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            'Search institutions by name, email, or location...',
                        hintStyle:
                            TextStyle(color: AppColors.textLight, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: AppColors.primaryLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: AppColors.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded,
                                    size: 20, color: AppColors.textLight),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                  _loadInstitutions(page: 1);
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        _loadInstitutions(page: 1);
                      },
                    ),
                  ),

                  SizedBox(height: 16),

                  // Filter Section - Fixed Row overflow
                  Row(
                    children: [
                      Icon(Icons.filter_alt_outlined,
                          size: 20, color: AppColors.primaryLight),
                      SizedBox(width: 8),
                      Text('Filter by:',
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 14)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.accent1, width: 1.5),
                          ),
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            items: _statusOptions.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _statusFilter = value;
                                });
                                _loadInstitutions(page: 1);
                              }
                            },
                            underline: SizedBox(),
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: AppColors.surface,
                            icon: Icon(Icons.arrow_drop_down_rounded,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stats Bar - Fixed overflow
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: AppColors.accent1.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        Icon(Icons.business_rounded,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$_totalRows Institutions',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_statusFilter != 'All')
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_statusFilter).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _getStatusColor(_statusFilter)
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_statusFilter),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            _statusFilter,
                            style: TextStyle(
                              color: _getStatusColor(_statusFilter),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Institutions List
            Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.4,
                maxHeight: isWide ? 600 : 500,
              ),
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading institutions...',
                            style: TextStyle(
                                color: AppColors.textGray, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : _institutions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppColors.accent1,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.business_outlined,
                                  size: 60,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'No institutions found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try adjusting your search or filters',
                                style: TextStyle(
                                    color: AppColors.textLight, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.background,
                          onRefresh: () =>
                              _loadInstitutions(page: _currentPage),
                          child: isWide
                              ? _buildInstitutionsTable()
                              : ListView.separated(
                                  controller: _scrollController,
                                  padding: EdgeInsets.all(20),
                                  itemCount: _institutions.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final institution = _institutions[index];
                                    return _buildInstitutionCard(institution);
                                  },
                                ),
                        ),
            ),

            // Pagination
            if (!isWide && _totalPages > 1) _buildPagination(),
            SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: isWide
          ? null
          : FloatingActionButton(
              onPressed: () => _showInstitutionForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Icon(Icons.add, size: 28),
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return AppColors.warning;
      case 'Approved':
        return AppColors.success;
      case 'Rejected':
        return AppColors.error;
      case 'Suspended':
        return Color(0xFF9C27B0);
      default:
        return AppColors.textLight;
    }
  }

  Widget _buildInstitutionsTable() {
    return Container(
      margin: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.accent1,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.table_chart_rounded,
                    color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Institutions Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list_rounded,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        '$_totalRows Total',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pagination Controls (Top)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              border: Border(
                bottom: BorderSide(color: AppColors.accent1, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rows per page selector
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rows per page:',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _rowsPerPage,
                        items: const [5, 10, 20, 50].map((value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(
                              '$value',
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _rowsPerPage = v;
                          });
                          _loadInstitutions(page: 1);
                        },
                        underline: SizedBox(),
                        icon: Icon(Icons.arrow_drop_down_rounded,
                            color: AppColors.primary, size: 18),
                        borderRadius: BorderRadius.circular(10),
                        dropdownColor: AppColors.surface,
                      ),
                    ],
                  ),
                ),

                // Page info
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Page $_currentPage of $_totalPages',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),

                // Page navigation
                Row(
                  children: [
                    _buildTablePageButton(
                      icon: Icons.first_page_rounded,
                      enabled: _currentPage > 1,
                      onPressed: () => _loadInstitutions(page: 1),
                      tooltip: 'First page',
                    ),
                    SizedBox(width: 4),
                    _buildTablePageButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: _currentPage > 1,
                      onPressed: () =>
                          _loadInstitutions(page: _currentPage - 1),
                      tooltip: 'Previous page',
                    ),
                    SizedBox(width: 4),
                    _buildTablePageButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: _currentPage < _totalPages,
                      onPressed: () =>
                          _loadInstitutions(page: _currentPage + 1),
                      tooltip: 'Next page',
                    ),
                    SizedBox(width: 4),
                    _buildTablePageButton(
                      icon: Icons.last_page_rounded,
                      enabled: _currentPage < _totalPages,
                      onPressed: () => _loadInstitutions(page: _totalPages),
                      tooltip: 'Last page',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Table Content
          Container(
            constraints: BoxConstraints(
              minHeight: 400,
              maxHeight: 600,
            ),
            child: Scrollbar(
              thumbVisibility: true,
              thickness: 6,
              radius: Radius.circular(3),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width * 0.95,
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        cardTheme: CardThemeData(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                          ),
                        ),
                      ),
                      child: DataTable(
                        headingRowColor: MaterialStateColor.resolveWith(
                          (states) => AppColors.primary.withOpacity(0.05),
                        ),
                        headingRowHeight: 56,
                        dataRowHeight: 60,
                        horizontalMargin: 20,
                        columnSpacing: 24,
                        border: TableBorder(
                          horizontalInside: BorderSide(
                            color: AppColors.accent1.withOpacity(0.5),
                            width: 0.5,
                          ),
                          verticalInside: BorderSide(
                            color: AppColors.accent1.withOpacity(0.5),
                            width: 0.5,
                          ),
                          bottom: BorderSide(
                            color: AppColors.accent1,
                            width: 1,
                          ),
                        ),
                        headingTextStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                        dataTextStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                        columns: [
                          DataColumn(
                            label: Row(
                              children: [
                                Icon(Icons.business_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Institution Name'),
                              ],
                            ),
                            numeric: false,
                          ),
                          DataColumn(
                            label: Row(
                              children: [
                                Icon(Icons.circle_rounded,
                                    size: 14, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Status'),
                              ],
                            ),
                            numeric: false,
                          ),
                          DataColumn(
                            label: Row(
                              children: [
                                Icon(Icons.location_city_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Location'),
                              ],
                            ),
                            numeric: false,
                          ),
                          DataColumn(
                            label: Row(
                              children: [
                                Icon(Icons.email_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Contact'),
                              ],
                            ),
                            numeric: false,
                          ),
                          DataColumn(
                            label: Row(
                              children: [
                                Icon(Icons.people_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Managers'),
                              ],
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Row(
                              children: [
                                Icon(Icons.settings_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Actions'),
                              ],
                            ),
                            numeric: false,
                          ),
                        ],
                        rows: _buildTableRows(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Footer with summary
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cream,
              border: Border(
                top: BorderSide(color: AppColors.accent1, width: 1),
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.textLight),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Showing ${_calculateStartRow()}-${_calculateEndRow()} of $_totalRows institutions',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: AppColors.textLight),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Last updated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
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

  int _calculateStartRow() {
    return ((_currentPage - 1) * _rowsPerPage) + 1;
  }

  int _calculateEndRow() {
    final end = _currentPage * _rowsPerPage;
    return end > _totalRows ? _totalRows : end;
  }

  Widget _buildTablePageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: enabled ? AppColors.primary.withOpacity(0.1) : AppColors.accent1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              enabled ? AppColors.primary.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: enabled ? onPressed : null,
        color: enabled ? AppColors.primary : AppColors.textLight,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  List<DataRow> _buildTableRows() {
    return _institutions.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;
      final id = int.tryParse(row['institution_id']?.toString() ?? '') ?? 0;
      final name = row['name']?.toString() ?? '—';
      final status = row['approval_status']?.toString() ?? '—';
      final city = row['city']?.toString() ?? '—';
      final region = row['region']?.toString() ?? '';
      final email = row['contact_email']?.toString() ?? '—';
      final phone = row['contact_phone']?.toString() ?? '—';
      final managers = (row['managers'] as List?) ?? const [];
      final createdDate = row['created_at']?.toString().split('T')[0] ?? '—';

      return DataRow(
        cells: [
          DataCell(
            Container(
              padding: EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ID: $id • Created: $createdDate',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          DataCell(
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getStatusColor(status).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          DataCell(
            Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (city != '—') ...[
                    Text(
                      city,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (region.isNotEmpty)
                      Text(
                        region,
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ] else
                    Text(
                      'N/A',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
          DataCell(
            Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.email_rounded,
                          size: 12, color: AppColors.textLight),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded,
                          size: 12, color: AppColors.textLight),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          phone != '—' ? phone : 'No phone',
                          style: TextStyle(
                            color: phone != '—'
                                ? AppColors.textDark
                                : AppColors.textLight,
                            fontSize: 12,
                            fontStyle: phone == '—' ? FontStyle.italic : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          DataCell(
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: managers.isNotEmpty
                    ? AppColors.primary.withOpacity(0.08)
                    : AppColors.accent1,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    managers.isNotEmpty
                        ? Icons.people_alt_rounded
                        : Icons.person_off_rounded,
                    size: 16,
                    color: managers.isNotEmpty
                        ? AppColors.primary
                        : AppColors.textLight,
                  ),
                  SizedBox(width: 6),
                  Text(
                    managers.isNotEmpty ? '${managers.length}' : '0',
                    style: TextStyle(
                      color: managers.isNotEmpty
                          ? AppColors.primary
                          : AppColors.textLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          DataCell(
            Container(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View Button
                    _buildTableActionButton(
                      icon: Icons.visibility_rounded,
                      color: AppColors.primary,
                      tooltip: 'View details',
                      onPressed: () => _showInstitutionDetails(row),
                    ),

                    // Edit Button
                    _buildTableActionButton(
                      icon: Icons.edit_rounded,
                      color: AppColors.warning,
                      tooltip: 'Edit institution',
                      onPressed: () => _showInstitutionForm(institution: row),
                    ),

                    // Status-specific buttons
                    if (status == 'Pending') ...[
                      _buildTableActionButton(
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        tooltip: 'Approve institution',
                        onPressed: () => _approveInstitution(id),
                      ),
                      _buildTableActionButton(
                        icon: Icons.cancel_rounded,
                        color: AppColors.error,
                        tooltip: 'Reject institution',
                        onPressed: () => _rejectInstitution(id),
                      ),
                    ] else if (status == 'Approved') ...[
                      _buildTableActionButton(
                        icon: Icons.pause_circle_rounded,
                        color: Color(0xFF9C27B0),
                        tooltip: 'Suspend institution',
                        onPressed: () => _suspendInstitution(id),
                      ),
                      _buildTableActionButton(
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        tooltip: 'Already approved',
                        onPressed: null,
                        enabled: false,
                      ),
                    ] else if (status == 'Rejected') ...[
                      _buildTableActionButton(
                        icon: Icons.do_not_disturb_rounded,
                        color: AppColors.error,
                        tooltip: 'Rejected',
                        onPressed: null,
                        enabled: false,
                      ),
                    ] else if (status == 'Suspended') ...[
                      _buildTableActionButton(
                        icon: Icons.pause_circle_filled_rounded,
                        color: Color(0xFF9C27B0),
                        tooltip: 'Suspended',
                        onPressed: null,
                        enabled: false,
                      ),
                    ],

                    // Archive Button
                    _buildTableActionButton(
                      icon: Icons.archive_rounded,
                      color: AppColors.error,
                      tooltip: 'Archive institution',
                      onPressed: () => _archiveInstitution(id, name),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildTableActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return Container(
      width: 32,
      height: 32,
      margin: EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: enabled ? color.withOpacity(0.1) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled ? color.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: enabled ? color : color.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstitutionCard(Map<String, dynamic> institution) {
    final id =
        int.tryParse(institution['institution_id']?.toString() ?? '') ?? 0;
    final name = institution['name']?.toString() ?? 'Unnamed Institution';
    final status = institution['approval_status']?.toString() ?? 'Pending';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.accent1, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 14, color: AppColors.textLight),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Registered: ${institution['created_at']?.split('T')[0] ?? 'N/A'}',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textLight),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Divider(height: 24, color: AppColors.accent1),

            // Contact Information
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: Icons.email_rounded,
                  title: 'Email',
                  value: institution['contact_email'] ?? 'N/A',
                  iconColor: AppColors.primary,
                ),
                SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.phone_rounded,
                  title: 'Phone',
                  value: institution['contact_phone'] ?? 'N/A',
                  iconColor: AppColors.success,
                ),
                SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.location_on_rounded,
                  title: 'Location',
                  value:
                      '${institution['city'] ?? 'N/A'} - ${institution['region'] ?? 'N/A'}',
                  iconColor: AppColors.warning,
                ),
              ],
            ),

            // Managers Section
            if (institution['managers'] != null &&
                institution['managers'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 24, color: AppColors.accent1),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'MANAGERS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...institution['managers'].map<Widget>((manager) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent1),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Icon(Icons.person_rounded,
                                size: 20, color: AppColors.primary),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  manager['full_name'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  manager['email'] ?? 'No email',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textLight),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),

            // Action Buttons
            SizedBox(height: 20),
            if (status == 'Pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectInstitution(id),
                      icon: Icon(Icons.close_rounded, size: 18),
                      label: Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error, width: 1.5),
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
                      onPressed: () => _approveInstitution(id),
                      icon: Icon(Icons.check_rounded, size: 18),
                      label: Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.textWhite,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),

            if (status == 'Approved')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _suspendInstitution(id),
                      icon: Icon(Icons.pause_circle_outline_rounded, size: 18),
                      label: Text('Suspend'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: BorderSide(color: AppColors.warning, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.accent1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    _currentPage > 1 ? AppColors.accent1 : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.chevron_left_rounded,
                    color: _currentPage > 1
                        ? AppColors.primary
                        : AppColors.textLight),
                onPressed: _currentPage > 1
                    ? () => _loadInstitutions(page: _currentPage - 1)
                    : null,
              ),
            ),
            SizedBox(width: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Page $_currentPage of $_totalPages',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                color: _currentPage < _totalPages
                    ? AppColors.accent1
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    color: _currentPage < _totalPages
                        ? AppColors.primary
                        : AppColors.textLight),
                onPressed: _currentPage < _totalPages
                    ? () => _loadInstitutions(page: _currentPage + 1)
                    : null,
              ),
            ),
          ],
        ));
  }
}
