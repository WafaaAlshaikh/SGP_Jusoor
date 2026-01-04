// lib/screens/admin/admin_dashboard.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/admin_api_service.dart';
import '../../../theme/app_colors.dart';
import '../../../models/admin_models.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> _dashboardData;
  late Future<Map<String, dynamic>> _recentStats;
  late Future<List<Institution>> _institutions;
  late Future<Map<String, dynamic>> _analytics;
  String? _adminName;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _dashboardData = _loadDashboardData();
    _recentStats = _loadRecentStats();
    _institutions = _loadInstitutions();
    _analytics = _loadAnalyticsOverview();
  }

  Future<Map<String, dynamic>> _loadAnalyticsOverview() async {
    try {
      return await AdminApiService.getAnalyticsOverview(rangeDays: 30);
    } catch (e) {
      return {'success': false};
    }
  }

  Future<List<Institution>> _loadInstitutions() async {
    try {
      final token = await AdminApiService.getToken();
      if (token == null) {
        print('No token found');
        return [];
      }
      
      print('Loading institutions from: ${AdminApiService.baseUrl}/institutions');
      
      final response = await http.get(
        Uri.parse('${AdminApiService.baseUrl}/institutions')
            .replace(queryParameters: {
          'page': '1',
          'limit': '200',
        }),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API response: ${data['success']}');
        
        if (data['success'] != true) {
          print('API returned success false');
          print('Response data: $data');
          return [];
        }
        
        final list = (data['data']?['institutions'] as List?) ?? [];
        print('Found ${list.length} institutions');
        
        // أضف try-catch لكل institution
        final institutions = <Institution>[];
        for (var item in list) {
          try {
            final institution = Institution.fromJson((item as Map).cast<String, dynamic>());
            institutions.add(institution);
          } catch (e) {
            print('Error parsing institution: $e');
            print('Problematic data: $item');
          }
        }
        
        print('Successfully parsed ${institutions.length} institutions');
        return institutions;
      } else {
        print('HTTP Error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error loading institutions: $e');
      print('Error type: ${e.runtimeType}');
      return [];
    }
  }

  Future<void> _loadAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _adminName = prefs.getString('user_name') ?? 'Administration';
    });
  }

  Future<Map<String, dynamic>> _loadDashboardData() async {
    try {
      return await AdminApiService.getDashboardStats();
    } catch (e) {
      print('Error loading dashboard: $e');
      return {
        'success': false,
        'data': {
          'summary': {
            'total_institutions': 0,
            'pending_institutions': 0,
            'total_users': 0,
            'pending_approvals': 0,
            'total_children': 0,
            'total_sessions': 0,
            'total_donations': 0,
            'open_reports': 0,
          }
        }
      };
    }
  }

  Future<Map<String, dynamic>> _loadRecentStats() async {
    try {
      return await AdminApiService.getDetailedStats();
    } catch (e) {
      print('Error loading recent stats: $e');
      return {'success': false};
    }
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, size: 56, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome, ${_adminName ?? "Administration"}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Comprehensive system administration dashboard',
                    style: TextStyle(color: AppColors.textGray, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subTitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: AppColors.textGray, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (subTitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subTitle,
              style: TextStyle(color: AppColors.textGray, fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1, // تم تغييره من 1.25 إلى 1.1
          children: [
            _buildQuickActionButton(
              icon: Icons.business,
              label: 'Institutions',
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, '/institutionManagement'),
            ),
            _buildQuickActionButton(
              icon: Icons.people,
              label: 'Users',
              color: Colors.green,
              onTap: () => Navigator.pushNamed(context, '/userManagement'),
            ),
            _buildQuickActionButton(
              icon: Icons.analytics,
              label: 'Statistics',
              color: Colors.deepPurple,
              onTap: () => Navigator.pushNamed(context, '/detailedStatistics'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8), // تم تخفيض الحجم من 10 إلى 8
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20), // تم تخفيض حجم الأيقونة
            ),
            const SizedBox(height: 6), // تم تخفيضه من 10 إلى 6
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), // تم إضافة fontSize
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return FutureBuilder(
      future: _dashboardData,
      builder: (context, snapshot) {
        final recent = snapshot.data?['data']?['recent_activity'] ?? {};
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Recent Activity (Week)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActivityItem('New Users', recent['new_users']?.toString() ?? '0', Icons.person_add),
                  _buildActivityItem('New Children', recent['new_children']?.toString() ?? '0', Icons.child_friendly),
                  _buildActivityItem('Open Reports', (snapshot.data?['data']?['summary']?['open_reports'] ?? 0).toString(), Icons.flag),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analytics,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final ok = data != null && data['success'] == true;
        final roles = ok ? (data['data']?['user_roles'] as Map?)?.cast<String, dynamic>() : null;
        final statuses = ok ? (data['data']?['institution_statuses'] as Map?)?.cast<String, dynamic>() : null;
        final growthUsers = ok ? (data['data']?['growth']?['users'] as List?) : null;

        final width = MediaQuery.of(context).size.width;
        final isWide = width >= 980;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Analytics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!ok)
                const SizedBox(
                  height: 120,
                  child: Center(child: Text('Analytics unavailable')),
                )
              else
                (isWide)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildRolesDonutChart(roles ?? const {})),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInstitutionStatusBar(statuses ?? const {})),
                          const SizedBox(width: 12),
                          Expanded(child: _buildUsersGrowthLine(growthUsers ?? const [])),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRolesDonutChart(roles ?? const {}),
                          const SizedBox(height: 12),
                          _buildInstitutionStatusBar(statuses ?? const {}),
                          const SizedBox(height: 12),
                          _buildUsersGrowthLine(growthUsers ?? const []),
                        ],
                      ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRolesDonutChart(Map<String, dynamic> roleCounts) {
    final entries = roleCounts.entries
        .map((e) => MapEntry(e.key, int.tryParse(e.value.toString()) ?? 0))
        .where((e) => e.value > 0)
        .toList();

    const palette = <Color>[
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
    ];

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final color = palette[i % palette.length];
      final percent = total == 0 ? 0.0 : (e.value / total) * 100.0;
      sections.add(
        PieChartSectionData(
          value: e.value.toDouble(),
          color: color,
          radius: 48,
          title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Users by role', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 34,
                    sections: sections.isEmpty
                        ? [
                            PieChartSectionData(
                              value: 1,
                              color: Colors.grey.shade300,
                              radius: 48,
                              title: '',
                            )
                          ]
                        : sections,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: palette[i % palette.length],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${entries[i].key} (${entries[i].value})',
                                style: TextStyle(color: AppColors.textGray, fontSize: 12),
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
        ),
      ],
    );
  }

  Widget _buildInstitutionStatusBar(Map<String, dynamic> statusCounts) {
    final entries = statusCounts.entries
        .map((e) => MapEntry(e.key, int.tryParse(e.value.toString()) ?? 0))
        .where((e) => e.value >= 0)
        .toList();

    final labels = entries.map((e) => e.key).toList();
    final maxY = max<double>(1, entries.fold<int>(0, (m, e) => max(m, e.value)).toDouble());

    Color colorFor(String status) {
      final s = status.toLowerCase();
      if (s.contains('approved')) return Colors.green;
      if (s.contains('pending')) return Colors.orange;
      if (s.contains('rejected')) return Colors.red;
      return Colors.blueGrey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Institutions status', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          labels[idx],
                          style: TextStyle(color: AppColors.textGray, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value.toDouble(),
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                        color: colorFor(entries[i].key),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersGrowthLine(List growthRows) {
    final points = <FlSpot>[];
    for (var i = 0; i < growthRows.length; i++) {
      final row = (growthRows[i] as Map).cast<String, dynamic>();
      final c = int.tryParse(row['count']?.toString() ?? '') ?? 0;
      points.add(FlSpot(i.toDouble(), c.toDouble()));
    }

    final maxY = points.isEmpty ? 1.0 : points.map((e) => e.y).reduce(max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('New users (last 30d)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: points.isEmpty ? const [FlSpot(0, 0)] : points,
                  isCurved: true,
                  barWidth: 3,
                  color: AppColors.primary,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withOpacity(0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 20), // حجم الأيقونة
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), // حجم الخط
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.textGray, fontSize: 11)), // حجم الخط
      ],
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'System Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildStatusItem('Database', 'Connected', Colors.green),
          _buildStatusItem('Server', 'Running', Colors.green),
          _buildStatusItem('Memory', 'Normal', Colors.green),
          _buildStatusItem('Updates', 'Up to date', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4), // تم تخفيضه من 6 إلى 4
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textGray), // حجم الخط
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600), // حجم الخط
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionsMapSection() {
  return FutureBuilder<List<Institution>>(
    future: _institutions,
    builder: (context, snapshot) {
      final institutions = snapshot.data ?? const <Institution>[];
      final withCoords = institutions
          .where((i) => i.locationLat != null && i.locationLng != null)
          .toList();
      
      print('🗺️ GoogleMap Debug:');
      print('   Total institutions: ${institutions.length}');
      print('   With coordinates: ${withCoords.length}');
      
      // تحقق من صحة الإحداثيات
      for (var i = 0; i < min(3, withCoords.length); i++) {
        final inst = withCoords[i];
        print('   Institution ${i+1}: ${inst.name}');
        print('     Lat: ${inst.locationLat} (type: ${inst.locationLat?.runtimeType})');
        print('     Lng: ${inst.locationLng} (type: ${inst.locationLng?.runtimeType})');
        
        // تحقق إذا الإحداثيات ضمن المدى الطبيعي
        if (inst.locationLat! < -90 || inst.locationLat! > 90) {
          print('     ⚠️ WARNING: Latitude out of range!');
        }
        if (inst.locationLng! < -180 || inst.locationLng! > 180) {
          print('     ⚠️ WARNING: Longitude out of range!');
        }
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.map, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Institutions Distribution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${withCoords.length}/${institutions.length}',
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              Container(
                height: 200,
                alignment: Alignment.center,
                child: CircularProgressIndicator(),
              )
            else if (institutions.isEmpty)
              Container(
                height: 200,
                alignment: Alignment.center,
                child: Text('No institutions available'),
              )
            else if (withCoords.isEmpty)
              Container(
                height: 200,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off, size: 50, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('No location data available'),
                    Text('Add coordinates to institutions', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    // استخدم إحداثيات أول مؤسسة كمكان بداية
                    target: LatLng(
                      withCoords.first.locationLat!,
                      withCoords.first.locationLng!,
                    ),
                    zoom: 10,
                  ),
                  markers: withCoords
                      .map(
                        (i) => Marker(
                          markerId: MarkerId('inst_${i.institutionId}'),
                          position: LatLng(i.locationLat!, i.locationLng!),
                          infoWindow: InfoWindow(
                            title: i.name,
                            snippet: i.approvalStatus ?? 'No status',
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            i.approvalStatus == 'Approved' 
                              ? BitmapDescriptor.hueGreen
                              : i.approvalStatus == 'Pending'
                                ? BitmapDescriptor.hueOrange
                                : BitmapDescriptor.hueRed,
                          ),
                        ),
                      )
                      .toSet(),
                  mapType: MapType.normal,
                  myLocationEnabled: false,
                  zoomControlsEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    print('🗺️ GoogleMap created successfully!');
                    print('   Markers count: ${withCoords.length}');
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 25, // تم تخفيضه من 30 إلى 25
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 32, // تم تخفيضه من 40 إلى 32
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 8), // تم تخفيضه من 10 إلى 8
                Text(
                  _adminName ?? 'Administration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16, // تم تخفيضه من 18 إلى 16
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'System Administrator',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12, // تم إضافة حجم الخط
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.dashboard, color: AppColors.primary, size: 20),
            title: Text('Dashboard', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.business, color: AppColors.primary, size: 20),
            title: Text('Institutions Management', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/institutionManagement');
            },
          ),
          ListTile(
            leading: Icon(Icons.people, color: AppColors.primary, size: 20),
            title: Text('Users Management', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/userManagement');
            },
          ),
          ListTile(
            leading: Icon(Icons.report, color: AppColors.primary, size: 20),
            title: Text('Reports Management', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/reportManagement');
            },
          ),
          // في _buildDrawer() في admin_dashboard.dart
ListTile(
  leading: Icon(Icons.article, color: AppColors.primary, size: 20),
  title: Text('App Content Management', style: TextStyle(fontSize: 14)),
  onTap: () {
    Navigator.pop(context);
    Navigator.pushNamed(context, '/appContentManagement');
  },
),  
          ListTile(
            leading: Icon(Icons.settings, color: AppColors.primary, size: 20),
            title: Text('System Settings', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/systemSettings');
            },
          ),
          ListTile(
            leading: Icon(Icons.history, color: AppColors.primary, size: 20),
            title: Text('System Logs', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/auditLogs');
            },
          ),
          ListTile(
            leading: Icon(Icons.analytics, color: AppColors.primary, size: 20),
            title: Text('Detailed Statistics', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/detailedStatistics');
            },
          ),
          // ListTile(
          //   leading: Icon(Icons.flag, color: AppColors.primary, size: 20),
          //   title: Text('Content Moderation', style: TextStyle(fontSize: 14)),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.pushNamed(context, '/contentModeration');
          //   },
          // ),
          ListTile(
            leading: Icon(Icons.person, color: AppColors.primary, size: 20),
            title: Text('Profile', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/adminProfile');
            },
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red, size: 20),
            title: Text('Logout', style: TextStyle(fontSize: 14)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18, // تم تخفيضه من 20 إلى 18
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, size: 20),
            onPressed: () {
              Navigator.pushNamed(context, '/adminNotifications');
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, size: 20),
            onPressed: () {
              Navigator.pushNamed(context, '/adminSettings');
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _dashboardData = _loadDashboardData();
            _recentStats = _loadRecentStats();
            _institutions = _loadInstitutions();
            _analytics = _loadAnalyticsOverview();
          });
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(12), // تم تخفيضه من 16 إلى 12
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  _buildWelcomeCard(),
                  SizedBox(height: 16), // تم تخفيضه من 20 إلى 16
                  // Quick Actions Grid
                  _buildQuickActions(),
                  SizedBox(height: 16), // تم تخفيضه من 20 إلى 16
                  // Statistics Cards
                  FutureBuilder(
                    future: _dashboardData,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading data', style: TextStyle(fontSize: 14)));
                      }
                      final data = snapshot.data?['data']?['summary'] ?? {};
                      return GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 10, // تم تخفيضه من 12 إلى 10
                        mainAxisSpacing: 10, // تم تخفيضه من 12 إلى 10
                        childAspectRatio: 1.1, // تم تخفيضه من 1.2 إلى 1.1
                        children: [
                          _buildStatCard(
                            title: 'Institutions',
                            value: data['total_institutions']?.toString() ?? '0',
                            icon: Icons.business,
                            color: Colors.blue,
                            subTitle: '${data['pending_institutions'] ?? 0} pending',
                          ),
                          _buildStatCard(
                            title: 'Users',
                            value: data['total_users']?.toString() ?? '0',
                            icon: Icons.people,
                            color: Colors.green,
                            subTitle: '${data['pending_approvals'] ?? 0} pending approval',
                          ),
                          _buildStatCard(
                            title: 'Children',
                            value: data['total_children']?.toString() ?? '0',
                            icon: Icons.child_care,
                            color: Colors.orange,
                            subTitle: 'Registered in the system',
                          ),
                          _buildStatCard(
                            title: 'Reports',
                            value: data['open_reports']?.toString() ?? '0',
                            icon: Icons.report,
                            color: Colors.red,
                            subTitle: 'Open reports',
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 16), // تم تخفيضه من 20 إلى 16
                  // Analytics
                  _buildAnalyticsSection(),
                  SizedBox(height: 16), // تم تخفيضه من 20 إلى 16
                  // Recent Activity
                  _buildRecentActivity(),
                  SizedBox(height: 16), // تم تخفيضه من 20 إلى 16
                  // Institutions Map
                  _buildInstitutionsMapSection(),
                  SizedBox(height: 16), // تم تخفيضه من 20 إلى 16
                  // System Status
                  // _buildSystemStatus(),
                  // SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showQuickActionsDialog();
        },
        child: Icon(Icons.add, size: 20),
        backgroundColor: AppColors.primary,
        mini: true, // لجعل الزر أصغر
      ),
    );
  }

  void _showQuickActionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quick Actions', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.business, size: 20),
              title: Text('Add New Institution', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                // Navigate to add institution page
              },
            ),
            ListTile(
              leading: Icon(Icons.person_add, size: 20),
              title: Text('Add New User', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                // Navigate to add user page
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, size: 20),
              title: Text('Quick Settings', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/systemSettings');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}