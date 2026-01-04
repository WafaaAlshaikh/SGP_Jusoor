import 'package:flutter/material.dart';
import 'package:frontend/screens/donor_dashboard_screen.dart';
import 'package:frontend/screens/financial_assistance_dashboard.dart';
import 'package:frontend/screens/general_assessment_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../models/dashboard_data.dart';
import 'upcoming_sessions_screen.dart';
import 'browse_centers_screen.dart';
import 'manage_children_screen.dart';
import 'educational_resources_screen.dart';
import 'sessions_screen.dart';
import 'EditProfileScreen.dart';
import 'ViewProfileScreen.dart';
import 'profile_settings_screen.dart';
import 'package:frontend/screens/notifications_screen.dart';
import 'package:frontend/screens/chat_list_screen.dart';
import 'community_screen.dart';
import 'parent_child_evaluations_screen.dart';
import 'browse_centers_screen.dart';
import 'parent_workshops_screen.dart';
import 'parent_free_sessions_screen.dart';
import 'start_screening_screen.dart';
import 'my_ratings_screen.dart';
import 'donation_screen.dart';
import 'parent_donation_history_screen.dart';
import 'reports_list_screen.dart';
import '../services/reports_service.dart';
import 'parent_equipment_allocations_screen.dart';

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
  bool _showFullTip = false;

  List<dynamic> _communityHighlights = [];
  bool _isLoadingCommunity = true;

  // Donation impact (for parent/donor)
  Map<String, dynamic>? _donationImpact;
  bool _isLoadingDonationImpact = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _fetchDonationImpact() async {
    if (!mounted) return;

    setState(() {
      _isLoadingDonationImpact = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() {
          _donationImpact = null;
          _isLoadingDonationImpact = false;
        });
        return;
      }

      final impact = await ApiService.getDonationImpact(token);

      if (!mounted) return;
      setState(() {
        _donationImpact = impact;
        _isLoadingDonationImpact = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _donationImpact = null;
        _isLoadingDonationImpact = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    await _fetchDashboardData();
    _fetchDailyTip();
    _fetchCommunityHighlights();
    _fetchDonationImpact();
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

      if (mounted) {
        setState(() {
          dashboardData = newDashboardData;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load dashboard. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchCommunityHighlights() async {
    if (!mounted) return;

    setState(() => _isLoadingCommunity = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() => _isLoadingCommunity = false);
        return;
      }

      final response = await ApiService.getCommunityPosts(token, limit: 3);
      final posts = response['data'] as List? ?? [];

      if (posts.isEmpty) {
        setState(() {
          _communityHighlights = [];
          _isLoadingCommunity = false;
        });
        return;
      }

      final highlights = <dynamic>[];

      for (int i = 0; i < (posts.length < 3 ? posts.length : 3); i++) {
        highlights.add(posts[i]);
      }

      setState(() {
        _communityHighlights = highlights;
        _isLoadingCommunity = false;
      });
    } catch (e) {
      setState(() => _isLoadingCommunity = false);
    }
  }

  Future<void> _fetchDailyTip() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTip = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        _setFallbackTip();
        return;
      }

      final response = await ApiService.getDailyAITip(token);

      if (mounted && response['success'] == true) {
        setState(() {
          _dailyTip = response['tip'];
          _isLoadingTip = false;
        });
      } else {
        _setFallbackTip();
      }

    } catch (e) {
      _setFallbackTip();
    }
  }

  void _setFallbackTip() {
    if (!mounted) return;

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

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ManageChildrenScreen()),
      );
    }
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BrowseCentersScreen()),
      );
    }
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatListScreen()),
      );
    }
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) =>  ProfileSettingsScreen()),
      );
    }

    else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildAvatar({required String name, required String image, double radius = 28}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.1),
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
                    color: AppColors.primary,
                    fontSize: radius * 0.65,
                    fontWeight: FontWeight.w600),
              ),
            );
          },
        ),
      )
          : Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
            color: AppColors.primary,
            fontSize: radius * 0.65,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 48),
            SizedBox(height: 16),
            Text(_errorMessage!,
              style: TextStyle(color: AppColors.textGray, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDashboardData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Try Again'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchDashboardData,
        backgroundColor: AppColors.background,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              SizedBox(height: 20),
              _buildFinancialAssistanceCard(), // 
              SizedBox(height: 20),
              _buildChildrenSection(),
              SizedBox(height: 20),
              _buildDailyTipCard(),
              SizedBox(height: 20),
              _buildQuickStats(),
              SizedBox(height: 20),
              _buildDonationImpactCard(),
              SizedBox(height: 20),
              _buildMainActions(),
              SizedBox(height: 20),
              // _buildPaymentOverview(),
              // SizedBox(height: 20),
              _buildCommunitySection(),
              SizedBox(height: 20),
              _buildRecentNotificationsFeed(),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildFinancialAssistanceCard() {
  return GestureDetector(
    onTap: () {
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => FinancialAssistanceDashboard(),
      //   ),
      // );
       _showFinancialAssistanceOptions();
    },
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.attach_money, color: Colors.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Assistance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Check your eligibility and apply for therapy cost support',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
        ],
      ),
    ),
  );
}

