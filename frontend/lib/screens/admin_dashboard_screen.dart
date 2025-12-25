  import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../models/admin_model.dart';
import 'admin_institutions_screen.dart';
import 'admin_users_screen.dart';
import 'admin_settings_screen.dart';
import 'reports_list_screen.dart';
import '../services/reports_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminDashboardStats? _stats;
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedIndex = 0;
  final int _unreadMessagesCount = 3;

  bool _analyticsLoading = false;
  String? _analyticsError;
  String _analyticsRole = 'all';
  int _analyticsYear = DateTime.now().year;
  String _analyticsCity = 'all';
  List<String> _availableCities = ['all'];
  List<Map<String, dynamic>> _userRegistrationsSeries = [];
  List<Map<String, dynamic>> _institutionsByCitySeries = [];

  Map<String, dynamic> _adminProfile = {
    'name': 'Admin User',
    'email': 'admin@speechup.com',
    'role': 'Super Admin',
    'avatar': '',
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
    _loadAdminProfile();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() {
        _analyticsLoading = true;
        _analyticsError = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('Please login again');

      final userReg = await ApiService.getAdminUserRegistrationsAnalytics(
        token: token,
        role: _analyticsRole,
        year: _analyticsYear,
        city: _analyticsCity == 'all' ? null : _analyticsCity,
        groupBy: 'month',
      );

      final instByCity = await ApiService.getAdminInstitutionsByCity(
        token: token,
        status: 'Approved',
        limit: 12,
      );

      final userSeries = ((userReg['data']?['series'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      final instSeries = ((instByCity['data']?['series'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      final cities = <String>{'all'};
      for (final s in instSeries) {
        final label = (s['label'] ?? '').toString().trim();
        if (label.isNotEmpty) cities.add(label);
      }

      setState(() {
        _userRegistrationsSeries = userSeries;
        _institutionsByCitySeries = instSeries;
        _availableCities = cities.toList()..sort();
        if (!_availableCities.contains(_analyticsCity)) {
          _analyticsCity = 'all';
        }
        _analyticsLoading = false;
      });
    } catch (e) {
      setState(() {
        _analyticsError = e.toString();
        _analyticsLoading = false;
      });
    }
  }

  Future<void> _loadAdminProfile() async {
    // Simulate loading admin profile
    await Future.delayed(Duration(milliseconds: 500));
    setState(() {
      _adminProfile = {
        'name': 'Admin User',
        'email': 'admin@speechup.com',
        'role': 'Super Admin',
        'avatar': '',
      };
    });
  }

  Future<void> _loadDashboardStats() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login again';
          _isLoading = false;
        });
        return;
      }

      final stats = await ApiService.getAdminDashboardStats(token);

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading admin dashboard: $e');
      setState(() {
        _errorMessage = 'Failed to load statistics: $e';
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) return;

    Widget? target;
    if (index == 1) {
      target = const AdminUsersScreen();
    } else if (index == 2) {
      target = const AdminInstitutionsScreen();
    } else if (index == 3) {
      target = const ReportsListScreen(
        scope: ReportsScope.admin,
        title: 'All Reports',
      );
    } else if (index == 4) {
      target = const AdminSettingsScreen();
    }

    if (target != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => target!),
      ).then((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
    }
  }

  void _navigateToTab(int index) {
    Navigator.pop(context);
    _onItemTapped(index);
  }

  Widget _buildAvatar({required String name, required String image, double radius = 28}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.3),
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
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _isLoading
          ? _buildLoading()
          : _errorMessage.isNotEmpty
          ? _buildError()
          : _buildDashboard(),
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
              color: AppColors.primary.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _buildAvatar(
                        name: _adminProfile['name'],
                        image: _adminProfile['avatar'],
                        radius: 35,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
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
                    _adminProfile['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _adminProfile['email'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _adminProfile['role'],
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
                    isSelected: true,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'User Management',
                    onTap: () {
                      _navigateToTab(1);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.business,
                    title: 'Institutions',
                    onTap: () {
                      _navigateToTab(2);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.analytics,
                    title: 'Reports & Analytics',
                    onTap: () {
                      _navigateToTab(3);
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.chat,
                    title: 'Support Tickets',
                    badgeCount: _unreadMessagesCount,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportsListScreen(
                            scope: ReportsScope.admin,
                            title: 'Support Tickets',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.payment,
                    title: 'Payment Management',
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
                    title: 'System Settings',
                    onTap: () {
                      _navigateToTab(4);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.security,
                    title: 'Security & Permissions',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.backup,
                    title: 'Backup & Restore',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(height: 1),
                  ),

                  _buildDrawerItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info,
                    title: 'About System',
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
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: color ?? (isSelected ? AppColors.primary : Colors.black87),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: color ?? (isSelected ? AppColors.primary : Colors.black87),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
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
                'Admin Options',
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
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.security,
                title: 'Security Settings',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.notifications,
                title: 'Notification Preferences',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                  ),
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
                _performLogout();
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

  Future<void> _performLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (route) => false,
      );
    } catch (e) {
      print('Logout error: $e');
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(
            Icons.menu,
            color: Colors.white,
            size: 28,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text('Admin Dashboard',
          style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold)),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none, color: Colors.white),
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

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'Loading statistics...',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 64),
          SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 16,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadDashboardStats,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_stats == null) return _buildError();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadDashboardStats();
        await _loadAnalytics();
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            SizedBox(height: 24),
            _buildStatsCards(),
            SizedBox(height: 24),
            _buildAnalyticsSection(),
            SizedBox(height: 24),
            _buildUsersStats(),
            SizedBox(height: 24),
            _buildInstitutionsStats(),
            SizedBox(height: 24),
            _buildQuickActions(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Analytics (by City)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadAnalytics,
                  icon: const Icon(Icons.refresh),
                )
              ],
            ),
            const SizedBox(height: 12),
            _buildAnalyticsFilters(),
            const SizedBox(height: 12),
            if (_analyticsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              )
            else if (_analyticsError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _analyticsError!,
                  style: const TextStyle(color: AppColors.error),
                ),
              )
            else ...[
              _buildUserRegistrationsLineChart(),
              const SizedBox(height: 16),
              _buildInstitutionsByCityBarChart(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _analyticsRole,
                decoration: InputDecoration(
                  labelText: 'Role',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'Parent', child: Text('Parents')),
                  DropdownMenuItem(value: 'Manager', child: Text('Managers')),
                  DropdownMenuItem(value: 'Specialist', child: Text('Specialists')),
                  DropdownMenuItem(value: 'Donor', child: Text('Donors')),
                  DropdownMenuItem(value: 'Admin', child: Text('Admins')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _analyticsRole = v);
                  _loadAnalytics();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _analyticsYear,
                decoration: InputDecoration(
                  labelText: 'Year',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: List.generate(6, (i) {
                  final y = DateTime.now().year - i;
                  return DropdownMenuItem(value: y, child: Text(y.toString()));
                }),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _analyticsYear = v);
                  _loadAnalytics();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _analyticsCity,
          decoration: InputDecoration(
            labelText: 'City',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _availableCities
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c == 'all' ? 'All Cities' : c),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _analyticsCity = v);
            _loadAnalytics();
          },
        ),
      ],
    );
  }

  Widget _buildUserRegistrationsLineChart() {
    final series = _userRegistrationsSeries;
    final maxY = (series.map((e) => (e['value'] ?? 0) as num).fold<num>(0, (a, b) => a > b ? a : b)).toDouble();

    if (series.isEmpty) {
      return const Text('No user registration data');
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < series.length; i++) {
      final v = (series[i]['value'] ?? 0) as num;
      spots.add(FlSpot(i.toDouble(), v.toDouble()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User registrations (monthly)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY <= 0 ? 1 : (maxY * 1.2),
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: AppColors.textGray, fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= series.length) return const SizedBox.shrink();
                      final label = (series[idx]['label'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.12)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstitutionsByCityBarChart() {
    final series = _institutionsByCitySeries;
    if (series.isEmpty) {
      return const Text('No institutions by city data');
    }

    final maxY = (series.map((e) => (e['value'] ?? 0) as num).fold<num>(0, (a, b) => a > b ? a : b)).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Institutions distribution (top cities)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY <= 0 ? 1 : (maxY * 1.2),
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: AppColors.textGray, fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= series.length) return const SizedBox.shrink();
                      final label = (series[idx]['label'] ?? '').toString();
                      final shortLabel = label.length > 6 ? '${label.substring(0, 6)}…' : label;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(shortLabel, style: const TextStyle(color: AppColors.textGray, fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(series.length, (i) {
                final v = (series[i]['value'] ?? 0) as num;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: v.toDouble(),
                      width: 14,
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.primary,
                    )
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, Admin! 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Here\'s what\'s happening with your platform today',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildAvatar(
            name: _adminProfile['name'],
            image: _adminProfile['avatar'],
            radius: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _StatCard(
          title: 'Total Users',
          value: _stats!.totalUsers.toString(),
          icon: Icons.people_outline,
          color: AppColors.info,
          gradient: LinearGradient(
            colors: [AppColors.info, AppColors.info.withOpacity(0.65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        _StatCard(
          title: 'Institutions',
          value: _stats!.totalInstitutions.toString(),
          icon: Icons.business_outlined,
          color: AppColors.success,
          gradient: LinearGradient(
            colors: [AppColors.success, AppColors.success.withOpacity(0.65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        _StatCard(
          title: 'Children',
          value: _stats!.totalChildren.toString(),
          icon: Icons.child_care_outlined,
          color: AppColors.warning,
          gradient: LinearGradient(
            colors: [AppColors.warning, AppColors.warning.withOpacity(0.65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        _StatCard(
          title: 'Sessions',
          value: _stats!.totalSessions.toString(),
          icon: Icons.event_note_outlined,
          color: AppColors.error,
          gradient: LinearGradient(
            colors: [AppColors.error, AppColors.error.withOpacity(0.65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ],
    );
  }

  Widget _buildUsersStats() {
    final entries = _stats!.usersByRole.entries.where((e) => e.value > 0).toList();
    final total = _stats!.totalUsers;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'User Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 520;
                final chart = SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 55,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      sections: entries.map((e) {
                        final color = _getRoleColor(e.key);
                        final percent = total == 0 ? 0.0 : (e.value / total * 100);
                        return PieChartSectionData(
                          color: color,
                          value: e.value.toDouble(),
                          radius: 60,
                          title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );

                final legend = Column(
                  children: entries
                      .map(
                        (e) => _UserRoleItem(
                          role: _getRoleName(e.key),
                          count: e.value.toString(),
                          percentage: (total == 0 ? 0 : (e.value / total * 100)).toStringAsFixed(1),
                          color: _getRoleColor(e.key),
                        ),
                      )
                      .toList(),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      chart,
                      const SizedBox(height: 12),
                      legend,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: chart),
                    const SizedBox(width: 16),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionsStats() {
    final approved = _stats!.institutionStats['approved'] ?? 0;
    final pending = _stats!.institutionStats['pending'] ?? 0;
    final rejected = _stats!.institutionStats['rejected'] ?? 0;
    final total = (approved + pending + rejected);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surface,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Institution Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (total > 0) ...[
              SizedBox(
                height: 170,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 52,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        color: AppColors.success,
                        value: approved.toDouble(),
                        radius: 58,
                        title: approved == 0 ? '' : '${(approved / total * 100).toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      PieChartSectionData(
                        color: AppColors.warning,
                        value: pending.toDouble(),
                        radius: 58,
                        title: pending == 0 ? '' : '${(pending / total * 100).toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      PieChartSectionData(
                        color: AppColors.error,
                        value: rejected.toDouble(),
                        radius: 58,
                        title: rejected == 0 ? '' : '${(rejected / total * 100).toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _InstitutionStatItem(
                    status: 'Active',
                    count: _stats!.institutionStats['approved']?.toString() ?? '0',
                    color: AppColors.success,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _InstitutionStatItem(
                    status: 'Pending',
                    count: _stats!.institutionStats['pending']?.toString() ?? '0',
                    color: AppColors.warning,
                    icon: Icons.pending_actions_outlined,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _InstitutionStatItem(
                    status: 'Rejected',
                    count: _stats!.institutionStats['rejected']?.toString() ?? '0',
                    color: AppColors.error,
                    icon: Icons.cancel_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surface,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickActionButton(
                  icon: Icons.business,
                  label: 'Manage Institutions',
                  color: AppColors.info,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminInstitutionsScreen(),
                      ),
                    );
                  },
                ),
                _QuickActionButton(
                  icon: Icons.people,
                  label: 'Manage Users',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminUsersScreen(),
                      ),
                    );
                  },
                ),
                _QuickActionButton(
                  icon: Icons.analytics,
                  label: 'Reports',
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportsListScreen(
                          scope: ReportsScope.admin,
                          title: 'All Reports',
                        ),
                      ),
                    );
                  },
                ),
                _QuickActionButton(
                  icon: Icons.settings,
                  label: 'System Settings',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
        BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Institutions'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
    );
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'Parent': return 'Parents';
      case 'Specialist': return 'Specialists';
      case 'Manager': return 'Managers';
      case 'Admin': return 'Admins';
      default: return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Parent': return Color(0xFF2196F3);
      case 'Specialist': return Color(0xFF4CAF50);
      case 'Manager': return Color(0xFFFF9800);
      case 'Admin': return Color(0xFF9C27B0);
      default: return Color(0xFF666666);
    }
  }
}

// Helper Components
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Gradient gradient;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRoleItem extends StatelessWidget {
  final String role;
  final String count;
  final String percentage;
  final Color color;

  const _UserRoleItem({
    required this.role,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              role,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '$percentage%',
            style: TextStyle(
              color: Color(0xFF999999),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionStatItem extends StatelessWidget {
  final String status;
  final String count;
  final Color color;
  final IconData icon;

  const _InstitutionStatItem({
    required this.status,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}