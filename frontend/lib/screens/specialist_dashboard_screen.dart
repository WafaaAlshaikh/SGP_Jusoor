import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/specialist_api.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'package:frontend/screens/specialist_sessions_screen.dart';
import 'package:frontend/screens/specialist_children_screen.dart';
import 'package:frontend/screens/add_evaluation_screen.dart';
import 'package:frontend/screens/full_vacation_request_screen.dart';
import 'package:frontend/screens/evaluations_screen.dart';
import 'package:frontend/screens/add_session_screen.dart';
import 'package:frontend/screens/community_screen.dart';
import 'package:frontend/screens/create_post_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/about_screen.dart';
import 'package:frontend/screens/help_support_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/screens/notifications_screen.dart';
import 'package:frontend/screens/chat_list_screen.dart';
import 'package:frontend/screens/ai_insights_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/activity_service.dart';

class SpecialistDashboardScreen extends StatefulWidget {
  const SpecialistDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SpecialistDashboardScreen> createState() =>
      _SpecialistDashboardScreenState();
}

class _SpecialistDashboardScreenState extends State<SpecialistDashboardScreen> {
  Map<String, dynamic> dashboardData = {};
  bool isLoading = true;
  List<dynamic> imminentSessions = [];
  bool hasImminentSessions = false;
  Timer? _sessionCheckTimer;
  Timer? _activitiesRefreshTimer;

  List<Map<String, dynamic>> recentActivities = [];
  final int unreadMessagesCount = 2;

  // 🔥 تحديد إذا كان على ويب أو موبايل
  bool get isWeb => MediaQuery.of(context).size.width > 600;

