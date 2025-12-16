import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import 'sessions_tab.dart';
import '../screens/booking_screen.dart';
import '../services/payment_service.dart';
import 'reports_tab.dart';
import '../theme/app_colors.dart';

class ChildTabs extends StatefulWidget {
  final Child child;
  const ChildTabs({super.key, required this.child});

  @override
  State<ChildTabs> createState() => _ChildTabsState();
}

class _ChildTabsState extends State<ChildTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _cachedToken;
  bool _isInitialized = false;
  int _selectedTabIndex = 0; // تتبع التبويب المختار

  @override
  void initState() {
    super.initState();
    print('🚀 ChildTabs initState for ${widget.child.fullName}');
    
    // ⚠️ تغيير length من 4 إلى 3 (حذف Payments مؤقتاً)
    _tabController = TabController(length: 3, vsync: this);
    
    // استماع لتغيير التبويب
    _tabController.addListener(_handleTabChange);
    
    Future.delayed(Duration.zero, _initializeData);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    }
  }

  Future<void> _initializeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('token') ?? '';
    } catch (e) {
      print('❌ Error loading token: $e');
      _cachedToken = '';
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    print('🗑️ ChildTabs dispose for ${widget.child.fullName}');
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🔨 ChildTabs build for ${widget.child.fullName} (Tab: $_selectedTabIndex)');
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildElegantHeader(),

          // Tab Bar
          _buildTabBar(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildSessionsTab(),
                _buildReportsTab(),
                // ⚠️ تمت إزالة Payments Tab مؤقتاً
                // _buildPaymentsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 1 ? _buildLuxuryFAB() : null,
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textGray,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.person_outline, size: 18),
            text: 'Profile',
          ),
          Tab(
            icon: Icon(Icons.event_note_outlined, size: 18),
            text: 'Sessions',
          ),
          Tab(
            icon: Icon(Icons.assessment_outlined, size: 18),
            text: 'Reports',
          ),
          // ⚠️ تمت إزالة Payments مؤقتاً
          // Tab(
          //   icon: Icon(Icons.payment_outlined, size: 18),
          //   text: 'Payments',
          // ),
        ],
      ),
    );
  }

  Widget _buildElegantHeader() {
    return Container(
      height: 140, // تصغير الـ header
      decoration: BoxDecoration(
        color: AppColors.primary, // لون واحد بدل gradient
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.child.currentInstitutionId != null ? 'Registered' : 'Not Registered',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Avatar بسيط
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.child.fullName.isNotEmpty 
                          ? widget.child.fullName[0].toUpperCase() 
                          : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.child.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (widget.child.age != null)
                          Text(
                            '${widget.child.age} years old',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
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
      ),
    );
  }

  Widget _buildLuxuryFAB() {
    return FloatingActionButton(
      onPressed: () {
        if (widget.child.currentInstitutionId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BookingScreen(
                child: widget.child,
                institutionId: widget.child.currentInstitutionId!,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Child must be registered to book sessions'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      },
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            'Personal Information',
            [
              _buildInfoItem('Date of Birth', _formatDate(widget.child.dateOfBirth)),
              _buildInfoItem('Gender', _formatGender(widget.child.gender)),
              _buildInfoItem('Age', widget.child.age?.toString() ?? 'N/A'),
              if (widget.child.condition != null)
                _buildInfoItem('Condition', widget.child.condition!),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Registration Status',
            [
              ListTile(
                leading: Icon(
                  widget.child.currentInstitutionId != null
                      ? Icons.check_circle
                      : Icons.pending,
                  color: widget.child.currentInstitutionId != null
                      ? AppColors.success
                      : AppColors.warning,
                ),
                title: Text(
                  widget.child.currentInstitutionId != null
                      ? 'Registered'
                      : 'Not Registered',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  widget.child.currentInstitutionId != null
                      ? widget.child.currentInstitutionName ?? 'Registered at institution'
                      : 'Child needs to be registered to book sessions',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not specified';
    try {
      if (dateString.contains('T')) {
        final dateTime = DateTime.parse(dateString);
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
      return dateString;
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatGender(String? gender) {
    if (gender == null || gender.isEmpty) return 'Not specified';
    switch (gender.toLowerCase()) {
      case 'male':
      case 'm':
        return 'Male';
      case 'female':
      case 'f':
        return 'Female';
      default:
        return gender;
    }
  }

  Widget _buildSessionsTab() {
    if (!_isInitialized) {
      return _buildLoadingState('Initializing...');
    }
    
    if (_cachedToken == null || _cachedToken!.isEmpty) {
      return _buildErrorState('Authentication required', _initializeData);
    }
    
    return SessionsTab(
      child: widget.child, 
      token: _cachedToken!,
    );
  }

  Widget _buildReportsTab() {
    return ReportsTab(
      child: widget.child,
    );
  }

  // ⚠️ تم تعليق Payments Tab مؤقتاً
  /*
  Widget _buildPaymentsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: AppColors.textGray),
          const SizedBox(height: 16),
          Text(
            'Payments Tab Under Maintenance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This feature will be available soon',
            style: TextStyle(
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }
  */

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: AppColors.error,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}