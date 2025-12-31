// lib/screens/manager/manager_home_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/manager/manager_free_sessions_screen.dart';
import 'package:frontend/screens/manager_equipment_donations_screen.dart';
import 'package:frontend/screens/manager/manager_equipment_campaigns_screen.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/screens/reports_list_screen.dart';
import 'package:frontend/services/reports_service.dart';
import '../../services/manager_dashboard_service.dart';
import 'manager/children_management_screen.dart';
import 'manager/specialist_management_screen.dart';
import 'manager/financial_report_screen.dart';
import 'manager/donations_screen.dart';
import 'manager/institution_profile_screen.dart';
import 'manager/institution_reviews_dashboard.dart';
import 'package:frontend/screens/community_screen.dart';
import 'package:frontend/screens/chat_list_screen.dart';
import 'manager/financial_requests_screen.dart';
import 'manager/manager_workshops_screen.dart';
import 'manager/manager_donations_screen.dart';
import 'manager/manager_financial_report_screen.dart';
import 'manager/manager_donation_campaigns_screen.dart';
import 'public_institution_home_screen.dart';
import 'manager/cms/manager_cms_dashboard_screen.dart';

import 'package:frontend/screens/login_screen.dart';

class ManagerHomeScreen extends StatefulWidget {
  @override
  _ManagerHomeScreenState createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  bool _isSidebarOpen = false;
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _sidebarItems = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ManagerDashboardService.getDashboardStats();