  @override
  void initState() {
    super.initState();
    fetchData();
    _startAutoRefresh();
    _loadRecentActivities();
    _startActivitiesAutoRefresh();
    _checkAndAddSampleActivities();
  }

  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    _activitiesRefreshTimer?.cancel();
    super.dispose();
  }

  void _startActivitiesAutoRefresh() {
    _activitiesRefreshTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _loadRecentActivities();
    });
  }

  Future<void> _loadRecentActivities() async {
    try {
      final activities = await ActivityService.getLast3Activities();

      if (_hasActivitiesChanged(activities)) {
        setState(() {
          recentActivities = activities;
        });
      }
    } catch (e) {
      print('❌ Error loading activities: $e');
    }
  }

  bool _hasActivitiesChanged(List<Map<String, dynamic>> newActivities) {
    if (recentActivities.length != newActivities.length) {
      return true;
    }

    for (int i = 0; i < recentActivities.length; i++) {
      final oldActivity = recentActivities[i];
      final newActivity = newActivities[i];

      final oldTime = oldActivity['time'] ?? '';
      final newTime = newActivity['time'] ?? '';
      final oldTitle = oldActivity['title'] ?? '';
      final newTitle = newActivity['title'] ?? '';

      if (oldTime != newTime || oldTitle != newTitle) {
        return true;
      }
    }

    return false;
  }

  void _startAutoRefresh() {
    checkImminentSessions();
    _sessionCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      checkImminentSessions();
    });
  }

  Future<void> _refreshAllData() async {
    try {
      await Future.wait([
        fetchData(),
        checkImminentSessions(),
        _loadRecentActivities(),
      ]);
    } catch (e) {
      print('❌ Error during refresh: $e');
    }
  }
  Future<void> _checkAndAddSampleActivities() async {
    try {
      final activities = await ActivityService.getLast3Activities();
      if (activities.isEmpty) {
        // إضافة أنشطة تجريبية فقط إذا لم يكن هناك أنشطة
        await ActivityService.addSampleActivities();
        // إعادة تحميل الأنشطة
        _loadRecentActivities();
      }
    } catch (e) {
      print('❌ Error checking sample activities: $e');
    }
  }
  Future<void> fetchData() async {
    try {
      final profile = await SpecialistService.getProfileInfo();
      final upcomingCount = await SpecialistService.getUpcomingSessionsCount();
      final childrenCount = await SpecialistService.getChildrenCount();

      // 🔥 طباعة معلومات الصورة للديبقنق
      print('🖼️ Avatar URL: ${profile['avatar']}');
      print('🖼️ Avatar type: ${profile['avatar']?.runtimeType}');
      print('🖼️ Avatar is null: ${profile['avatar'] == null}');
      print('🖼️ Avatar is empty: ${profile['avatar']?.toString().isEmpty}');

      setState(() {
        dashboardData = {
          'name': profile['name'],
          'avatar': profile['avatar'],
          'upcomingSessionsCount': upcomingCount,
          'childrenCount': childrenCount,
        };
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching dashboard data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> checkImminentSessions() async {
    try {
      final result = await SessionService.getImminentSessions();

      if (result['success'] == true) {
        final sessionsIn5Min = List<dynamic>.from(result['sessionsIn5Min'] ?? []);
        final sessionsIn10Min = List<dynamic>.from(result['sessionsIn10Min'] ?? []);

        final allSessions = [...sessionsIn5Min, ...sessionsIn10Min];

        setState(() {
          imminentSessions = allSessions;
          hasImminentSessions = allSessions.isNotEmpty;
        });
      }
    } catch (e) {
      print('❌ Error checking imminent sessions: $e');
    }
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSessionDetailsSheet(session),
    );
  }

  Widget _buildSessionDetailsSheet(Map<String, dynamic> session) {
    final bool isOnline = session['session_type'] == 'Online';
    final bool hasZoomMeeting = session['zoomMeeting'] != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Session Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          _buildSessionInfoItem(
            'Child',
            session['child']['full_name'] ?? 'Unknown',
            Icons.person,
          ),
          _buildSessionInfoItem(
            'Time',
            '${session['date']} at ${session['time'].substring(0, 5)}',
            Icons.access_time,
          ),
          _buildSessionInfoItem(
            'Type',
            session['session_type'],
            isOnline ? Icons.videocam : Icons.location_on,
          ),
          if (session['institution'] != null && session['institution']['name'] != null)
            _buildSessionInfoItem(
              'Institution',
              session['institution']['name'],
              Icons.business,
            ),
          const SizedBox(height: 20),
          if (isOnline && hasZoomMeeting)
            _buildActionButton(
              'Join Zoom Meeting',
              Icons.video_call,
              AppColors.primary,
                  () {
                Navigator.pop(context);
                _launchZoomMeeting(session['zoomMeeting']['join_url']);
              },
            )
          else if (isOnline)
            _buildActionButton(
              'Create Zoom Meeting',
              Icons.add,
              AppColors.primary,
                  () {
                Navigator.pop(context);
              },
            )
          else
            _buildActionButton(
              'View Session Details',
              Icons.info,
              AppColors.primary,
                  () {
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 10),
          _buildActionButton(
            'Close',
            Icons.close,
            Colors.grey,
                () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoItem(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchZoomMeeting(String joinUrl) async {
    try {
      if (await canLaunchUrl(Uri.parse(joinUrl))) {
        await launchUrl(
          Uri.parse(joinUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showZoomLinkDialog(joinUrl);
      }
    } catch (e) {
      _showZoomLinkDialog(joinUrl);
    }
  }

  void _showZoomLinkDialog(String joinUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Join Zoom Meeting'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Copy this link and open it in your browser:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  joinUrl,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _copyToClipboard(joinUrl);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
              child: const Text('Copy Link'),
            ),
          ],
        );
      },
    );
  }

  void _copyToClipboard(String text) async {
    print('📋 Link to copy: $text');
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🔥 بناء واجهة مختلفة للويب
    if (isWeb) {
      return _buildWebLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // 🔥 واجهة الويب
  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // 🔥 السايدبار للويب
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: _buildWebSidebar(),
          ),
          // 🔥 المحتوى الرئيسي
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAllData,
              color: AppColors.primary,
              backgroundColor: AppColors.background,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔥 كروت الملخص للويب
                    _buildWebSummaryCards(),
                    const SizedBox(height: 32),
                    // 🔥 الإجراءات السريعة للويب
                    _buildWebQuickActions(),
                    const SizedBox(height: 32),
                    // 🔥 النشاط الحديث للويب
                    _buildWebRecentActivity(),

                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: hasImminentSessions ? _buildFloatingCTA() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // 🔥 واجهة الموبايل
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        color: AppColors.primary,
        backgroundColor: AppColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(),
              const SizedBox(height: 27),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildRecentActivityFeed(),
            ],
          ),
        ),
      ),
      floatingActionButton: hasImminentSessions ? _buildFloatingCTA() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // 🔥 السايدبار للويب
  Widget _buildWebSidebar() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 🔥 الهيدر
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 40, bottom: 24, left: 20, right: 20),
            color: AppColors.primary.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 بدل CircleAvatar استخدمي WebSafeImage
                WebSafeImage(
                  imageUrl: dashboardData['avatar'],
                  size: 80, // للويب
                  fallbackIcon: Icons.person,
                ),
                const SizedBox(height: 16),
                Text(
                  dashboardData['name'] ?? 'Specialist',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Speech Therapist',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          // 🔥 القائمة
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildWebDrawerItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: true,
                  onTap: () {},
                ),
                _buildWebDrawerItem(
                  icon: Icons.assessment,
                  title: 'Evaluations',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EvaluationsScreen()));
                  },
                ),
                _buildWebDrawerItem(
                  icon: Icons.calendar_today,
                  title: 'Sessions',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistSessionsScreen()));
                  },
                ),
                _buildWebDrawerItem(
                  icon: Icons.people,
                  title: 'My Children',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistChildrenScreen()));
                  },
                ),
                _buildWebDrawerItem(
                  icon: Icons.chat,
                  title: 'Messages',
                  badgeCount: unreadMessagesCount,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatListScreen()));
                  },
                ),
                _buildWebDrawerItem(
                  icon: Icons.article,
                  title: 'Community',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CommunityScreen()));
                  },
                ),
                _buildWebDrawerItem(
                  icon: Icons.psychology,
                  title: 'AI Insights',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AIInsightsScreen()));
                  },
                ),
                const SizedBox(height: 20),
                const Divider(),
                _buildWebDrawerItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen())),
                ),
                _buildWebDrawerItem(
                  icon: Icons.help,
                  title: 'Help & Support',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HelpSupportScreen())),
                ),
                _buildWebDrawerItem(
                  icon: Icons.info,
                  title: 'About',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AboutScreen())),
                ),
                const SizedBox(height: 20),
                _buildWebDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  color: Colors.red,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    int? badgeCount,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? (isSelected ? AppColors.primary : AppColors.textDark), size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            color: color ?? (isSelected ? AppColors.primary : AppColors.textDark),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // 🔥 كروت الملخص للويب
  Widget _buildWebSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _SummaryCard(
          icon: Icons.calendar_month,
          title: 'Upcoming Sessions',
          count: dashboardData['upcomingSessionsCount'] ?? 0,
          buttonText: 'View ➔',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistSessionsScreen())),
        ),
        _SummaryCard(
          icon: Icons.people,
          title: 'My Children',
          count: dashboardData['childrenCount'] ?? 0,
          buttonText: 'View ➔',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistChildrenScreen())),
        ),
        _SummaryCard(
          icon: Icons.mail_outline,
          title: 'New Messages',
          count: unreadMessagesCount,
          buttonText: 'Open ➔',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatListScreen())),
        ),
        _SummaryCard(
          icon: Icons.psychology_outlined,
          title: 'AI Insights',
          count: 3,
          buttonText: 'Explore ➔',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AIInsightsScreen())),
        ),
      ],
    );
  }

  // 🔥 الإجراءات السريعة للويب
  Widget _buildWebQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.5,
          children: [
            _QuickActionButton(
              icon: Icons.add_circle_outline,
              text: 'Add Session',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddSessionScreen())),
            ),
            _QuickActionButton(
              icon: Icons.edit_note,
              text: 'New Evaluation',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddEvaluationScreen())),
            ),
            _QuickActionButton(
              icon: Icons.article_outlined,
              text: 'New Post',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreatePostScreen())),
            ),
            _QuickActionButton(
              icon: Icons.beach_access,
              text: 'Vacation Request',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VacationRequestScreen())),
            ),
          ],
        ),
      ],
    );
  }

  // 🔥 النشاط الحديث للويب
  Widget _buildWebRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recent Activity",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: recentActivities.isEmpty
              ? _buildEmptyActivityState()
              : Column(
            children: recentActivities.map((activity) => _buildActivityItem(activity)).toList(),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: isWeb ? null : Builder(builder: (context) => IconButton(
        icon: const Icon(Icons.menu, color: Colors.white, size: 28),
        onPressed: () => Scaffold.of(context).openDrawer(),
      )),
      title: Text(
        dashboardData['name'] ?? 'Specialist Dashboard',
        style: const TextStyle(color: AppColors.background, fontSize: 21),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: AppColors.background),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                );
              },
            ),
            if (unreadMessagesCount > 0)
              const Positioned(
                right: 11,
                top: 11,
                child: Icon(Icons.circle, color: Colors.red, size: 10),
              ),
          ],
        ),
      ],
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
              color: AppColors.primary.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔥 بدل CircleAvatar استخدمي WebSafeImage
                  WebSafeImage(
                    imageUrl: dashboardData['avatar'],
                    size: 80, // للويب
                    fallbackIcon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    dashboardData['name'] ?? 'Specialist',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Speech Therapist',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '4.8 (124 reviews)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textDark.withOpacity(0.7),
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
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDrawerItem(
                    icon: Icons.assessment,
                    title: 'Evaluations',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => EvaluationsScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_today,
                    title: 'Sessions',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistSessionsScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'My Children',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistChildrenScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.chat,
                    title: 'Messages',
                    badgeCount: 0,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.article,
                    title: 'Community',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CommunityScreen()));
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(height: 1),
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen())),
                  ),
                  _buildDrawerItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HelpSupportScreen())),
                  ),
                  _buildDrawerItem(
                    icon: Icons.info,
                    title: 'About',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AboutScreen())),
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
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
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
      leading: Icon(icon, color: color ?? AppColors.primary, size: 22),
      title: Text(title, style: TextStyle(fontSize: 16, color: color ?? AppColors.textDark, fontWeight: FontWeight.w500)),
      trailing: badgeCount != null && badgeCount > 0 ? Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
        child: Text(badgeCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ) : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildSummaryCards() {
    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(width: MediaQuery.of(context).size.width * 0.6, child: _SummaryCard(icon: Icons.calendar_month, title: 'Upcoming Sessions ', count: dashboardData['upcomingSessionsCount'] ?? 0, buttonText: 'View ➔', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistSessionsScreen())))),
          SizedBox(width: MediaQuery.of(context).size.width * 0.6, child: _SummaryCard(icon: Icons.people, title: 'My Children', count: dashboardData['childrenCount'] ?? 0, buttonText: 'View ➔', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistChildrenScreen())))),
          SizedBox(width: MediaQuery.of(context).size.width * 0.6, child: _SummaryCard(icon: Icons.mail_outline, title: 'New Messages', count: unreadMessagesCount, buttonText: 'Open Messages ➔', onTap: () {})),
          SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: _SummaryCard(
                  icon: Icons.psychology_outlined,
                  title: 'AI Insight Center',
                  count: 3,
                  buttonText: 'View  ➔',
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AIInsightsScreen()
                        )
                    );
                  }
              )
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Quick Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      const SizedBox(height: 12),
      Wrap(spacing: 20, runSpacing: 14, children: [
        _QuickActionButton(icon: Icons.add_circle_outline, text: 'Add Session', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddSessionScreen()))),
        _QuickActionButton(icon: Icons.edit_note, text: 'New Evaluation', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddEvaluationScreen()))),
        _QuickActionButton(icon: Icons.article_outlined, text: 'New Post/Article', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreatePostScreen()))),
        _QuickActionButton(icon: Icons.beach_access, text: 'Vacation Request', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VacationRequestScreen()))),
      ]),
    ]);
  }

  Widget _buildRecentActivityFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
            "Recent Activity",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)
        ),
        const SizedBox(height: 12),

        if (recentActivities.isEmpty)
          _buildEmptyActivityState()
        else
          ...recentActivities.map((activity) => _buildActivityItem(activity)).toList(),
      ],
    );
  }

  Widget _buildEmptyActivityState() {
    return const ListTile(
      leading: Icon(Icons.history, color: Colors.grey),
      title: Text(
        'No recent activity',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final iconCode = activity['iconCode'] ?? 'history';
    final icon = ActivityService.getIconFromCode(iconCode);
    final time = _getTimeAgo(activity['time']);

    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        activity['title'] ?? 'No title',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(time, style: TextStyle(color: AppColors.textGray, fontSize: 12)),
      contentPadding: EdgeInsets.symmetric(vertical: 4 , horizontal: 16),
    );
  }

  String _getTimeAgo(String? timeString) {
    if (timeString == null) return 'Recently';

    try {
      final time = DateTime.parse(timeString);
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';

      return '${time.day}/${time.month}/${time.year}';
    } catch (e) {
      return 'Recently';
    }
  }

  Widget _buildFloatingCTA() {
    final firstSession = imminentSessions.isNotEmpty ? imminentSessions.first : null;
    final bool isOnline = firstSession != null && firstSession['session_type'] == 'Online';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: SizedBox(
        width: double.infinity,
        child: FloatingActionButton.extended(
          onPressed: () => firstSession != null ? _showSessionDetails(firstSession) : null,
          label: Text(isOnline ? 'Start Online Session' : 'Upcoming Session', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          icon: Icon(isOnline ? Icons.video_call : Icons.access_time, color: Colors.white),
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return isWeb ? const SizedBox.shrink() : BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Sessions'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'My Children'),
        BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Messages'),
      ],
      currentIndex: 0,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textGray,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        switch (index) {
          case 1: Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistSessionsScreen())); break;
          case 2: Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialistChildrenScreen())); break;
        }
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final String buttonText;
  final VoidCallback onTap;
  final String? insightText;

  const _SummaryCard({required this.icon, required this.title, required this.count, required this.buttonText, required this.onTap, this.insightText});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [
        Icon(icon, color: AppColors.primary, size: 36),
        const SizedBox(height: 8),
        if (insightText == null) Text('$count', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark))
        else Text(insightText!, style: const TextStyle(fontSize: 12, color: AppColors.textGray), maxLines: 3, overflow: TextOverflow.ellipsis),
        Text(title, style: const TextStyle(fontSize: 16, color: AppColors.textGray)),
        const SizedBox(height: 2),
        TextButton(onPressed: onTap, child: Text(buttonText)),
      ])),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: Container(
      width: 175,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500)),
      ]),
    ));
  }
}

class RefreshController {}

class WebSafeImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final IconData fallbackIcon;

  const WebSafeImage({
    Key? key,
    required this.imageUrl,
    this.size = 80,
    this.fallbackIcon = Icons.person,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.primary.withOpacity(0.1),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Image load error: $error');
            return _buildFallback();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        fallbackIcon,
        size: size * 0.5,
        color: AppColors.primary,
      ),
    );
  }
}