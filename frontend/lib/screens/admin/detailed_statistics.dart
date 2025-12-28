// lib/screens/admin/detailed_statistics.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/admin_api_service.dart';
import '../../theme/app_colors.dart';

class DetailedStatistics extends StatefulWidget {
  @override
  _DetailedStatisticsState createState() => _DetailedStatisticsState();
}

class _DetailedStatisticsState extends State<DetailedStatistics> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  DateTimeRange? _dateRange;
  List<String> _availableYears = ['2024', '2023', '2022'];
  int _selectedChartIndex = 0;
  final List<String> _chartTypes = ['Bar', 'Line', 'Pie'];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      setState(() => _isLoading = true);
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final Map<String, String> queryParams = {};
      if (_dateRange != null) {
        queryParams['start_date'] = _dateRange!.start.toIso8601String();
        queryParams['end_date'] = _dateRange!.end.toIso8601String();
      }

      final response = await http.get(
        Uri.parse('${AdminApiService.baseUrl}/detailed-stats').replace(
          queryParameters: queryParams,
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _stats = data['data'] ?? {};
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load statistics');
      }
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load statistics'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = _dateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(Duration(days: 30)),
          end: DateTime.now(),
        );
    
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textWhite,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadStats();
    }
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        final cleanString = value.replaceAll(RegExp(r'[^0-9\.\-]'), '');
        return double.parse(cleanString);
      } catch (e) {
        print('Error parsing double from string: $value, error: $e');
        return 0.0;
      }
    }
    return 0.0;
  }

  String _formatAmount(dynamic amount) {
    final value = _safeToDouble(amount);
    return value.toStringAsFixed(2);
  }

  Widget _buildStatCard(String title, dynamic value, IconData icon, Color color) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 120,
        maxWidth: 160,
        minHeight: 110,
        maxHeight: 130,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), AppColors.cardColor.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent2, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: AppColors.textWhite),
              ),
              SizedBox(height: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 4),
              Flexible(
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                    shadows: [
                      Shadow(
                        blurRadius: 2,
                        color: Colors.black12,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(String title, List<dynamic> data, String key1, String key2) {
    if (data.isEmpty) {
      return _buildEmptyChart(title);
    }
    
    final maxValue = data.map((e) => _safeToDouble(e[key2])).reduce((a, b) => a > b ? a : b);
    
    final List<BarChartGroupData> barGroups = List.generate(
      data.length,
      (index) => BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: _safeToDouble(data[index][key2]),
            gradient: LinearGradient(
              colors: [AppColors.blue, AppColors.primary],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 28,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxValue,
              color: AppColors.background.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
    
    final List<String> xLabels = data.map((item) {
      final value = item[key1].toString();
      if (value.length > 6) {
        return value.substring(0, 6);
      }
      return value;
    }).toList();

    return _buildChartContainer(
      title,
      Container(
        height: 250,
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
                strokeWidth: 1,
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
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Transform.rotate(
                          angle: -0.3,
                          child: Text(
                            xLabels[value.toInt()],
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }
                    return Text('');
                  },
                  reservedSize: 32,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                  reservedSize: 40,
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
                    TextStyle(color: AppColors.textWhite, fontSize: 12),
                    children: [
                      TextSpan(
                        text: '${rod.toY.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
      AppColors.primary,
    );
  }

  Widget _buildLineChart(String title, List<dynamic> data, String key1, String key2) {
    if (data.isEmpty) {
      return _buildEmptyChart(title);
    }
    
    final List<FlSpot> spots = List.generate(
      data.length,
      (index) => FlSpot(
        index.toDouble(),
        _safeToDouble(data[index][key2]),
      ),
    );

    final maxValue = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    
    final List<String> xLabels = data.map((item) {
      final value = item[key1].toString();
      if (value.length > 6) {
        return value.substring(0, 6);
      }
      return value;
    }).toList();

    return _buildChartContainer(
      title,
      Container(
        height: 250,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.green,
                barWidth: 4,
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
                      radius: 4,
                      color: AppColors.textWhite,
                      strokeWidth: 2,
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
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: AppColors.accent1,
                strokeWidth: 1,
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
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Transform.rotate(
                          angle: -0.3,
                          child: Text(
                            xLabels[value.toInt()],
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }
                    return Text('');
                  },
                  reservedSize: 32,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                  reservedSize: 40,
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
                      '${xLabels[barSpot.x.toInt()]}\n',
                      TextStyle(color: AppColors.textWhite, fontSize: 12),
                      children: [
                        TextSpan(
                          text: '${barSpot.y.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
      AppColors.green,
    );
  }

  Widget _buildPieChart(String title, List<dynamic> data, String key1, String key2) {
    if (data.isEmpty) {
      return _buildEmptyChart(title);
    }
    
    final total = data.fold<double>(0, (sum, item) => sum + _safeToDouble(item[key2]));
    
    final List<PieChartSectionData> sections = List.generate(
      data.length,
      (index) {
        final value = _safeToDouble(data[index][key2]);
        final percentage = ((value / total) * 100).toStringAsFixed(1);
        final color = _getChartColor(index);
        
        return PieChartSectionData(
          color: color,
          value: value,
          title: '$percentage%',
          radius: 80,
          titleStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
            shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
          ),
          badgeWidget: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.8),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          badgePositionPercentageOffset: 0.98,
        );
      },
    );

    return _buildChartContainer(
      title,
      Container(
        height: 300,
        child: Stack(
          children: [
            PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 50,
                sectionsSpace: 2,
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                  Text(
                    total.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      AppColors.primaryDark,
    );
  }

  Widget _buildEmptyChart(String title) {
    return _buildChartContainer(
      title,
      Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 64, color: AppColors.textLight),
              SizedBox(height: 16),
              Text(
                'No data available',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
      AppColors.textLight,
    );
  }

  Widget _buildChartContainer(String title, Widget chart, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.accent2, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.timeline, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        _chartTypes[_selectedChartIndex],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            chart,
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final userStats = _stats['user_statistics'] ?? [];
    final institutionStats = _stats['institution_statistics'] ?? [];
    final monthlyDonations = _stats['monthly_donations'] ?? [];
    final monthlySessions = _stats['monthly_sessions'] ?? [];
    final topInstitutions = _stats['top_institutions'] ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.analytics, color: AppColors.textWhite),
            SizedBox(width: 12),
            Text(
              'Detailed Statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.textWhite.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.date_range, size: 22, color: AppColors.textWhite),
            ),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Select date range',
          ),
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.textWhite.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh, size: 22, color: AppColors.textWhite),
            ),
            onPressed: () => _loadStats(),
            tooltip: 'Refresh data',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.blue, AppColors.primary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.textWhite,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Loading Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait while we fetch your data',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Info
                  if (_dateRange != null)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accent1, AppColors.cardColor],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.date_range, color: AppColors.textWhite, size: 20),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Selected Date Range',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '${_dateRange!.start.toLocal().toString().substring(0, 10)} - ${_dateRange!.end.toLocal().toString().substring(0, 10)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.blue, AppColors.primary],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TextButton(
                                onPressed: () => _selectDateRange(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 14, color: AppColors.textWhite),
                                    SizedBox(width: 4),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textWhite,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  SizedBox(height: 24),
                  
                  // User Statistics Section
                  Row(
                    children: [
                      Icon(Icons.people_alt, color: AppColors.primary, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'User Statistics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: userStats.length,
                    itemBuilder: (context, index) {
                      final stat = userStats[index];
                      return _buildStatCard(
                        stat['role'] ?? 'Unknown',
                        stat['count'] ?? 0,
                        _getRoleIcon(stat['role'] ?? ''),
                        _getRoleColor(stat['role'] ?? ''),
                      );
                    },
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Institution Statistics
                  if (institutionStats.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.business, color: AppColors.blue, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Institution Status',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: institutionStats.length,
                        itemBuilder: (context, index) {
                          final stat = institutionStats[index];
                          return Padding(
                            padding: EdgeInsets.only(right: 16),
                            child: _buildStatCard(
                              stat['approval_status'] ?? 'Unknown',
                              stat['count'] ?? 0,
                              Icons.business_center,
                              _getStatusColor(stat['approval_status'] ?? ''),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                  
                  // Charts Section
                  Row(
                    children: [
                      Icon(Icons.insights, color: AppColors.ment, size: 24),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Analytics & Charts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Spacer(),
                      Container(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: SegmentedButton<int>(
                          segments: _chartTypes.asMap().entries.map((entry) {
                            return ButtonSegment<int>(
                              value: entry.key,
                              label: Text(
                                entry.value,
                                style: TextStyle(fontSize: 11),
                              ),
                              icon: Icon(_getChartTypeIcon(entry.key), size: 16),
                            );
                          }).toList(),
                          selected: {_selectedChartIndex},
                          onSelectionChanged: (Set<int> newSelection) {
                            setState(() {
                              _selectedChartIndex = newSelection.first;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  
                  // Charts based on selected type
                  if (monthlyDonations.isNotEmpty)
                    _selectedChartIndex == 0 
                      ? _buildBarChart('Monthly Donations', monthlyDonations, 'month', 'total')
                      : _selectedChartIndex == 1
                        ? _buildLineChart('Monthly Donations Trend', monthlyDonations, 'month', 'total')
                        : _buildPieChart('Donations Distribution', monthlyDonations, 'month', 'total'),
                  
                  SizedBox(height: 24),
                  
                  if (monthlySessions.isNotEmpty)
                    _buildLineChart('Monthly Sessions Trend', monthlySessions, 'month', 'count'),
                  
                  SizedBox(height: 32),
                  
                  // Top Institutions
                  if (topInstitutions.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.emoji_events, color: AppColors.green, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Top Donating Institutions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: AppColors.accent2, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            ...topInstitutions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final inst = entry.value;
                              final isTop3 = index < 3;
                              
                              return Container(
                                margin: EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isTop3 
                                    ? _getTop3Color(index).withOpacity(0.1)
                                    : AppColors.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isTop3 
                                      ? _getTop3Color(index).withOpacity(0.3)
                                      : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: isTop3
                                        ? LinearGradient(
                                            colors: [
                                              _getTop3Color(index),
                                              _getTop3Color(index).withOpacity(0.7),
                                            ],
                                          )
                                        : null,
                                      color: isTop3 ? null : AppColors.accent1,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isTop3 ? AppColors.textWhite : AppColors.textGray,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    inst['Institution']?['name'] ?? 'Unknown Institution',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Icon(Icons.monetization_on, size: 14, color: AppColors.green),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${_formatAmount(inst['total_donations'])} JOD',
                                          style: TextStyle(
                                            color: AppColors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent1,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 40),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _exportStatistics();
        },
        icon: Icon(Icons.share, color: AppColors.textWhite),
        label: Text('Export', style: TextStyle(color: AppColors.textWhite)),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        elevation: 4,
        splashColor: AppColors.blue,
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Parent': return Icons.family_restroom;
      case 'Specialist': return Icons.medical_services;
      case 'Manager': return Icons.manage_accounts;
      case 'Donor': return Icons.handshake;
      case 'Admin': return Icons.admin_panel_settings;
      default: return Icons.person;
    }
  }

  IconData _getChartTypeIcon(int index) {
    switch (index) {
      case 0: return Icons.bar_chart;
      case 1: return Icons.show_chart;
      case 2: return Icons.pie_chart;
      default: return Icons.bar_chart;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Parent': return AppColors.blue;
      case 'Specialist': return AppColors.green;
      case 'Manager': return AppColors.ment;
      case 'Donor': return AppColors.darkGreen;
      case 'Admin': return AppColors.primaryDark;
      default: return AppColors.textGray;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return AppColors.warning;
      case 'Approved': return AppColors.success;
      case 'Rejected': return AppColors.error;
      case 'Suspended': return AppColors.red;
      default: return AppColors.textGray;
    }
  }

  Color _getTop3Color(int index) {
    switch (index) {
      case 0: return AppColors.primary;
      case 1: return AppColors.green;
      case 2: return AppColors.blue;
      default: return AppColors.ment;
    }
  }

  void _exportStatistics() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Export Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 20),
              _buildExportOption(
                context,
                Icons.picture_as_pdf,
                'PDF Document',
                'High quality PDF report',
                AppColors.red,
                () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Preparing PDF export...'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
              ),
              _buildExportOption(
                context,
                Icons.table_chart,
                'Excel Spreadsheet',
                'Data in spreadsheet format',
                AppColors.success,
                () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Preparing Excel export...'),
                      backgroundColor: AppColors.green,
                    ),
                  );
                },
              ),
              _buildExportOption(
                context,
                Icons.image,
                'Image (PNG)',
                'Chart images',
                AppColors.blue,
                () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Preparing image export...'),
                      backgroundColor: AppColors.blue,
                    ),
                  );
                },
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportOption(BuildContext context, IconData icon, String title,
      String subtitle, Color color, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent2),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: AppColors.textGray),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color),
        onTap: onTap,
      ),
    );
  }
}