      setState(() {
        final donations = data['donations'] ?? {};

        _dashboardData = {
          'institutionId': data['institution']['institution_id'],
          'centerName': data['institution']['name'],
          'totalRevenue': data['revenue']['currentMonth']?.toInt() ?? 0,
          'activeSessions': data['sessionStats']['totalSessions'] ?? 0,
          'totalChildren': data['children']['total'] ?? 0,
          'totalSpecialists': data['specialists']['total'] ?? 0,
          'monthlyGrowth': data['revenue']['growth']?.toDouble() ?? 0,
          'pendingRequests': data['pendingRequests']['registrations'] ?? 0,
          'todaySessions': data['sessionStats']['todaySessions'] ?? 0,
          'monthlySessions': data['sessionStats']['monthlySessions'] ?? 0,
          'sessionGrowth':
              data['sessionStats']['sessionGrowth']?.toDouble() ?? 0,
          'totalDonations': donations['totalDonations'] ?? 0,
          'donationBalance': donations['donationBalance'] ?? 0,
          'totalAllocated': donations['totalAllocated'] ?? 0,
        };

        // أضف هذا: تحميل إحصائيات التبرعات العينية
        _stats = data; // أو بيانات محددة تحتاجها

        // تحويل sessionDistribution إلى chartData مع ألوان مختلفة
        final sessionDistribution = data['sessionDistribution'] as List? ?? [];
        _chartData = sessionDistribution.map<Map<String, dynamic>>((item) {
          final category = item['category']?.toString() ?? 'Unknown';
          return {
            'label': category,
            'value': item['percentage']?.toDouble() ?? 0,
            'color': _getColorForCategory(category),
          };
        }).toList();

        // تحديث sidebar items مع إضافة التبرعات العينية
        _sidebarItems = [
          {
            'title': 'Public Institution Preview',
            'icon': Icons.public_rounded,
            'count': 0,
            'route': 'public_preview',
          },
          {
            'title': 'Complete Institution Setup',
            'icon': Icons.verified_outlined,
            'count': 0,
            'route': 'onboarding',
          },
          {
            'title': 'CMS Management',
            'icon': Icons.dashboard_customize_rounded,
            'count': 0,
            'route': 'cms',
          },
          {
            'title': 'Children Management',
            'icon': Icons.child_care_rounded,
            'count': data['children']['total'] ?? 0,
            'route': 'children',
          },
          {
            'title': 'Specialists Management',
            'icon': Icons.medical_services_rounded,
            'count': data['specialists']['total'] ?? 0,
            'route': 'specialists',
          },
          {
            'title': 'Financial Assistance Requests',
            'icon': Icons.request_quote_rounded,
            'count': data['pendingRequests']['financial'] ?? 0,
          },
          {
            'title': 'Free Session Offers',
            'icon': Icons.volunteer_activism_rounded,
            'count': 0,
          },
          {
            'title': 'Parent Workshops',
            'icon': Icons.groups_2_rounded,
            'count': 0,
          },
          {
            'title': 'Financial Reports',
            'icon': Icons.assessment_rounded,
            'count': data['revenue']['currentMonth']?.toInt() ?? 0,
            'route': 'financial',
          },
          {
            'title': 'Donations',
            'icon': Icons.volunteer_activism_rounded,
            'count': (data['donationStats']?['totalDonations'] ?? 0).toInt(),
            'route': 'donations',
          },
          // أضف هذا العنصر الجديد
          {
            'title': 'Equipment Donations',
            'icon': Icons.medical_services_rounded,
            'count': 0, // يمكنك جلب العدد من API
            'route': 'equipment_donations',
          },
          {
            'title': 'Equipment Campaigns',
            'icon': Icons.campaign_rounded,
            'count': 0,
            'route': 'equipment_campaigns',
          },
          {
            'title': 'Session Management',
            'icon': Icons.calendar_today_rounded,
            'count': data['sessionStats']['monthlySessions'] ?? 0,
          },
          {
            'title': 'Community',
            'icon': Icons.groups_rounded,
            'count': data['communityStats']?['members'] ?? 0,
            'route': 'community',
          },
          {
            'title': 'Messages',
            'icon': Icons.message_rounded,
            'count': data['messageStats']?['unread'] ?? 0,
            'route': 'messages',
          },
          {
            'title': 'Institution Profile',
            'icon': Icons.business_rounded,
            'count': 0,
            'route': 'profile',
          },
          {
            'title': 'Institution Rating',
            'icon': Icons.star,
            'count': 0,
            'route': 'rate',
          },
          {
            'title': 'Reports',
            'icon': Icons.report_gmailerrorred_rounded,
            'count': 0,
            'route': 'reports',
          },
        ];

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard: $e');
      setState(() {
        _isLoading = false;
        _dashboardData = {
          'institutionId': null,
          'centerName': 'Therapy Care Center',
          'totalRevenue': 0,
          'activeSessions': 0,
          'totalChildren': 0,
          'totalSpecialists': 0,
          'monthlyGrowth': 0,
          'pendingRequests': 0,
          'todaySessions': 0,
          'monthlySessions': 0,
          'sessionGrowth': 0,
        };
        _stats = {}; // تهيئة فارغة
        _chartData = [
          {'label': 'Speech Therapy', 'value': 40, 'color': AppColors.primary},
          {'label': 'Behavioral', 'value': 25, 'color': AppColors.success},
          {'label': 'Occupational', 'value': 20, 'color': AppColors.warning},
          {'label': 'Educational', 'value': 10, 'color': AppColors.info},
          {'label': 'Other', 'value': 5, 'color': AppColors.accent3},
        ];
        _sidebarItems = [
          {
            'title': 'Public Institution Preview',
            'icon': Icons.public_rounded,
            'count': 0,
            'route': 'public_preview',
          },
          {
            'title': 'Complete Institution Setup',
            'icon': Icons.verified_outlined,
            'count': 0,
            'route': 'onboarding',
          },
          {
            'title': 'CMS Management',
            'icon': Icons.dashboard_customize_rounded,
            'count': 0,
            'route': 'cms',
          },
          {
            'title': 'Children Management',
            'icon': Icons.child_care_rounded,
            'count': 0,
            'route': 'children',
          },
          {
            'title': 'Specialists Management',
            'icon': Icons.medical_services_rounded,
            'count': 0,
            'route': 'specialists',
          },
          {
            'title': 'Financial Assistance Requests',
            'icon': Icons.request_quote_rounded,
            'count': 0,
          },
          {
            'title': 'Free Session Offers',
            'icon': Icons.volunteer_activism_rounded,
            'count': 0,
          },
          {
            'title': 'Parent Workshops',
            'icon': Icons.groups_2_rounded,
            'count': 0,
          },
          {
            'title': 'Financial Reports',
            'icon': Icons.assessment_rounded,
            'count': 0,
            'route': 'financial',
          },
          {
            'title': 'Donations',
            'icon': Icons.volunteer_activism_rounded,
            'count': 0,
            'route': 'donations',
          },
          {
            'title': 'Equipment Donations',
            'icon': Icons.medical_services_rounded,
            'count': 0,
            'route': 'equipment_donations',
          },
          {
            'title': 'Equipment Campaigns',
            'icon': Icons.campaign_rounded,
            'count': 0,
            'route': 'equipment_campaigns',
          },
          {
            'title': 'Session Management',
            'icon': Icons.calendar_today_rounded,
            'count': 0,
          },
          {
            'title': 'Community',
            'icon': Icons.groups_rounded,
            'count': 0,
            'route': 'community',
          },
          {
            'title': 'Messages',
            'icon': Icons.message_rounded,
            'count': 0,
            'route': 'messages',
          },
          {
            'title': 'Institution Profile',
            'icon': Icons.business_rounded,
            'count': 0,
            'route': 'profile',
          },
          {
            'title': 'Institution Rating',
            'icon': Icons.star,
            'count': 0,
            'route': 'rate',
          },
          {
            'title': 'Reports',
            'icon': Icons.report_gmailerrorred_rounded,
            'count': 0,
            'route': 'reports',
          },
        ];
      });
    }
  }