void _showFinancialAssistanceOptions() {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Financial Assistance Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 20),
            
            // Option 1: General Assessment
            ListTile(
              leading: Icon(Icons.assessment, color: AppColors.primary),
              title: Text('Quick Financial Assessment'),
              subtitle: Text('Check your eligibility in 3-5 minutes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GeneralFinancialAssessmentScreen(),
                  ),
                );
              },
            ),
            
            // Option 2: Dashboard
            ListTile(
              leading: Icon(Icons.dashboard, color: AppColors.primary),
              title: Text('Financial Assistance Dashboard'),
              subtitle: Text('View all options and manage requests'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FinancialAssistanceDashboard(),
                  ),
                );
              },
            ),
            
            // Option 3: Existing Requests
            ListTile(
              leading: Icon(Icons.request_quote, color: AppColors.primary),
              title: Text('My Assistance Requests'),
              subtitle: Text('View and manage your applications'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to requests screen
              },
            ),
            
            SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    },
  );
}



  Widget _buildWelcomeSection() {
    final parent = dashboardData?.parent;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24), // 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.08), AppColors.primary.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      constraints: BoxConstraints(
        minHeight: 120, // 
      ),
      child: Row(
        children: [
          Stack(
            children: [
              _buildAvatar(
                name: parent?.name ?? '',
                image: parent?.profilePicture ?? '',
                radius: 36, // 
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showProfileMenu,
                  child: Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, // 
              children: [
                Row(
                  children: [
                    Text(
                      'Hello,',
                      style: TextStyle(
                        fontSize: 19,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      parent?.name ?? 'Parent',
                      style: TextStyle(
                        fontSize: 19,
                        color: AppColors.textDark,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8), // 
                Text(
                  'Ready to continue your child\'s journey',
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
    );
  }



  // === CHILDREN SECTION ===
  Widget _buildChildrenSection() {
    final children = dashboardData?.children ?? [];
    if (children.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Children',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    '${children.length} Children',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParentEquipmentAllocationsScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medical_information, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Equipment',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 105,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: children.length,
            separatorBuilder: (_, __) => SizedBox(width: 15),
            itemBuilder: (_, index) {
              final child = children[index];
              return _buildChildCircle(child);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChildCircle(dynamic child) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ParentChildEvaluationsScreen(childId: child.childId),
          ),
        );
      },
      child: Container(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                _buildAvatar(name: child.name, image: child.image, radius: 30),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.visibility,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              child.name.split(' ').first,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              child.condition,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textGray,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // === DAILY TIP ===
  Widget _buildDailyTipCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showFullTip = !_showFullTip;
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accent1, AppColors.accent2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Daily Insight',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showFullTip ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary,
                ),
              ],
            ),
            SizedBox(height: 12),
            AnimatedCrossFade(
              duration: Duration(milliseconds: 300),
              crossFadeState: _showFullTip ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: Text(
                _dailyTip.length > 100 ? '${_dailyTip.substring(0, 100)}...' : _dailyTip,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              secondChild: Text(
                _dailyTip,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                  height: 1.4,
                ),
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: AppColors.textGray),
                SizedBox(width: 4),
                Text(
                  'Updated daily • AI Powered',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // === DONATION IMPACT (PARENT) ===
  Widget _buildDonationImpactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Donation Impact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isLoadingDonationImpact)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              if (_isLoadingDonationImpact) {
                return const Text(
                  'Loading your donation impact...',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                );
              }

              if (_donationImpact == null) {
                return const Text(
                  'No donation impact data yet. Start donating to see how you help other families.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                );
              }

              final sessions = (_donationImpact!['sessionsSupportedCount'] ?? 0) as int;
              final children = (_donationImpact!['childrenSupportedCount'] ?? 0) as int;

              if (sessions == 0 || children == 0) {
                return const Text(
                  'Your donations are ready to support upcoming sessions.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                );
              }

              return Text(
                'Your donations covered $sessions sessions for $children children.',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              );
            },
          ),
        ],
      ),
    );
  }

  // === QUICK STATS ===
  Widget _buildQuickStats() {
    final s = dashboardData?.summaries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Quick Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.8,
          children: [
            _buildMiniStatCard(
              icon: Icons.calendar_today,
              title: 'Sessions',
              value: dashboardData?.summaries.upcomingSessions ?? 0,
              color: AppColors.primary,
              onTap: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('token') ?? '';
                  if (token.isEmpty) return;

                  final sessions = await ApiService.getUpcomingSessions(token);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SessionsScreen()),
                  );
                } catch (e) {
                  print(' Error fetching sessions: $e');
                }
              },
            ),
            _buildMiniStatCard(
              icon: Icons.assessment,
              title: 'Reports',
              value: s?.newReportsCount ?? 0,
              color: AppColors.info,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ParentChildEvaluationsScreen()),
                );
              },
            ),
            _buildMiniStatCard(
              icon: Icons.child_care,
              title: 'Children',
              value: dashboardData?.children.length ?? 0,
              color: AppColors.success,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ManageChildrenScreen()));
              },
            ),
            _buildMiniStatCard(
              icon: Icons.forum,
              title: 'Messages',
              value: _unreadMessagesCount,
              color: AppColors.accent4,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ChatListScreen()));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required String title,
    required int value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === MAIN ACTIONS ===
  Widget _buildMainActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'How I can help you?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildModernActionCard(
                      icon: Icons.assignment,
                      title: 'Initial Screening',
                      subtitle: 'Start assessment',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StartScreeningScreen()),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildModernActionCard(
                      icon: Icons.local_hospital,
                      title: 'Browse Centers',
                      subtitle: 'Find specialists',
                      color: AppColors.info,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BrowseCentersScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildModernActionCard(
                      icon: Icons.menu_book,
                      title: 'Resources',
                      subtitle: 'Learning materials',
                      color: AppColors.success,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EducationalResourcesScreen()),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildModernActionCard(
                      icon: Icons.people,
                      title: 'Community',
                      subtitle: 'Connect with others',
                      color: AppColors.accent4,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CommunityScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildModernActionCard(
                      icon: Icons.volunteer_activism,
                      title: 'Support with Donation',
                      subtitle: 'Help other families',
                      color: AppColors.accent3,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DonorDashboardScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Row(
              //   children: [
              //     Expanded(
              //       child: _buildModernActionCard(
              //         icon: Icons.apartment,
              //         title: 'Explore Institutions',
              //         subtitle: 'View profiles, media, team and reviews',
              //         color: AppColors.primary,
              //         onTap: () {
              //           Navigator.push(
              //             context,
              //             MaterialPageRoute(builder: (_) => const BrowseCentersScreen()),
              //           );
              //         },
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === PAYMENT OVERVIEW ===
  // Widget _buildPaymentOverview() {
  //   return Container(
  //     padding: EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: AppColors.surface,
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black12.withOpacity(0.04),
  //           blurRadius: 8,
  //           offset: Offset(0, 2),
  //         )
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Payments ',
  //           style: TextStyle(
  //             fontSize: 16,
  //             fontWeight: FontWeight.bold,
  //             color: AppColors.textDark,
  //           ),
  //         ),
  //         SizedBox(height: 12),
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text(
  //               'Next due: 25 Oct 2025',
  //               style: TextStyle(
  //                 color: AppColors.textGray,
  //                 fontSize: 14,
  //               ),
  //             ),
  //             TextButton(
  //               onPressed: () {},
  //               child: Text(
  //                 'Pay Now ',
  //                 style: TextStyle(
  //                   color: AppColors.primary,
  //                   fontSize: 14,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         SizedBox(height: 8),
  //         LinearProgressIndicator(
  //           value: 0.8,
  //           color: AppColors.primary,
  //           backgroundColor: AppColors.textLight.withOpacity(0.2),
  //           minHeight: 6,
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //         SizedBox(height: 6),
  //         Text(
  //           '80% paid this month',
  //           style: TextStyle(
  //             fontSize: 12,
  //             color: AppColors.textGray,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // === COMMUNITY SECTION ===
  Widget _buildCommunitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Community',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CommunityScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingCommunity)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_communityHighlights.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.forum, size: 40, color: AppColors.textLight),
                SizedBox(height: 8),
                Text(
                  'No recent posts',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Be the first to share in the community',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._communityHighlights.map((post) {
            final content = post['content']?.toString() ?? 'Post content';
            final userName = post['user_name']?.toString() ?? 'Community Member';
            final timeAgo = _getTimeAgo(post['created_at']);
            final likesCount = (post['likes_count'] as num?) ?? 0;
            final commentsCount = (post['comments_count'] as num?) ?? 0;

            return _buildCommunityPost(
              content: content,
              userName: userName,
              timeAgo: timeAgo,
              likesCount: likesCount,
              commentsCount: commentsCount,
            );
          }).toList(),
      ],
    );
  }

  Widget _buildCommunityPost({
    required String content,
    required String userName,
    required String timeAgo,
    required num likesCount,
    required num commentsCount,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.04),
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Icon(Icons.person, size: 16, color: AppColors.primary),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            content.length > 100 ? '${content.substring(0, 100)}...' : content,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textDark,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_outline, size: 14, color: AppColors.textGray),
                  SizedBox(width: 4),
                  Text(
                    '$likesCount',
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Row(
                children: [
                  Icon(Icons.comment_outlined, size: 14, color: AppColors.textGray),
                  SizedBox(width: 4),
                  Text(
                    '$commentsCount',
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === RECENT NOTIFICATIONS FEED ===
  Widget _buildRecentNotificationsFeed() {
    final notifications = dashboardData?.summaries.notifications ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 12),
        ...notifications.map((n) {
          final notification = n is Map ? n : {};
          final title = notification['title']?.toString() ?? 'Notification';
          final time = '2 hours ago';

          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.04),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.notifications_none, color: AppColors.primary, size: 18),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        time,
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // === BOTTOM NAVIGATION ===
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          )
        ],
      ),
      child: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.child_care_outlined), activeIcon: Icon(Icons.child_care), label: 'Children'),
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined), activeIcon: Icon(Icons.local_hospital), label: 'Centers'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
    );
  }

  // === APP BAR ===
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text('Parent Dashboard',
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold)),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificationsScreen()),
                );
              },
            ),
            if (_unreadMessagesCount > 0)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // === DRAWER === ( 
  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Container(
        color: AppColors.surface,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
              color: AppColors.primary.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _buildAvatar(
                        name: dashboardData?.parent.name ?? '',
                        image: dashboardData?.parent.profilePicture ?? '',
                        radius: 32,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showProfileMenu,
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 14,
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dashboardData?.parent.address ?? ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.family_restroom, color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${dashboardData?.children.length ?? 0} Children',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
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
                        MaterialPageRoute(builder: (context) => ManageChildrenScreen()),
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
                        MaterialPageRoute(builder: (context) => SessionsScreen()),
                      );
                    },
                  ),
                  // _buildDrawerItem(
                  //   icon: Icons.assessment,
                  //   title: 'Progress Reports',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //   },
                  // ),
                  _buildDrawerItem(
                    icon: Icons.chat,
                    title: 'Messages',
                    badgeCount: _unreadMessagesCount,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ChatListScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.star,
                    title: 'My Reviews',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MyRatingsScreen()),
                      );
                    },
                  ),
                  // _buildDrawerItem(
                  //   icon: Icons.business,
                  //   title: 'مراجعات المراكز',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     // Navigator.push(
                  //     //   context,
                  //     //   MaterialPageRoute(builder: (context) => const BrowseCentersScreen()),
                  //     // );
                  //   },
                  // ),
                  _buildDrawerItem(
                    icon: Icons.payment,
                    title: 'Payments',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/parent-payment-dashboard');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.volunteer_activism,
                    title: 'Donations',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const BrowseCentersScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: 'Donation History',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ParentDonationHistoryScreen()),
                      );
                    },
                  ),
                    // _buildDrawerItem(
                    //   icon: Icons.volunteer_activism,
                    //   title: 'Free Session Offers',
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) => const ParentFreeSessionsScreen(),
                    //       ),
                    //     );
                    //   },
                    // ),

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
                        MaterialPageRoute(builder: (context) => EducationalResourcesScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.local_hospital,
                    title: 'Centers & Institutions',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BrowseCentersScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.groups,
                    title: 'Parent Workshops',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ParentWorkshopsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'Community',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CommunityScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.flag_outlined,
                    title: 'My Reports',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportsListScreen(
                            scope: ReportsScope.user,
                            title: 'My Reports',
                          ),
                        ),
                      );
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
                        MaterialPageRoute(builder: (context) => ProfileSettingsScreen()),
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
                color: AppColors.error,
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
        color: color ?? AppColors.primary,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: color ?? AppColors.textDark,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: badgeCount != null && badgeCount > 0
          ? Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          badgeCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
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
                  color: AppColors.textLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
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
        color: AppColors.primary,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: AppColors.textDark,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: AppColors.textLight,
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

  String _getTimeAgo(dynamic createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt.toString());
      final difference = DateTime.now().difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return '${(difference.inDays / 7).floor()}w ago';
    } catch (e) {
      return '';
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout', style: TextStyle(color: AppColors.textDark)),
          content: Text('Are you sure you want to logout?', style: TextStyle(color: AppColors.textGray)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _simpleLogout();
              },
              child: Text(
                'Logout',
                style: TextStyle(color: AppColors.error),
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
        builder: (context) => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
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
      }

    } catch (e) {
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
}