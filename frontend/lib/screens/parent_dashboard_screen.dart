// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../widgets/parent_summary_card.dart';
import '../widgets/parent_action_button.dart';
import '../services/api_service.dart';
import '../models/dashboard_data.dart';
import 'upcoming_sessions_screen.dart';
import 'manage_children_screen.dart';
import 'educational_resources_screen.dart';
import 'sessions_screen.dart';
import 'questionnaire_screen.dart';
import 'EditProfileScreen.dart';
import 'ViewProfileScreen.dart';
import 'profile_settings_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _selectedIndex = 0;
  DashboardData? dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  final int _unreadMessagesCount = 3;

  String _dailyTip = 'Loading daily tip...';
  bool _isLoadingTip = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDailyTip();
    });
  }

  Future<void> _loadInitialData() async {
    await _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('Token not found');
      }

      final response = await ApiService.getParentDashboard(token);
      if (response == null) {
        throw Exception('Invalid server response');
      }

      final newDashboardData = DashboardData.fromJson(response);

      setState(() {
        dashboardData = newDashboardData;
        _isLoading = false;
      });

      await _fetchDailyTip();

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data. Please try again.';
        _isLoading = false;
        _isLoadingTip = false;
        _dailyTip = 'Spend quality time playing with your child today - play is a great way to build trust and skills.';
      });
    }
  }

  Future<void> _fetchDailyTip() async {
    setState(() {
      _isLoadingTip = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('Token not found');
      }

      print('🔄 Fetching AI daily tip...');

      // استدعاء الـ API الجديد
      final response = await ApiService.getDailyAITip(token);

      print('✅ AI Tip response: $response');

      if (response['success'] == true) {
        setState(() {
          _dailyTip = response['tip'];
          _isLoadingTip = false;
        });
      } else {
        throw Exception('Failed to get AI tip');
      }

    } catch (e) {
      print('❌ Error fetching AI tip: $e');

      // Fallback tips
      final fallbackTips = [
        'Spend quality time playing with your child today - play is a great way to build trust and skills.',
        'Read a story to your child before bedtime. It helps develop language skills and imagination.',
        'Praise your child\'s efforts, not just results. This builds confidence and resilience.',
        'Create a consistent daily routine - children feel secure when they know what to expect.',
      ];

      final today = DateTime.now().day;
      final selectedTip = fallbackTips[today % fallbackTips.length];

      setState(() {
        _dailyTip = selectedTip;
        _isLoadingTip = false;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SessionsScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildAvatar({required String name, required String image, double radius = 28}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: ParentAppColors.primaryTeal.withOpacity(0.3),
      child: (image.isNotEmpty)
          ? ClipOval(
        child: Image.network(
          image,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.65,
                    fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      )
          : Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.65,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentAppColors.backgroundLight,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
          : RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildParentProfileAndChildrenSummary(),
              SizedBox(height: 25),
              _buildDailyTipCard(),
              SizedBox(height: 25),
              _buildQuickSummaries(),
              SizedBox(height: 25),
              _buildProgressAndReports(),
              SizedBox(height: 25),
              _buildMainActionsGrid(),
              SizedBox(height: 25),
              _buildInstitutionSuggestions(),
              SizedBox(height: 25),
              _buildPaymentOverview(),
              SizedBox(height: 25),
              _buildCommunityHighlights(),
              SizedBox(height: 25),
              _buildRecentNotificationsFeed(),
              SizedBox(height: 50),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
              color: ParentAppColors.primaryTeal.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _buildAvatar(
                        name: dashboardData?.parent.name ?? '',
                        image: dashboardData?.parent.profilePicture ?? '',
                        radius: 35,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: ParentAppColors.primaryTeal,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: _showProfileMenu,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    dashboardData?.parent.name ?? 'Parent',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dashboardData?.parent.address ?? ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.family_restroom, color: ParentAppColors.primaryTeal, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${dashboardData?.children.length ?? 0} Children',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.child_care,
                    title: 'My Children',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManageChildrenScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_today,
                    title: 'Sessions',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SessionsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.assessment,
                    title: 'Progress Reports',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.chat,
                    title: 'Messages',
                    badgeCount: _unreadMessagesCount,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.payment,
                    title: 'Payments',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/parent-payment-dashboard');
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(height: 1),
                  ),

                  _buildDrawerItem(
                    icon: Icons.school,
                    title: 'Educational Resources',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EducationalResourcesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.local_hospital,
                    title: 'Centers & Institutions',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'Community',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(height: 1),
                  ),

                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileSettingsScreen(),
                        ),
                      );
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              child: _buildDrawerItem(
                icon: Icons.logout,
                title: 'Logout',
                color: Colors.red,
                onTap: () {
                  _showLogoutDialog();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    int? badgeCount,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? ParentAppColors.primaryTeal,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: color ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: badgeCount != null && badgeCount > 0
          ? Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          badgeCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              _buildProfileMenuItem(
                icon: Icons.edit,
                title: 'Edit Profile',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToEditProfile();
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.camera_alt,
                title: 'Change Photo',
                onTap: () {
                  Navigator.pop(context);
                  _showImageSourceDialog();
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.visibility,
                title: 'View Profile',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToViewProfile();
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.settings,
                title: 'Profile Settings',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToProfileSettings();
                },
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: ParentAppColors.primaryTeal,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    ).then((updated) {
      if (updated == true) {
        _fetchDashboardData();
      }
    });
  }

  void _navigateToViewProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ViewProfileScreen(),
      ),
    );
  }

  void _navigateToProfileSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSettingsScreen(),
      ),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Profile Photo'),
          content: const Text('Choose photo source'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _simpleLogout();
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _simpleLogout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await Future.delayed(const Duration(milliseconds: 500));

      Navigator.pop(context);

      if (mounted) {
        Navigator.pop(context);

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
              (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      print('Logout error: $e');

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
              (route) => false,
        );
      }
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.2,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(
            Icons.menu,
            color: ParentAppColors.textDark,
            size: 28,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text('Parent Dashboard',
          style: TextStyle(
              color: ParentAppColors.textDark,
              fontSize: 21,
              fontWeight: FontWeight.bold)),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none, color: ParentAppColors.textDark),
              onPressed: () {},
            ),
            if (_unreadMessagesCount > 0)
              Positioned(
                right: 11,
                top: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildParentProfileAndChildrenSummary() {
    final parent = dashboardData?.parent;
    final children = dashboardData?.children ?? [];

    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 8)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _buildAvatar(name: parent?.name ?? '', image: parent?.profilePicture ?? ''),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back, ${parent?.name ?? ''} 👋',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 4),
                  Text('${parent?.address ?? ''} • ${parent?.phone ?? ''}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            )
          ]),
          Divider(height: 25),
          Text('Your Children (${children.length})',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (_, __) => SizedBox(width: 15),
              itemBuilder: (_, i) {
                final child = children[i];
                return Column(
                  children: [
                    _buildAvatar(name: child.name, image: child.image, radius: 25),
                    SizedBox(height: 5),
                    Text(child.name,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text(child.condition,
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTipCard() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ParentAppColors.accentOrange.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParentAppColors.accentOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  _isLoadingTip ? Icons.hourglass_top : Icons.auto_awesome,
                  color: ParentAppColors.accentOrange,
                  size: 30
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('AI Daily Tip 🤖',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(width: 8),
                        if (_isLoadingTip)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(ParentAppColors.accentOrange),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Personalized for your child\'s needs',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isLoadingTip)
                IconButton(
                  icon: Icon(Icons.refresh, size: 20, color: ParentAppColors.primaryTeal),
                  onPressed: _fetchDailyTip,
                  tooltip: 'Get New Tip',
                ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            _dailyTip,
            style: TextStyle(
              color: Colors.black87,
              height: 1.4,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 12, color: Colors.amber),
              SizedBox(width: 4),
              Text(
                'Powered by AI • Updates daily',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSummaries() {
    final s = dashboardData?.summaries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            ParentSummaryCard(
              icon: Icons.calendar_month,
              title: 'Upcoming Sessions',
              count: dashboardData?.summaries.upcomingSessions ?? 0,
              color: ParentAppColors.primaryTeal,
              buttonText: 'View All ➜',
              onTap: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('token') ?? '';

                  if (token.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please login again'))
                    );
                    return;
                  }

                  print('🔄 Fetching upcoming sessions...');
                  final sessions = await ApiService.getUpcomingSessions(token);
                  print('✅ Sessions fetched: ${sessions.length}');

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => UpcomingSessionsScreen(
                          upcomingSessions: sessions,
                        )
                    ),
                  );
                } catch (e) {
                  print('❌ Error fetching sessions: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load sessions: $e'))
                  );
                }
              },
            ),
            ParentSummaryCard(
              icon: Icons.insights,
              title: 'New Reports',
              count: s?.newReportsCount ?? 0,
              color: Colors.deepPurpleAccent,
              buttonText: 'Open ➜',
              onTap: () {},
            ),
            ParentSummaryCard(
                icon: Icons.child_care,
                title: 'Children',
                count: dashboardData?.children.length ?? 0,
                color: ParentAppColors.accentOrange,
                buttonText: 'Manage ➜',
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ManageChildrenScreen()));
                }),
          ]),
        )
      ],
    );
  }

  Widget _buildProgressAndReports() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress & Reports',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          Text('Track your child\'s improvement over time 📈',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: 0.65,
            color: ParentAppColors.primaryTeal,
            backgroundColor: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            minHeight: 10,
          ),
          SizedBox(height: 8),
          Align(
              alignment: Alignment.centerRight,
              child: Text('65% of therapy plan completed',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
        ],
      ),
    );
  }

  Widget _buildMainActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tools & Resources',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            ParentActionButton(
              icon: Icons.assignment,
              text: 'Initial Screening',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
                );
              },
            ),
            ParentActionButton(icon: Icons.school, text: 'Browse Centers', onTap: () {}),
            ParentActionButton(
              icon: Icons.menu_book,
              text: 'Educational Resources',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EducationalResourcesScreen()),
                );
              },
            ),
            ParentActionButton(icon: Icons.forum, text: 'Community', onTap: () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildInstitutionSuggestions() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 6)
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recommended Centers 🏥',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Column(
            children: [
              _buildInstitutionTile('Yasmeen Charity', 'Amman, Jordan', 'Autism, Speech Therapy'),
              _buildInstitutionTile('Sanad Center', 'Irbid', 'ADHD, Down Syndrome'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInstitutionTile(String name, String location, String tags) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
      CircleAvatar(radius: 25, backgroundColor: ParentAppColors.primaryTeal.withOpacity(0.2)),
      title: Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$location • $tags', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {},
    );
  }

  Widget _buildPaymentOverview() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 6)
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Payments 💳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Next due: 25 Oct 2025', style: TextStyle(color: Colors.grey[700])),
          TextButton(onPressed: () {}, child: Text('Pay Now ➜'))
        ]),
        LinearProgressIndicator(
          value: 0.8,
          color: ParentAppColors.accentOrange,
          backgroundColor: Colors.grey[200],
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
        SizedBox(height: 6),
        Text('80% paid this month', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]),
    );
  }

  Widget _buildCommunityHighlights() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: ParentAppColors.primaryTeal.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Community Highlights 🌟',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          _buildCommunityPost('New awareness event this Friday at Yasmeen Charity!'),
          _buildCommunityPost('Parents forum: Tips for managing ADHD routines.'),
        ],
      ),
    );
  }

  Widget _buildCommunityPost(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(children: [
      Icon(Icons.campaign, color: ParentAppColors.primaryTeal, size: 20),
      SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13))),
    ]),
  );

  Widget _buildRecentNotificationsFeed() {
    final notifications = dashboardData?.summaries.notifications ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Latest Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ...notifications.map((n) {
          final notification = n is Map ? n : {};
          final title = notification['title']?.toString() ?? 'Notification';
          final time = '2 hours ago';

          return ListTile(
            leading: Icon(Icons.notifications, color: ParentAppColors.primaryTeal),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(time, style: TextStyle(color: Colors.grey[600])),
            trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () {},
          );
        }),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.child_care), label: 'Children'),
        BottomNavigationBarItem(icon: Icon(Icons.local_hospital), label: 'Centers'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: ParentAppColors.primaryTeal,
      unselectedItemColor: Colors.grey,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
    );
  }
}