  Color _getColorForCategory(String category) {
    final String cleanCategory = category.trim().toLowerCase();

    // تعريف patterns لكل نوع
    final speechPattern = RegExp(r'(speech|communication)');
    final behaviorPattern = RegExp(r'(behavior|behaviour|aba)');
    final occupationalPattern = RegExp(r'(occupational|ot\b)');
    final psychologicalPattern = RegExp(r'(psychological|support|ps\b)');
    final assessmentPattern =
        RegExp(r'(initial.*assessment|assessment.*initial|ia\s*therapy)');

    if (speechPattern.hasMatch(cleanCategory)) {
      return Color(0xFF8CB6D1);
    } else if (behaviorPattern.hasMatch(cleanCategory)) {
      return Color(0xFF396A4E);
    } else if (occupationalPattern.hasMatch(cleanCategory)) {
      return Color(0xFFFAFDC2);
    } else if (psychologicalPattern.hasMatch(cleanCategory)) {
      return Color(0xFF68170E);
    } else if (assessmentPattern.hasMatch(cleanCategory)) {
      return Color(0xFF95DFD8);
    } else {
      // توليد لون فريد للأنواع الأخرى
      final colors = [
        AppColors.primary,
        AppColors.darkGreen,
        AppColors.blue,
        AppColors.green,
        AppColors.ment,
        AppColors.accent4,
        AppColors.accent3,
        AppColors.yalw,
        AppColors.yal,
        AppColors.accent1,
        AppColors.accent2,
      ];
      final int hash = cleanCategory.hashCode.abs();
      return colors[hash % colors.length];
    }
  }

