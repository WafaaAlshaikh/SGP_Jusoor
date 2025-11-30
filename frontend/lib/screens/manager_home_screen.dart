// screens/manager/manager_home_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/manager/manager_children_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import 'dart:convert';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  late TabController _tabController;
  Map<String, dynamic>? userData;
  Map<String, dynamic>? institutionData;
  int _currentIndex = 0;
  bool _isSidebarOpen = true;
  bool _isMounted = false;

  @override
  bool get wantKeepAlive => true;

  final List<Map<String, dynamic>> myTabs = [
    {'icon': Icons.person, 'label': 'Profile'},
    {'icon': Icons.business, 'label': 'Institution'},
    {'icon': Icons.people, 'label': 'Specialists'},
    {'icon': Icons.analytics, 'label': 'Analytics'},
    {'icon': Icons.medical_services, 'label': 'Services'},
    {'icon': Icons.chat, 'label': 'Chat'},
    {'icon': Icons.group, 'label': 'Community'},
    {'icon': Icons.volunteer_activism, 'label': 'Donors'},
    {'icon': Icons.child_care, 'label': 'Children'},
    {'icon': Icons.feedback, 'label': 'Feedback'},
  ];

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _tabController = TabController(length: myTabs.length, vsync: this);
    _loadUserData();
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_isMounted) return;
    
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentIndex = _tabController.index;
      });
    }
  }

  Widget _buildTabContent(int index) {
    // بناء التاب حسب الفهرس بشكل مباشر
    switch (index) {
      case 0: return _buildManagerInfoTab();
      case 1: return _buildInstitutionTab();
      case 2: return _buildSpecialistsTab();
      case 3: return _buildStatisticsTab();
      case 4: return _buildServicesTab();
      case 5: return _buildChatTab();
      case 6: return _buildCommunityTab();
      case 7: return _buildDonorsTab();
      case 8: return ManagerChildrenScreen();
      case 9: return _buildFeedbackTab();
      default: return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildAnimatedSidebar(),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TabBarView(
                controller: _tabController,
                physics: NeverScrollableScrollPhysics(),
                children: List.generate(myTabs.length, (index) {
                  return _buildTabContent(index);
                }),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // إصلاح دالة تحميل البيانات
  void _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_isMounted) {
        setState(() {
          userData = {
            'name': prefs.getString('user_name'),
            'email': prefs.getString('user_email'),
            'role': prefs.getString('user_role'),
          };
          
          final institutionJson = prefs.getString('institution_data');
          if (institutionJson != null) {
            institutionData = jsonDecode(institutionJson);
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: Icon(
          _isSidebarOpen ? Icons.menu_open : Icons.menu,
          color: AppColors.textWhite,
          size: 24,
        ),
        onPressed: _toggleSidebar,
      ),
      title: Text(
        'Manager Dashboard',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
        ),
      ),
      backgroundColor: AppColors.primary,
      elevation: 0,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        onTap: (index) {
          if (_isMounted) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        tabs: myTabs.map((tab) => Tab(
          icon: Icon(tab['icon']),
          text: tab['label'],
        )).toList(),
      ),
    );
  }

  void _toggleSidebar() {
    if (_isMounted) {
      setState(() {
        _isSidebarOpen = !_isSidebarOpen;
      });
    }
  }

  Widget _buildAnimatedSidebar() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: _isSidebarOpen ? 280 : 0,
      child: _isSidebarOpen ? _buildSidebar() : SizedBox.shrink(),
    );
  }

  Widget _buildSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: AppColors.surface.withOpacity(0.2),
                      child: Icon(Icons.person, size: 40, color: AppColors.textWhite),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: Icon(Icons.check, size: 12, color: AppColors.textWhite),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  userData?['name']?.toString() ?? 'Manager Name',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  userData?['email']?.toString() ?? 'email@example.com',
                  style: TextStyle(
                    color: AppColors.textWhite.withOpacity(0.8),
                  ),
                ),
                SizedBox(height: 16),
                if (institutionData?['name'] != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business, size: 14, color: AppColors.textWhite),
                        SizedBox(width: 6),
                        Text(
                          institutionData!['name']!.toString(),
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Quick Stats
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent3.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSidebarStatItem('Children', '87'),
                    _buildSidebarStatItem('Team', '15'),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSidebarStatItem('Sessions', '24'),
                    _buildSidebarStatItem('Rating', '4.8'),
                  ],
                ),
              ],
            ),
          ),
          
          // Navigation Menu
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildSidebarMenuItem(Icons.person, 'Profile', 0, 0),
                _buildSidebarMenuItem(Icons.business, 'Institution', 1, 0),
                _buildSidebarMenuItem(Icons.people, 'Specialists', 2, 0),
                _buildSidebarMenuItem(Icons.analytics, 'Analytics', 3, 0),
                _buildSidebarMenuItem(Icons.medical_services, 'Services', 4, 0),
                _buildSidebarMenuItem(Icons.chat, 'Chat', 5, 3),
                _buildSidebarMenuItem(Icons.group, 'Community', 6, 5),
                _buildSidebarMenuItem(Icons.volunteer_activism, 'Donors', 7, 0),
                _buildSidebarMenuItem(Icons.child_care, 'Children', 8, 12),
                _buildSidebarMenuItem(Icons.feedback, 'Feedback', 9, 7),
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.accent3.withOpacity(0.3)),
              ),
            ),
            child: Column(
              children: [
                _buildSidebarAction('Settings', Icons.settings, () {}),
                _buildSidebarAction('Help & Support', Icons.help, () {}),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.logout, size: 16),
                    label: Text('Logout'),
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error.withOpacity(0.1),
                      foregroundColor: AppColors.error,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
  }

  Widget _buildSidebarStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textGray,
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarMenuItem(IconData icon, String label, int index, int badgeCount) {
    final isSelected = _currentIndex == index;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            _tabController.animateTo(index);
            if (_isMounted) {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? AppColors.textWhite : AppColors.primary,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textDark,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount.toString(),
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
        ),
      ),
    );
  }

  Widget _buildSidebarAction(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: AppColors.textGray),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textGray,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(
        bottom: 16,
        right: _isSidebarOpen ? 296 : 16,
      ),
      child: FloatingActionButton(
        onPressed: _showQuickActions,
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: AppColors.textWhite),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ===== TAB CONTENT WIDGETS =====
  Widget _buildManagerInfoTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.surface.withOpacity(0.2),
                        child: Icon(Icons.person, size: 40, color: AppColors.textWhite),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: Icon(Icons.check, size: 12, color: AppColors.textWhite),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    userData?['name']?.toString() ?? 'Manager Name',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    userData?['email']?.toString() ?? 'email@example.com',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textWhite.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Professional Manager',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Institution',
                  institutionData?['name']?.toString() ?? 'Not assigned',
                  Icons.business,
                  AppColors.primaryLight,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Status',
                  'Active',
                  Icons.verified,
                  AppColors.success,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildActionChip('Edit Profile', Icons.edit, _editProfile),
                    _buildActionChip('Settings', Icons.settings, () {}),
                    _buildActionChip('Security', Icons.security, () {}),
                    _buildActionChip('Help', Icons.help, () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent1, AppColors.accent2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.business, size: 30, color: AppColors.primary),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              institutionData?['name']?.toString() ?? 'Institution Name',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Since ${institutionData?['established_year']?.toString() ?? 'N/A'}',
                              style: TextStyle(
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildStatusBadge(),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          
          _buildInfoSection(),
          SizedBox(height: 24),
          
          _buildInstitutionActions(),
        ],
      ),
    );
  }

  Widget _buildSpecialistsTab() {
    return Column(
      children: [
        _buildSectionHeader(
          'Specialists Team',
          'Manage your professional team',
          Icons.people,
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: 6,
            itemBuilder: (context, index) {
              final specialists = [
                {'name': 'Dr. Sarah Ahmed', 'specialty': 'Speech Therapy', 'status': 'Active', 'rating': 4.8},
                {'name': 'Dr. Mohammed Ali', 'specialty': 'Occupational Therapy', 'status': 'Active', 'rating': 4.9},
                {'name': 'Dr. Fatima Hassan', 'specialty': 'Behavioral Therapy', 'status': 'Busy', 'rating': 4.7},
                {'name': 'Dr. Khalid Omar', 'specialty': 'Psychological Counseling', 'status': 'Active', 'rating': 4.6},
                {'name': 'Dr. Layla Mohammed', 'specialty': 'Physical Therapy', 'status': 'Away', 'rating': 4.8},
                {'name': 'Dr. Ahmed Sami', 'specialty': 'Special Education', 'status': 'Active', 'rating': 4.9},
              ];
              final specialist = specialists[index];
              final name = specialist['name'] as String;
              final specialty = specialist['specialty'] as String;
              final status = specialist['status'] as String;
              final rating = specialist['rating'] as double;
              
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryLight, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(name),
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(specialty),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(rating.toString()),
                        ],
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () => _viewSpecialistDetails(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          _buildSectionHeader(
            'Analytics Dashboard',
            'Real-time insights and metrics',
            Icons.analytics,
          ),
          SizedBox(height: 24),
          
          GridView(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            children: [
              _buildMetricCard('Total Children', '87', '+12%', Icons.child_care, AppColors.info),
              _buildMetricCard('Active Specialists', '15', '+5%', Icons.people, AppColors.success),
              _buildMetricCard('Sessions Today', '24', '+8%', Icons.event_available, AppColors.warning),
              _buildMetricCard('Revenue', '\$5,240', '+15%', Icons.attach_money, AppColors.primary),
            ],
          ),
          SizedBox(height: 24),
          
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Performance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart, size: 50, color: AppColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Interactive Charts Coming Soon',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    return Column(
      children: [
        _buildSectionHeader(
          'Services Management',
          'Manage your offered services',
          Icons.medical_services,
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (context, index) {
              final services = [
                {'name': 'Speech Therapy', 'price': '\$50/session', 'status': 'Active', 'duration': '45 min'},
                {'name': 'Occupational Therapy', 'price': '\$60/session', 'status': 'Active', 'duration': '60 min'},
                {'name': 'Behavioral Therapy', 'price': '\$70/session', 'status': 'Inactive', 'duration': '50 min'},
                {'name': 'Psychological Counseling', 'price': '\$80/session', 'status': 'Active', 'duration': '60 min'},
              ];
              final service = services[index];
              final name = service['name'] as String;
              final price = service['price'] as String;
              final status = service['status'] as String;
              final duration = service['duration'] as String;
              
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.medical_services, color: AppColors.primary),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(price),
                      SizedBox(height: 4),
                      Text('Duration: $duration'),
                    ],
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () => _editService(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        _buildSectionHeader(
          'Messages',
          'Chat with parents and specialists',
          Icons.chat,
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: 6,
            itemBuilder: (context, index) {
              final chats = [
                {'name': 'Parent Ahmed', 'lastMsg': 'Thank you for the update!', 'unread': 2, 'time': '2:30 PM'},
                {'name': 'Specialist Sara', 'lastMsg': 'Need to discuss session plan', 'unread': 1, 'time': '1:45 PM'},
                {'name': 'Parent Mohammed', 'lastMsg': 'When is the next appointment?', 'unread': 0, 'time': '11:20 AM'},
                {'name': 'Specialist Ali', 'lastMsg': 'Progress report ready', 'unread': 0, 'time': 'Yesterday'},
                {'name': 'Parent Fatima', 'lastMsg': 'Payment completed', 'unread': 3, 'time': 'Yesterday'},
                {'name': 'Admin Support', 'lastMsg': 'System maintenance notice', 'unread': 0, 'time': '2 days ago'},
              ];
              final chat = chats[index];
              final name = chat['name'] as String;
              final lastMsg = chat['lastMsg'] as String;
              final unread = chat['unread'] as int;
              final time = chat['time'] as String;
              
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryLight, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(name),
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textGray,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unread.toString(),
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () => _openChat(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          _buildSectionHeader(
            'Community Hub',
            'Engage with your community',
            Icons.group,
          ),
          SizedBox(height: 24),
          
          GridView(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            children: [
              _buildCommunityCard('Events', Icons.event, 'Upcoming events', AppColors.primary),
              _buildCommunityCard('Workshops', Icons.workspaces, 'Educational sessions', AppColors.success),
              _buildCommunityCard('Support Groups', Icons.group, 'Parent communities', AppColors.info),
              _buildCommunityCard('Resources', Icons.library_books, 'Learning materials', AppColors.warning),
            ],
          ),
          SizedBox(height: 24),
          
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Activities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),
                _buildActivityItem('New parent joined the community', '2 hours ago', Icons.person_add),
                _buildActivityItem('Workshop scheduled for next week', '1 day ago', Icons.event),
                _buildActivityItem('New specialist approved', '2 days ago', Icons.verified),
                _buildActivityItem('Community donation received', '3 days ago', Icons.volunteer_activism),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorsTab() {
    return Column(
      children: [
        _buildSectionHeader(
          'Donors & Sponsors',
          'Manage your supporters',
          Icons.volunteer_activism,
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (context, index) {
              final donors = [
                {'name': 'Al-Rajhi Foundation', 'type': 'Corporate Sponsor', 'amount': '\$10,000', 'date': '2024'},
                {'name': 'Community Fund', 'type': 'Community Organization', 'amount': '\$5,000', 'date': '2024'},
                {'name': 'Individual Donor', 'type': 'Private Donation', 'amount': '\$2,500', 'date': '2024'},
                {'name': 'Education Grant', 'type': 'Government Grant', 'amount': '\$15,000', 'date': '2024'},
              ];
              final donor = donors[index];
              final name = donor['name'] as String;
              final type = donor['type'] as String;
              final amount = donor['amount'] as String;
              final date = donor['date'] as String;
              
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.volunteer_activism, color: AppColors.primary),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type),
                      SizedBox(height: 4),
                      Text(
                        amount,
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    date,
                    style: TextStyle(
                      color: AppColors.textLight,
                    ),
                  ),
                  onTap: () => _viewDonorDetails(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackTab() {
    return Column(
      children: [
        _buildSectionHeader(
          'Feedback & Reviews',
          'What parents are saying',
          Icons.feedback,
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (context, index) {
              final feedbacks = [
                {'name': 'Parent Ahmed', 'rating': 5, 'comment': 'Excellent service! My child has improved significantly.', 'date': '2 days ago'},
                {'name': 'Parent Sara', 'rating': 4, 'comment': 'Very professional staff and caring environment.', 'date': '1 week ago'},
                {'name': 'Parent Mohammed', 'rating': 5, 'comment': 'My child improved a lot thanks to the dedicated specialists.', 'date': '2 weeks ago'},
                {'name': 'Parent Fatima', 'rating': 3, 'comment': 'Good service but needs improvement in scheduling.', 'date': '3 weeks ago'},
                {'name': 'Parent Khalid', 'rating': 5, 'comment': 'Highly recommended! The best center in town.', 'date': '1 month ago'},
              ];
              final feedback = feedbacks[index];
              final name = feedback['name'] as String;
              final rating = feedback['rating'] as int;
              final comment = feedback['comment'] as String;
              final date = feedback['date'] as String;
              
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primaryLight, AppColors.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(name),
                                style: TextStyle(
                                  color: AppColors.textWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (starIndex) => Icon(
                                    Icons.star,
                                    size: 16,
                                    color: starIndex < rating ? Colors.amber : Colors.grey,
                                  )),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        comment,
                        style: TextStyle(
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: Icon(Icons.thumb_up, size: 16),
                            label: Text('Helpful'),
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                          TextButton.icon(
                            icon: Icon(Icons.reply, size: 16),
                            label: Text('Reply'),
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===== HELPER WIDGETS =====
  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.accent1,
      labelStyle: TextStyle(color: AppColors.primary),
    );
  }

  Widget _buildStatusBadge() {
    final status = institutionData?['approval_status']?.toString() ?? 'Pending';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor(status)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), size: 16, color: _getStatusColor(status)),
          SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String change, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                Text(
                  change,
                  style: TextStyle(
                    color: change.contains('+') ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityCard(String title, IconData icon, String subtitle, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String activity, String time, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          SizedBox(width: 12),
          Expanded(child: Text(activity)),
          Text(
            time,
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 16),
          _buildDetailRow('Contact Email', institutionData?['contact_email']?.toString()),
          _buildDetailRow('Contact Phone', institutionData?['contact_phone']?.toString()),
          _buildDetailRow('License', institutionData?['license_number']?.toString()),
          _buildDetailRow('Address', institutionData?['location_address']?.toString()),
          _buildDetailRow('City', institutionData?['city']?.toString()),
          _buildDetailRow('Region', institutionData?['region']?.toString()),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
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
                fontWeight: FontWeight.w500,
                color: AppColors.textGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not specified',
              style: TextStyle(
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(Icons.edit),
            label: Text('Edit Info'),
            onPressed: _editInstitution,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(Icons.photo),
            label: Text('Add Photos'),
            onPressed: _addInstitutionPhotos,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== HELPER METHODS =====
  String _getInitials(String name) {
    return name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
      case 'excellent':
      case 'good':
        return AppColors.success;
      case 'pending':
      case 'busy':
      case 'improving':
      case 'stable':
        return AppColors.warning;
      case 'rejected':
      case 'inactive':
        return AppColors.error;
      default:
        return AppColors.textGray;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'rejected':
      case 'inactive':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  // ===== ACTION METHODS =====
  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You have 3 new notifications'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _editProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit Profile - Coming Soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _editInstitution() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit Institution - Coming Soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _addInstitutionPhotos() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add Photos - Coming Soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _viewSpecialistDetails(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View Specialist Details - Coming Soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _editService(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit Service - Coming Soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _openChat(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open Chat - Coming Soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _viewDonorDetails(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View Donor Details - Coming Soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 20),
              _buildQuickActionItem('Add New Specialist', Icons.person_add, _addSpecialist),
              _buildQuickActionItem('Add New Child', Icons.child_care, _addChild),
              _buildQuickActionItem('Schedule Event', Icons.event, () {}),
              _buildQuickActionItem('Send Announcement', Icons.announcement, () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _addSpecialist() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add Specialist - Coming Soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _addChild() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add Child - Coming Soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}