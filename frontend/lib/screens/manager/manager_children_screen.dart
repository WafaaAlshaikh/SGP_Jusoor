// screens/manager/manager_children_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/screens/manager/child_advanced_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_colors.dart';
import '../../services/manager_service.dart';
import 'child_team_room_screen.dart';

class ManagerChildrenScreen extends StatefulWidget {
  const ManagerChildrenScreen({super.key});

  @override
  State<ManagerChildrenScreen> createState() => _ManagerChildrenScreenState();
}

class _ManagerChildrenScreenState extends State<ManagerChildrenScreen> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  late TabController _tabController;
  List<dynamic> _children = [];
  List<dynamic> _pendingRequests = [];
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  bool _isLoadingRequests = true;
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedGender = 'All';
  bool _isMounted = false;
  Timer? _searchTimer;

  final List<String> _statusOptions = ['All', 'Approved', 'Pending', 'Rejected'];
  final List<String> _genderOptions = ['All', 'Male', 'Female'];

  // ألوان للبطاقات
  final List<Color> _cardColors = [
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E8),
    Color(0xFFFFF3E0),
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
    Color(0xFFE0F2F1),
  ];

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _isMounted = false;
    _searchTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        _loadChildren(),
        _loadPendingRequests(),
        _loadStatistics(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
      if (_isMounted) {
        _showErrorSnackBar('Failed to load data');
      }
    }
  }

  Future<void> _loadChildren() async {
    try {
      if (_isMounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final response = await ManagerService.getInstitutionChildren(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        registrationStatus: _selectedStatus == 'All' ? null : _selectedStatus,
        gender: _selectedGender == 'All' ? null : _selectedGender,
      );

      if (_isMounted && response['success'] == true) {
        setState(() {
          _children = response['data'] ?? [];
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load children');
      }
    } catch (e) {
      print('Error loading children: $e');
      if (_isMounted) {
        _showErrorSnackBar('Failed to load children');
      }
    } finally {
      if (_isMounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final response = await ManagerService.getPendingRegistrationRequests();
      
      if (_isMounted && response['success'] == true) {
        setState(() {
          _pendingRequests = response['data'] ?? [];
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load requests');
      }
    } catch (e) {
      print('Error loading requests: $e');
      if (_isMounted) {
        _showErrorSnackBar('Failed to load registration requests');
      }
    } finally {
      if (_isMounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final response = await ManagerService.getChildrenStatistics();
      
      if (_isMounted && response['success'] == true) {
        setState(() {
          _statistics = response['data'];
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _onSearchChanged(String value) {
    if (!_isMounted) return;
    
    setState(() {
      _searchQuery = value;
    });
    
    _searchTimer?.cancel();
    _searchTimer = Timer(Duration(milliseconds: 500), () {
      if (_isMounted && _searchQuery == value) {
        _loadChildren();
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (!_isMounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!_isMounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _approveRequest(int requestId, String childName) async {
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => _buildApproveDialog(childName),
      );

      if (result != null && _isMounted) {
        final response = await ManagerService.approveRegistrationRequest(requestId, notes: result.isEmpty ? null : result);
        
        if (response['success'] == true) {
          _showSuccessSnackBar('تم الموافقة على الطلب بنجاح');
          await _loadData();
        } else {
          throw Exception(response['message'] ?? 'Failed to approve request');
        }
      }
    } catch (e) {
      print('Error approving request: $e');
      if (_isMounted) {
        _showErrorSnackBar('فشل في الموافقة على الطلب');
      }
    }
  }

  Future<void> _rejectRequest(int requestId, String childName) async {
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => _buildRejectDialog(childName),
      );

      if (reason != null && reason.isNotEmpty && _isMounted) {
        final response = await ManagerService.rejectRegistrationRequest(requestId, reason: reason);
        
        if (response['success'] == true) {
          _showSuccessSnackBar('تم رفض الطلب بنجاح');
          await _loadData();
        } else {
          throw Exception(response['message'] ?? 'Failed to reject request');
        }
      }
    } catch (e) {
      print('Error rejecting request: $e');
      if (_isMounted) {
        _showErrorSnackBar('فشل في رفض الطلب');
      }
    }
  }

  Widget _buildApproveDialog(String childName) {
    String notes = '';
    return AlertDialog(
      title: Text('موافقة على التسجيل'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('هل تريد الموافقة على تسجيل الطفل $childName؟'),
          SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'ملاحظات (اختياري)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => notes = value,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: TextStyle(color: AppColors.textGray)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, notes),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          child: Text('موافقة'),
        ),
      ],
    );
  }

  Widget _buildRejectDialog(String childName) {
    String reason = '';
    return AlertDialog(
      title: Text('رفض التسجيل'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('يرجى كتابة سبب رفض تسجيل الطفل $childName:'),
          SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'السبب *',
              border: OutlineInputBorder(),
              errorText: reason.isEmpty ? 'السبب مطلوب' : null,
            ),
            onChanged: (value) => reason = value,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: TextStyle(color: AppColors.textGray)),
        ),
        ElevatedButton(
          onPressed: reason.isEmpty ? null : () => Navigator.pop(context, reason),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: Text('رفض'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isWeb = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Statistics
            _buildStatisticsHeader(isWeb),
            
            // Tabs
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textGray,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.child_care, size: 20),
                            SizedBox(width: 8),
                            Text('الأطفال المسجلين'),
                            if (_children.isNotEmpty)
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _children.length.toString(),
                                  style: TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pending_actions, size: 20),
                            SizedBox(width: 8),
                            Text('طلبات التسجيل'),
                            if (_pendingRequests.isNotEmpty)
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _pendingRequests.length.toString(),
                                  style: TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tab Content
            Expanded(
              child: Container(
                color: AppColors.background,
                child: TabBarView(
                  controller: _tabController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    // Registered Children Tab
                    KeepAliveWrapper(child: _buildChildrenTab(isWeb)),
                    
                    // Pending Requests Tab
                    KeepAliveWrapper(child: _buildPendingRequestsTab(isWeb)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsHeader(bool isWeb) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textWhite.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.child_care, color: AppColors.textWhite, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة الأطفال',
                      style: TextStyle(
                        fontSize: isWeb ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'إدارة الأطفال المسجلين ومراجعة طلبات التسجيل',
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 14,
                        color: AppColors.textWhite.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          if (_statistics != null) _buildStatisticsGrid(isWeb),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(bool isWeb) {
    final stats = _statistics!['statistics'];
    final items = [
      {
        'label': 'إجمالي الأطفال',
        'value': stats['total_children']?.toString() ?? '0',
        'color': AppColors.info,
        'icon': Icons.child_care,
      },
      {
        'label': 'تمت الموافقة',
        'value': stats['by_registration_status']?['Approved']?.toString() ?? '0',
        'color': AppColors.success,
        'icon': Icons.check_circle,
      },
      {
        'label': 'طلبات قيد الانتظار',
        'value': stats['pending_registration_requests']?.toString() ?? '0',
        'color': AppColors.warning,
        'icon': Icons.pending_actions,
      },
      {
        'label': 'الجلسات الشهرية',
        'value': stats['monthly_sessions']?.toString() ?? '0',
        'color': AppColors.primary,
        'icon': Icons.event_available,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWeb ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isWeb ? 1.8 : 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildStatCard(item, isWeb);
      },
    );
  }

  Widget _buildStatCard(Map<String, dynamic> item, bool isWeb) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textWhite.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item['color'].withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item['icon'], size: isWeb ? 28 : 24, color: item['color']),
            ),
            SizedBox(height: 12),
            Text(
              item['value'],
              style: TextStyle(
                fontSize: isWeb ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 6),
            Text(
              item['label'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isWeb ? 14 : 12,
                color: AppColors.textGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildrenTab(bool isWeb) {
    return Column(
      children: [
        // Search and Filters
        _buildSearchFilters(isWeb),
        
        // Children List
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _children.isEmpty
                  ? _buildEmptyState(
                      'لا يوجد أطفال مسجلين', 
                      Icons.child_care_outlined,
                      'سيظهر الأطفال المسجلون هنا عند توفرهم',
                      'إضافة طفل جديد'
                    )
                  : _buildChildrenGrid(isWeb),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'جاري تحميل بيانات الأطفال...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilters(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث باسم الطفل أو المعرف...',
                prefixIcon: Icon(Icons.search, color: AppColors.primary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          SizedBox(height: 16),
          
          // Filters Row
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'الحالة',
                  _selectedStatus,
                  _statusOptions,
                  (value) {
                    if (!_isMounted) return;
                    setState(() {
                      _selectedStatus = value!;
                    });
                    _loadChildren();
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'الجنس',
                  _selectedGender,
                  _genderOptions,
                  (value) {
                    if (!_isMounted) return;
                    setState(() {
                      _selectedGender = value!;
                    });
                    _loadChildren();
                  },
                ),
              ),
              SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _loadChildren,
                  icon: Icon(Icons.refresh, color: AppColors.textWhite),
                  tooltip: 'تحديث القائمة',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent3.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Container(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_drop_down, color: AppColors.primary),
              ),
              iconSize: 24,
              elevation: 8,
              dropdownColor: AppColors.background,
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
              ),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      option,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildrenGrid(bool isWeb) {
    final crossAxisCount = isWeb ? 
        (MediaQuery.of(context).size.width ~/ 300) : 
        (MediaQuery.of(context).size.width ~/ 180);
        
    return Padding(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount < 2 ? 2 : crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        itemCount: _children.length,
        itemBuilder: (context, index) {
          final child = _children[index];
          return _buildChildCard(child, index);
        },
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child, int index) {
    final cardColor = _cardColors[index % _cardColors.length];
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cardColor, cardColor.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header with Status
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(child['registration_status'] ?? 'Pending').withOpacity(0.9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getStatusText(child['registration_status'] ?? 'Pending'),
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (child['child_identifier'] != null)
                    Text(
                      '#${child['child_identifier']}',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            
            // Child Info
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: child['photo'] != null && child['photo'].isNotEmpty
                            ? Image.network(
                                child['photo'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultAvatar();
                                },
                              )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      child['full_name'] ?? 'غير معروف',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'العمر: ${child['age'] ?? 'غير محدد'}',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _getGenderText(child['gender']),
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Diagnosis and Action
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.textWhite.withOpacity(0.8),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  if (child['diagnosis'] != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        child['diagnosis']['name'],
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => _showChildOptions(child),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textWhite,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size(0, 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'عرض الخيارات',
                      style: TextStyle(fontSize: 10),
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

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.child_care, size: 30, color: AppColors.textWhite),
    );
  }

  Widget _buildPendingRequestsTab(bool isWeb) {
    return Column(
      children: [
        // Requests Header
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pending_actions, color: AppColors.warning, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلبات التسجيل المعلقة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'مراجعة واتخاذ قرار بشأن طلبات التسجيل الجديدة',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _loadPendingRequests,
                  icon: Icon(Icons.refresh, color: AppColors.textWhite),
                  tooltip: 'تحديث الطلبات',
                ),
              ),
            ],
          ),
        ),
        
        // Requests List
        Expanded(
          child: _isLoadingRequests
              ? _buildLoadingState()
              : _pendingRequests.isEmpty
                  ? _buildEmptyState(
                      'لا توجد طلبات معلقة', 
                      Icons.pending_actions_outlined,
                      'سيظهر هنا طلبات التسجيل الجديدة عند توفرها',
                      'تحديث الطلبات'
                    )
                  : _buildPendingRequestsList(isWeb),
        ),
      ],
    );
  }

  Widget _buildPendingRequestsList(bool isWeb) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        return _buildRequestCard(request, index, isWeb);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, int index, bool isWeb) {
    final child = request['child'];
    final parent = request['parent'];
    final cardColor = _cardColors[index % _cardColors.length];
    
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cardColor, cardColor.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.textWhite.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_add_alt_1, color: AppColors.textWhite, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'طلب تسجيل جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'قيد الانتظار',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              
              // Child and Parent Info in two columns for web
              isWeb ? _buildWebRequestInfo(child, parent) : _buildMobileRequestInfo(child, parent),
              
              SizedBox(height: 20),
              
              // Request Date and Actions
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: AppColors.textGray),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'تاريخ الطلب: ${_formatDate(request['requested_at'])}',
                            style: TextStyle(fontSize: 12, color: AppColors.textGray),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Action Buttons - استخدم Wrap بدل Row للشاشات الصغيرة
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 300) {
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildApproveButton(request, child),
                            _buildRejectButton(request, child),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            _buildApproveButton(request, child),
                            SizedBox(width: 8),
                            _buildRejectButton(request, child),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApproveButton(Map<String, dynamic> request, Map<String, dynamic> child) {
    return ElevatedButton.icon(
      onPressed: () => _approveRequest(request['request_id'], child['full_name']),
      icon: Icon(Icons.check, size: 14),
      label: Text('موافقة'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: AppColors.textWhite,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildRejectButton(Map<String, dynamic> request, Map<String, dynamic> child) {
    return OutlinedButton.icon(
      onPressed: () => _rejectRequest(request['request_id'], child['full_name']),
      icon: Icon(Icons.close, size: 14),
      label: Text('رفض'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildWebRequestInfo(Map<String, dynamic> child, Map<String, dynamic> parent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildInfoSection(
            'معلومات الطفل',
            Icons.child_care,
            [
              _buildInfoRow('الاسم', child['full_name'] ?? 'غير معروف'),
              _buildInfoRow('العمر', child['age']?.toString() ?? 'غير محدد'),
              _buildInfoRow('الجنس', _getGenderText(child['gender'])),
              if (child['diagnosis'] != null)
                _buildInfoRow('التشخيص', child['diagnosis']['name']),
            ],
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildInfoSection(
            'معلومات ولي الأمر',
            Icons.person,
            [
              _buildInfoRow('الاسم', parent['name'] ?? 'غير معروف'),
              _buildInfoRow('البريد الإلكتروني', parent['email'] ?? 'غير محدد'),
              _buildInfoRow('رقم الهاتف', parent['phone'] ?? 'غير محدد'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileRequestInfo(Map<String, dynamic> child, Map<String, dynamic> parent) {
    return Column(
      children: [
        _buildInfoSection(
          'معلومات الطفل',
          Icons.child_care,
          [
            _buildInfoRow('الاسم', child['full_name'] ?? 'غير معروف'),
            _buildInfoRow('العمر', child['age']?.toString() ?? 'غير محدد'),
            _buildInfoRow('الجنس', _getGenderText(child['gender'])),
            if (child['diagnosis'] != null)
              _buildInfoRow('التشخيص', child['diagnosis']['name']),
          ],
        ),
        SizedBox(height: 12),
        _buildInfoSection(
          'معلومات ولي الأمر',
          Icons.person,
          [
            _buildInfoRow('الاسم', parent['name'] ?? 'غير معروف'),
            _buildInfoRow('البريد الإلكتروني', parent['email'] ?? 'غير محدد'),
            _buildInfoRow('رقم الهاتف', parent['phone'] ?? 'غير محدد'),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.textWhite.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent3.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8),
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

  Widget _buildEmptyState(String title, IconData icon, String subtitle, String actionText) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppColors.textGray.withOpacity(0.5)),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textGray,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: Icon(Icons.refresh),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textWhite,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChildOptions(Map<String, dynamic> child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.textWhite.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: child['photo'] != null && child['photo'].isNotEmpty
                          ? CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(child['photo']),
                            )
                          : Icon(Icons.child_care, color: AppColors.textWhite, size: 30),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child['full_name'] ?? 'غير معروف',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'إدارة معلومات الطفل',
                          style: TextStyle(
                            color: AppColors.textWhite.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textWhite, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Options Grid
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildOptionCard(
                      Icons.analytics,
                      'التفاصيل المتقدمة',
                      'عرض الإحصائيات المتقدمة وتحليل تقدم الطفل',
                      AppColors.info,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChildAdvancedDetailsScreen(
                              childId: child['id'],
                              childName: child['full_name'],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    _buildOptionCard(
                      Icons.group,
                      'غرفة الفريق',
                      'عرض الفريق العلاجي والنشاطات والجلسات',
                      AppColors.primary,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChildTeamRoomScreen(
                              childId: child['id'],
                              childName: child['full_name'],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    _buildOptionCard(
                      Icons.info,
                      'المعلومات الأساسية',
                      'عرض البيانات الشخصية والتشخيص والمعلومات',
                      AppColors.success,
                      () {
                        Navigator.pop(context);
                        _showBasicChildDetails(child);
                      },
                    ),
                    
                    _buildOptionCard(
                      Icons.assignment,
                      'التقارير',
                      'عرض التقارير والتقييمات',
                      AppColors.warning,
                      () {
                        Navigator.pop(context);
                        _showComingSoon();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBasicChildDetails(Map<String, dynamic> child) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'المعلومات الأساسية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailItem('الاسم الكامل', child['full_name']),
                    _buildDetailItem('العمر', child['age']?.toString()),
                    _buildDetailItem('الجنس', _getGenderText(child['gender'])),
                    _buildDetailItem('حالة التسجيل', _getStatusText(child['registration_status'])),
                    
                    if (child['diagnosis'] != null) 
                      _buildDetailItem('التشخيص', child['diagnosis']['name']),
                    
                    if (child['parent'] != null) ...[
                      SizedBox(height: 16),
                      Text(
                        'معلومات ولي الأمر:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 16,
                        ),
                      ),
                      _buildDetailItem('الاسم', child['parent']['name']),
                      _buildDetailItem('البريد الإلكتروني', child['parent']['email']),
                      _buildDetailItem('رقم الهاتف', child['parent']['phone']),
                    ],
                    
                    if (child['city'] != null) 
                      _buildDetailItem('المدينة', child['city']),
                    
                    if (child['school_info'] != null) 
                      _buildDetailItem('معلومات المدرسة', child['school_info']),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textWhite,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('إغلاق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value ?? 'غير محدد',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('هذه الميزة قيد التطوير وسيتم إضافتها قريباً'),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  String _formatDate(String? dateString) {
    if (dateString == null) return 'غير معروف';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'تاريخ غير صالح';
    }
  }

  String _getGenderText(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'male':
        return 'ذكر';
      case 'female':
        return 'أنثى';
      default:
        return 'غير محدد';
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'تمت الموافقة';
      case 'pending':
        return 'قيد الانتظار';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textGray;
    }
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}