  void _handleSidebarItemClick(Map<String, dynamic> item) {
  setState(() {
    _isSidebarOpen = false;
  });

  final title = item['title'];
  final route = item['route'];

  print('Navigating to: $title (route: $route)');

  switch (route) {
    case 'onboarding':
      Navigator.pushNamed(context, '/managerOnboarding');
      break;
    case 'public_preview':
      final instId = _dashboardData['institutionId'];
      final instName = _dashboardData['centerName']?.toString();

      if (instId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Institution id not available yet')),
        );
        break;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicInstitutionHomeScreen(
            institutionId: (instId as num).toInt(),
            institutionName: instName,
          ),
        ),
      );
      break;
    case 'cms':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManagerCmsDashboardScreen()),
      );
      break;
    case 'children':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChildrenManagementScreen(),
        ),
      );
      break;
    case 'specialists':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SpecialistManagementScreen(),
        ),
      );
      break;
    case 'financial':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ManagerFinancialReportScreen(),
        ),
      );
      break;
    case 'donations':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ManagerDonationsScreen(),
        ),
      );
      break;
    case 'equipment_donations': // أضف هذا الحالة
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ManagerEquipmentDonationsScreen(),
        ),
      );
      break;
    case 'equipment_campaigns':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ManagerEquipmentCampaignsScreen(),
        ),
      );
      break;
    case 'community':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CommunityScreen(),
        ),
      );
      break;
    case 'messages':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatListScreen(),
        ),
      );
      break;
    case 'profile':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InstitutionProfileScreen(),
        ),
      );
      break;
    case 'rate':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InstitutionReviewsDashboard(),
        ),
      );
      break;
    case 'reports':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ReportsListScreen(
            scope: ReportsScope.manager,
            title: 'Institution Reports',
          ),
        ),
      );
      break;
    default:
      _showComingSoon(title);
  }
}
  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title - Coming Soon!'),
        duration: Duration(seconds: 2),
      ),
    );
    if (title == 'Financial Reports') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ManagerFinancialReportScreen(),
        ),
      );
    }

    // if (title == 'Donation Campaigns') {
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => const ManagerDonationCampaignsScreen(),
    //     ),
    //   );
    // }

    if (title == 'Donations') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ManagerDonationsScreen(),
        ),
      );
    }

    if (title == 'Financial Assistance Requests') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ManagerFinancialRequestsScreen(),
        ),
      );
    }
    if (title == 'Free Session Offers') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ManagerFreeSessionsScreen(),
        ),
      );
    }
    if (title == 'Parent Workshops') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ManagerWorkshopsScreen(),
        ),
      );
    }
    // يمكنك إضافة باقي الصفحات هنا
  }

  void _handleLogout() {
    setState(() {
      _isSidebarOpen = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => LoginScreen()));
            },
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main Content
          _isLoading ? _buildLoadingScreen() : _buildMainContent(),

          // Sidebar Overlay
          if (_isSidebarOpen) _buildSidebarOverlay(),

          // Sidebar
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            left:
                _isSidebarOpen ? 0 : -MediaQuery.of(context).size.width * 0.85,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.85,
            child: _buildSidebar(),
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
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 20),
          Text(
            'Loading Dashboard...',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Header
        _buildHeader(),

        // Main Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Cards
                  _buildOverviewCards(),
                  SizedBox(height: 25),

                  // Donations Overview
                  _buildDonationsOverview(),
                  SizedBox(height: 25),

                  // Chart Section
                  _buildChartSection(),
                  SizedBox(height: 25),

                  // Quick Stats
                  _buildQuickStats(),

                  // Last Updated
                  _buildLastUpdated(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Menu Icon
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSidebarOpen = true;
                });
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(Icons.menu_rounded, color: Colors.white, size: 22),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _dashboardData['centerName'] ?? 'Therapy Care Center',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Management Dashboard',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Refresh Button
            GestureDetector(
              onTap: _loadDashboardData,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child:
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            'Total Revenue',
            '\$${_dashboardData['totalRevenue']?.toStringAsFixed(0) ?? '0'}',
            Icons.attach_money_rounded,
            AppColors.primary,
            '${_dashboardData['monthlyGrowth'] >= 0 ? '+' : ''}${_dashboardData['monthlyGrowth']?.toStringAsFixed(1) ?? '0'}% this month',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            'Active Sessions',
            _dashboardData['activeSessions']?.toString() ?? '0',
            Icons.video_library_rounded,
            AppColors.success,
            '${_dashboardData['todaySessions'] ?? 0} today',
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: subtitle.contains('-') ? Colors.red : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationsOverview() {
    final double totalDonations =
        (_dashboardData['totalDonations'] ?? 0).toDouble();
    final double donationBalance =
        (_dashboardData['donationBalance'] ?? 0).toDouble();
    final double totalAllocated =
        (_dashboardData['totalAllocated'] ?? 0).toDouble();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
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
                'Donations Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Icon(
                Icons.volunteer_activism_rounded,
                color: AppColors.accent3,
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDonationStatTile(
                  title: 'Total Donations',
                  value: '${totalDonations.toStringAsFixed(0)} JOD',
                  color: AppColors.accent3,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDonationStatTile(
                  title: 'Available Balance',
                  value: '${donationBalance.toStringAsFixed(0)} JOD',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildDonationStatTile(
            title: 'Used to support families',
            value: '${totalAllocated.toStringAsFixed(0)} JOD',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationStatTile({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
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
                'Session Distribution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              if (_chartData.isNotEmpty)
                Text(
                  'Total: ${_dashboardData['activeSessions'] ?? 0}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 200,
            child: _chartData.isNotEmpty
                ? Row(
                    children: [
                      // Pie Chart
                      Expanded(
                        flex: 2,
                        child: CustomPaint(
                          painter: _PieChartPainter(_chartData),
                        ),
                      ),
                      SizedBox(width: 20),
                      // Legend
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _chartData.map((data) {
                            return _buildChartLegendItem(
                              data['label'],
                              '${data['value']?.toStringAsFixed(0) ?? '0'}%',
                              data['color'],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      'No session data available',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatItem(
            'Total Children',
            _dashboardData['totalChildren']?.toString() ?? '0',
            Icons.child_care_rounded,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatItem(
            'Specialists',
            _dashboardData['totalSpecialists']?.toString() ?? '0',
            Icons.medical_services_rounded,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatItem(
            'Pending',
            _dashboardData['pendingRequests']?.toString() ?? '0',
            Icons.pending_actions_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatItem(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.textLight),
          SizedBox(width: 8),
          Text(
            'Last updated: ${DateTime.now().toString().substring(0, 16)}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSidebarOpen = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.3),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Icon
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSidebarOpen = false;
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _dashboardData['centerName'] ?? 'Management Center',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Management Center',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'equipment_donations',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  Container(width: 44, height: 44),
                ],
              ),
            ),
          ),

          // Sidebar Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Sidebar Items
                  ..._sidebarItems.map((item) {
                    return _buildSidebarItem(item);
                  }).toList(),

                  // Divider
                  SizedBox(height: 20),
                  Divider(color: AppColors.textLight.withOpacity(0.3)),

                  // Logout Button
                  SizedBox(height: 10),
                  Container(
                    margin: EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _handleLogout,
                        child: ListTile(
                          leading:
                              Icon(Icons.logout_rounded, color: Colors.red),
                          title: Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
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

  Widget _buildSidebarItem(Map<String, dynamic> item) {
    final count = item['count'] as int;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleSidebarItemClick(item),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item['icon'],
                color: AppColors.primary,
                size: 22,
              ),
            ),
            title: Text(
              item['title'],
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            trailing: count > 0
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
    );
  }
}

// Custom Pie Chart Painter
class _PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  _PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;

    double startAngle = -90 * (3.141592653589793 / 180);

    for (var item in data) {
      final sweepAngle =
          (item['value'] / 100) * 360 * (3.141592653589793 / 180);

      final paint = Paint()
        ..color = item['color']
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    final centerPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.6, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
