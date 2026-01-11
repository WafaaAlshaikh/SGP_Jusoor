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
  
  // Chart Control Variables
  Map<String, int> _selectedChartIndices = {
    'roles': 0,
    'status': 0,
    'growth': 0,
  };
  final List<String> _chartTypes = ['Bar', 'Line', 'Pie'];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _dashboardData = _loadDashboardData();
    _recentStats = _loadRecentStats();
    _institutions = _loadInstitutions();
    _analytics = _loadAnalyticsOverview();
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        final cleanString = value.replaceAll(RegExp(r'[^0-9\.\-]'), '');
        return double.parse(cleanString);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  Color _getChartColor(int index) {
    final colors = [
      AppColors.primary,
      AppColors.green,
      AppColors.ment,
      AppColors.blue,
      AppColors.red,
      AppColors.warning,
      AppColors.darkGreen,
      AppColors.accent4,
    ];
    return colors[index % colors.length];
  }

  Widget _buildEmptyChart(String title) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent2, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: AppColors.textLight),
            SizedBox(height: 12),
            Text(
              'No data available',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(String title, Map<String, dynamic> data, String chartKey) {
    final entries = data.entries
        .map((e) => MapEntry(e.key, _safeToDouble(e.value)))
        .where((e) => e.value > 0)
        .toList();

    if (entries.isEmpty) {
      return _buildEmptyChart(title);
    }

    final maxValue = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final xLabels = entries.map((e) => e.key).toList();

    final List<BarChartGroupData> barGroups = List.generate(
      entries.length,
      (index) => BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entries[index].value,
            gradient: LinearGradient(
              colors: [_getChartColor(index), _getChartColor(index).withOpacity(0.8)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 24,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxValue,
              color: AppColors.background.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent2, width: 1),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Bar',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.accent3, width: 1),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.accent1,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < xLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Transform.rotate(
                              angle: -0.3,
                              child: Text(
                                xLabels[value.toInt()],
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }
                        return Text('');
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (bar) => AppColors.primary.withOpacity(0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${xLabels[group.x.toInt()]}\n',
                        TextStyle(color: AppColors.textWhite, fontSize: 11),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(String title, List<dynamic> data, String chartKey) {
    if (data.isEmpty) {
      return _buildEmptyChart(title);
    }
    
    final List<FlSpot> spots = List.generate(
      data.length,
      (index) {
        final row = (data[index] as Map).cast<String, dynamic>();
        return FlSpot(
          index.toDouble(),
          _safeToDouble(row['count']),
        );
      },
    );

    final maxValue = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent2, width: 1),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.show_chart, size: 12, color: AppColors.green),
                    SizedBox(width: 4),
                    Text(
                      'Line',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.green,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.green.withOpacity(0.3),
                          AppColors.green.withOpacity(0.1),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.textWhite,
                          strokeWidth: 1.5,
                          strokeColor: AppColors.green,
                        );
                      },
                    ),
                    gradient: LinearGradient(
                      colors: [AppColors.ment, AppColors.green],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ],
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.accent3, width: 1),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.accent1,
                    strokeWidth: 0.5,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: AppColors.accent1,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                minY: 0,
                maxY: maxValue * 1.1,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (bar) => AppColors.green.withOpacity(0.9),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          'Day ${barSpot.x.toInt() + 1}\n',
                          TextStyle(color: AppColors.textWhite, fontSize: 11),
                          children: [
                            TextSpan(
                              text: '${barSpot.y.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(String title, Map<String, dynamic> data, String chartKey) {
    final entries = data.entries
        .map((e) => MapEntry(e.key, _safeToDouble(e.value)))
        .where((e) => e.value > 0)
        .toList();

    if (entries.isEmpty) {
      return _buildEmptyChart(title);
    }
    
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    
    final List<PieChartSectionData> sections = List.generate(
      entries.length,
      (index) {
        final value = entries[index].value;
        final percentage = ((value / total) * 100).toStringAsFixed(1);
        final color = _getChartColor(index);
        
        return PieChartSectionData(
          color: color,
          value: value,
          title: value >= (total * 0.05) ? '$percentage%' : '',
          radius: 60,
          titleStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
            shadows: [Shadow(color: Colors.black38, blurRadius: 1)],
          ),
        );
      },
    );

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent2, width: 1),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.pie_chart, size: 12, color: AppColors.primaryDark),
                    SizedBox(width: 4),
                    Text(
                      'Pie',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 30,
                      sectionsSpace: 1,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < min(entries.length, 5); i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getChartColor(i),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${entries[i].key}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textGray,
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
          ),
        ],
      ),
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
              Column(
                children: [
                  // Chart Type Selector for Roles
                  Row(
                    children: [
                      Icon(Icons.person, color: AppColors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Users by Role',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      _buildCompactChartSelector('roles'),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Dynamic Chart based on selection
                  _selectedChartIndices['roles'] == 0
                    ? _buildBarChart('Users by Role', roles ?? {}, 'roles')
                    : _selectedChartIndices['roles'] == 1
                      ? _buildLineChart('Users Growth', growthUsers ?? [], 'growth')
                      : _buildPieChart('Users Distribution', roles ?? {}, 'roles'),
                  
                  SizedBox(height: 24),
                  
                  // Chart Type Selector for Institution Status
                  Row(
                    children: [
                      Icon(Icons.business, color: AppColors.ment, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Institutions Status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      _buildCompactChartSelector('status'),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Dynamic Chart based on selection
                  _selectedChartIndices['status'] == 0
                    ? _buildBarChart('Institutions Status', statuses ?? {}, 'status')
                    : _selectedChartIndices['status'] == 1
                      ? Container(height: 200, child: Center(child: Text('No historical data available')))
                      : _buildPieChart('Status Distribution', statuses ?? {}, 'status'),
                  
                  SizedBox(height: 24),
                  
                  // Chart Type Selector for Growth
                  if (growthUsers != null && growthUsers.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.trending_up, color: AppColors.green, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'User Growth (Last 30 Days)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        _buildCompactChartSelector('growth'),
                      ],
                    ),
                    SizedBox(height: 12),
                    // Dynamic Chart based on selection
                    _selectedChartIndices['growth'] == 0
                      ? _buildBarChart('Daily User Growth', _prepareGrowthData(growthUsers), 'growth')
                      : _selectedChartIndices['growth'] == 1
                        ? _buildLineChart('User Growth Trend', growthUsers, 'growth')
                        : _buildPieChart('Growth Distribution', _prepareGrowthData(growthUsers), 'growth'),
                  ],
                ],
              ),
          ],
        ),
      );
    },
  );
}

// دالة مساعدة لبناء أداة اختيار المخطط المضغوطة
Widget _buildCompactChartSelector(String type) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey[300]!, width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: _chartTypes.asMap().entries.map((entry) {
        final isSelected = _selectedChartIndices[type] == entry.key;
        return Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blue : Colors.transparent,
            borderRadius: _getBorderRadius(entry.key, _chartTypes.length),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedChartIndices[type] = entry.key;
                });
              },
              borderRadius: _getBorderRadius(entry.key, _chartTypes.length),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Tooltip(
                  message: entry.value,
                  child: Icon(
                    entry.key == 0 
                      ? Icons.bar_chart 
                      : entry.key == 1 
                        ? Icons.show_chart 
                        : Icons.pie_chart,
                    size: 18,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

// دالة مساعدة لتحديد border radius لكل زر
BorderRadius _getBorderRadius(int index, int totalItems) {
  if (totalItems == 1) {
    return BorderRadius.circular(8);
  }
  
  if (index == 0) {
    return BorderRadius.only(
      topLeft: Radius.circular(8),
      bottomLeft: Radius.circular(8),
    );
  } else if (index == totalItems - 1) {
    return BorderRadius.only(
      topRight: Radius.circular(8),
      bottomRight: Radius.circular(8),
    );
  } else {
    return BorderRadius.zero;
  }
}

// دالة مساعدة لإعداد بيانات النمو
Map<String, dynamic> _prepareGrowthData(List<dynamic> growthUsers) {
  final Map<String, dynamic> result = {};
  
  if (growthUsers != null && growthUsers.isNotEmpty) {
    // تحويل البيانات إلى التنسيق المناسب
    for (var item in growthUsers) {
      if (item is Map && item.containsKey('date') && item.containsKey('count')) {
        result[item['date'].toString()] = item['count'];
      }
    }
  }
  
  return result;
}

  // باقي الدوال الموجودة سابقاً تبقى كما هي...
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
          childAspectRatio: 1.1,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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

  Widget _buildActivityItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.textGray, fontSize: 11)),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textGray),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
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
                    onMapCreated: (GoogleMapController controller) {},
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
                  radius: 25,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _adminName ?? 'Administration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'System Administrator',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
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
            fontSize: 18,
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
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  _buildWelcomeCard(),
                  SizedBox(height: 16),
                  // Quick Actions Grid
                  _buildQuickActions(),
                  SizedBox(height: 16),
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
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.1,
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
                  SizedBox(height: 16),
                  // Analytics
                  _buildAnalyticsSection(),
                  SizedBox(height: 16),
                  // Recent Activity
                  _buildRecentActivity(),
                  SizedBox(height: 16),
                  // Institutions Map
                  _buildInstitutionsMapSection(),
                  SizedBox(height: 16),
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
        mini: true,
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
                Navigator.pushNamed(context, '/institutionManagement');
              },
            ),
            ListTile(
              leading: Icon(Icons.person_add, size: 20),
              title: Text('Add New User', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/userManagement');
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