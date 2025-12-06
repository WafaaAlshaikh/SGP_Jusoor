import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_specialist_api_service.dart';
import '../../services/manager_stats_service.dart';
import '../../services/manager_vacation_service.dart';
import './specialists_list_screen.dart';
import './session_types_screen.dart';
import './specialist_schedule_screen.dart';
import './add_session_screen.dart';
import './vacation_screen.dart';
class SpecialistManagementScreen extends StatefulWidget {
  @override
  _SpecialistManagementScreenState createState() => _SpecialistManagementScreenState();
}

class _SpecialistManagementScreenState extends State<SpecialistManagementScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _specialistsList = [];
  List<Map<String, dynamic>> _vacationRequests = [];
  List<Map<String, dynamic>> _sessionTypeRequests = [];
  List<Map<String, dynamic>> _sessionTypeStats = []; // جديد: إحصائيات أنواع الجلسات

  int _selectedChartIndex = 0;
  List<bool> _chartTypeSelected = [true, false]; // ⬅️ تغيير: صار 2 بدل 3

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  // دالة مساعدة لتحويل القيم إلى double
  double? _parseDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is String) {
      // إزالة أي أحرف غير رقمية
      final cleanString = value.replaceAll(RegExp(r'[^0-9\.]'), '');
      return double.tryParse(cleanString);
    }

    return null;
  }

  // دالة مساعدة لتحويل حالة الموافقة
  String _mapStatus(String? approvalStatus) {
    switch (approvalStatus?.toLowerCase()) {
      case 'approved': return 'Active';
      case 'pending': return 'Pending';
      case 'rejected': return 'Inactive';
      default: return 'Unknown';
    }
  }

  // دالة مساعدة لتنسيق التاريخ
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is String) {
      try {
        final dateTime = DateTime.parse(date);
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } catch (e) {
        return date.toString();
      }
    }
    return date.toString();
  }
  List<Map<String, dynamic>> _convertToListOfMaps(List<dynamic> list) {
    return list.map((item) {
      if (item is Map<String, dynamic>) {
        return item;
      } else if (item is Map<dynamic, dynamic>) {
        return Map<String, dynamic>.from(item);
      } else if (item is Map) {
        return Map<String, dynamic>.from(item);
      } else {
        return <String, dynamic>{};
      }
    }).toList();
  }
  int _convertToInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  Future<void> _loadRealData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // جلب الإحصائيات الشاملة
      final statsResponse = await ManagerStatsService.getComprehensiveStats();

      // جلب الأخصائيين
      final specialistsResponse = await ManagerSpecialistApiService.getRequest('/manager/specialists');

      // جلب طلبات الإجازة
      final vacationResponse = await ManagerVacationService.getAllVacationRequests();

      // جلب أنواع الجلسات قيد الانتظار
      final sessionTypesResponse = await ManagerSpecialistApiService.getRequest('/manager/session-types/pending');

      // جلب إحصائيات الأخصائيين حسب نوع الجلسة ⬅️ جديد
      final sessionTypeStatsResponse = await ManagerStatsService.getSpecialistsBySessionType();

      setState(() {
        // تحديث الإحصائيات
        final statsData = statsResponse['data'] ?? {};
        _stats = {
          'totalSpecialists': statsData['active_specialists'] ?? 0,
          'activeSpecialists': statsData['active_specialists'] ?? 0,
          'absentToday': statsData['vacation_statistics'] != null
              ? (statsData['vacation_statistics']['absent_today'] ?? 0)
              : 0,
          'vacationRequests': statsData['vacation_statistics'] != null
              ? (statsData['vacation_statistics']['total_requests'] ?? 0)
              : 0,
          'sessionTypeRequests': sessionTypesResponse['data'] != null
              ? (sessionTypesResponse['data']['total_pending'] ?? 0)
              : 0,
          'averageSessions': _parseDouble(statsData['average_sessions_per_day']) ?? 0.0,
          'totalSessionsMonth': statsData['total_sessions_last_30_days'] ?? 0,
        };

        // تحديث قائمة الأخصائيين (أول 3 فقط)
        final specialistsData = specialistsResponse['data'] ?? {};
        final allSpecialists = specialistsData['all_specialists'] as List? ?? [];

        _specialistsList = allSpecialists.take(3).map((spec) {
          return {
            'id': spec['specialist_id'].toString(),
            'name': spec['personal_info']['full_name'],
            'specialty': spec['professional_info']['specialization'],
            'status': _mapStatus(spec['professional_info']['approval_status']),
            'sessionsThisMonth': 0, // سيتم تحديثه من sessionTypeStats
            'salary': _parseDouble(spec['professional_info']['salary']) ?? 0.0,
            'rating': 4.5, // افتراضي
            'childrenAssigned': 0, // افتراضي
            'nextVacation': 'N/A', // سيتم تحديثه لاحقاً
            'schedule': spec['has_schedules'] ? 'Has Schedule' : 'No Schedule',
          };
        }).toList();

        // تحديث طلبات الإجازة (أول 2 فقط)
        final vacationData = vacationResponse['data'] ?? {};
        final allVacationRequests = vacationData['vacation_requests'] as List? ?? [];

        _vacationRequests = allVacationRequests
            .where((req) => req['status'] == 'Pending')
            .take(2)
            .map((req) {
          final totalDays = req['total_days'] ?? 1;
          return {
            'id': req['request_id'].toString(),
            'specialistName': req['specialist']['full_name'],
            'vacationType': 'Annual Leave', // افتراضي
            'duration': '$totalDays days',
            'startDate': _formatDate(req['start_date']),
            'endDate': _formatDate(req['end_date']),
            'compensation': 'Paid', // افتراضي
            'status': req['status'],
            'notes': req['reason'] ?? 'No reason provided',
            'priority': totalDays > 7 ? 'High' : 'Medium',
            'request_id': req['request_id'], // للحاجة المستقبلية
          };
        }).toList();

        // تحديث أنواع الجلسات (أول 1 فقط)
        final sessionTypesData = sessionTypesResponse['data'] ?? {};
        final pendingSessionTypes = sessionTypesData['session_types'] as List? ?? [];

        _sessionTypeRequests = pendingSessionTypes.take(1).map((st) {
          return {
            'id': st['session_type_id'].toString(),
            'specialistName': st['created_by']?['full_name'] ?? 'Unknown',
            'sessionType': st['name'],
            'category': st['category'],
            'duration': '${st['duration']} min',
            'price': _parseDouble(st['price']) ?? 0.0,
            'targetConditions': (st['target_conditions'] as List?)?.cast<String>() ?? [],
            'status': st['approval_status'],
            'requestDate': _formatDate(st['created_at']),
            'session_type_id': st['session_type_id'], // للحاجة المستقبلية
          };
        }).toList();

        // تحديث إحصائيات أنواع الجلسات
        final sessionStatsData = sessionTypeStatsResponse['data'] as List? ?? [];
        _sessionTypeStats = _convertToListOfMaps(sessionStatsData);

        // تحديث عدد جلسات كل أخصائي من البيانات الجديدة
        _updateSpecialistsSessionCount();

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading real data: $e');
      setState(() {
        _isLoading = false;
      });

      // إظهار رسالة خطأ للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load data. Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _updateSpecialistsSessionCount() {
    final Map<int, int> specialistSessions = {};

    for (var sessionType in _sessionTypeStats) {
      final specialists = sessionType['specialists'] as List? ?? [];
      for (var specialist in specialists) {
        final specialistId = _convertToInt(specialist['specialist_id']);
        final sessionCount = _convertToInt(specialist['session_count'] ?? 0);

        if (specialistSessions.containsKey(specialistId)) {
          specialistSessions[specialistId] = specialistSessions[specialistId]! + sessionCount;
        } else {
          specialistSessions[specialistId] = sessionCount;
        }
      }
    }

    for (var specialist in _specialistsList) {
      final specialistId = int.tryParse(specialist['id']);
      if (specialistId != null && specialistSessions.containsKey(specialistId)) {
        specialist['sessionsThisMonth'] = specialistSessions[specialistId]!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingScreen() : _buildContent(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Specialists Management',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
          onPressed: _loadRealData,
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
          onPressed: () => _showAddSpecialistDialog(),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Loading Data from Server...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Column(
        children: [
          // Statistics Section with Charts
          _buildStatisticsCharts(),
          SizedBox(height: 20),

          // Quick Stats Cards
          _buildQuickStats(),
          SizedBox(height: 20),

          // Action Buttons
          _buildActionButtons(),
          SizedBox(height: 20),

          // Specialists List
          _buildSpecialistsList(),
          SizedBox(height: 20),

          // Vacation Requests
          if (_vacationRequests.isNotEmpty) ...[
            _buildVacationRequests(),
            SizedBox(height: 20),
          ],

          // Session Type Requests
          if (_sessionTypeRequests.isNotEmpty) ...[
            _buildSessionTypeRequests(),
            SizedBox(height: 30),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticsCharts() {
    // الحصول على توزيع الأخصائيين حسب نوع الجلسة من البيانات الحقيقية
    final specialtyDistribution = _getSpecialtyDistributionFromSessionTypes();
    final totalSpecialists = _stats['totalSpecialists'] ?? 1;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
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
                'Specialists Analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Live Data',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Chart Type Selector - تم التعديل ليكون نوعين فقط
          _buildChartTypeSelector(),
          SizedBox(height: 20),

          // Chart Container
          Container(
            height: 220,
            child: _selectedChartIndex == 0
                ? _buildSpecialtyPieChart(specialtyDistribution, totalSpecialists)
                : _buildSessionsBarChart(),
          ),
          SizedBox(height: 20),

          // Chart Legend
          _buildChartLegend(specialtyDistribution),
        ],
      ),
    );
  }

  // ⬅️ دالة جديدة: الحصول على توزيع الأخصائيين من البيانات الحقيقية
  Map<String, int> _getSpecialtyDistributionFromSessionTypes() {
    final Map<String, int> distribution = {};

    for (var sessionType in _sessionTypeStats) {
      final sessionTypeName = sessionType['session_type_name']?.toString() ?? 'Unknown';
      final totalSpecialists = sessionType['total_specialists'] ?? 0;

      if (totalSpecialists > 0) {
        distribution[sessionTypeName] = totalSpecialists;
      }
    }

    return distribution;
  }

  Widget _buildChartTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 8),
          _buildChartTypeButton('Specialists by Session Type', 0),
          SizedBox(width: 8),
          _buildChartTypeButton('Sessions by Specialist', 1),
          SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildChartTypeButton(String label, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChartIndex = index;
          _chartTypeSelected = List.generate(2, (i) => i == index); // ⬅️ تغيير
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: _chartTypeSelected[index] ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _chartTypeSelected[index] ? AppColors.primary : AppColors.accent4,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _chartTypeSelected[index] ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialtyPieChart(Map<String, int> distribution, int total) {
    List<PieChartSectionData> sections = [];
    List<Color> colors = [
      AppColors.primary,
      AppColors.ment,
      AppColors.warning,
      AppColors.info,
      Color(0xFF9C27B0),
      Color(0xFF607D8B),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
    ];

    int index = 0;
    distribution.forEach((sessionType, count) {
      if (count > 0) {
        sections.add(
          PieChartSectionData(
            color: colors[index % colors.length],
            value: count.toDouble(),
            title: '${((count / total) * 100).round()}%',
            radius: 45,
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        );
        index++;
      }
    });

    return sections.isNotEmpty
        ? PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 40,
        sections: sections,
      ),
    )
        : Center(
      child: Text(
        'No data available',
        style: TextStyle(color: AppColors.textGray),
      ),
    );
  }

  Widget _buildSessionsBarChart() {
    // الحصول على بيانات الجلسات من الأخصائيين
    List<Map<String, dynamic>> sessionsData = _getSessionsDataFromSpecialists();

    if (sessionsData.isEmpty) {
      return Center(
        child: Text(
          'No session data available',
          style: TextStyle(color: AppColors.textGray),
        ),
      );
    }

    // حساب أعلى قيمة للـ Y-axis مع إضافة هامش
    final maxSessionCount = sessionsData
        .map((d) => d['sessions'])
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    // قائمة الألوان المختلفة لكل عمود
    List<Color> barColors = [
      AppColors.primary,
      AppColors.ment,
      AppColors.warning,
      AppColors.info,
      Color(0xFF9C27B0),
      Color(0xFF607D8B),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF795548),
      Color(0xFF009688),
      Color(0xFF673AB7),
      Color(0xFF3F51B5),
    ];

    return Container(
      width: double.maxFinite,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: EdgeInsets.only(right: 20),
          width: (sessionsData.length * 60).toDouble(), // عرض ديناميكي حسب عدد الأخصائيين
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxSessionCount + (maxSessionCount * 0.2), // هامش 20% للأعلى
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final specialist = sessionsData[group.x.toInt()];
                    return BarTooltipItem(
                      '${specialist['fullName']}\n',
                      TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toInt()} sessions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sessionsData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Transform.rotate(
                            angle: -0.3, // تدوير النص ليكون مائلاً
                            child: Text(
                              sessionsData[index]['name'],
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        '${value.toInt()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.accent1,
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: AppColors.accent1, width: 1),
                  left: BorderSide(color: AppColors.accent1, width: 1),
                ),
              ),
              barGroups: sessionsData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;

                // لون مختلف لكل عمود (استخدام modulo للبقاء ضمن حدود القائمة)
                Color barColor = barColors[index % barColors.length];

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data['sessions'].toDouble(),
                      color: barColor,
                      width: 25, // عرض أكبر للأعمدة
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxSessionCount + (maxSessionCount * 0.2),
                        color: AppColors.accent1.withOpacity(0.1),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend(Map<String, int> distribution) {
    // في حالة عرض توزيع الأخصائيين حسب نوع الجلسة
    if (_selectedChartIndex == 0) {
      final entries = distribution.entries.toList();
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: entries.map((entry) {
          return _buildLegendItem(
            entry.key,
            _getColorForSessionType(entry.key, entries.indexOf(entry)),
            entry.value,
          );
        }).toList(),
      );
    }
    // في حالة عرض الجلسات حسب الأخصائي
    else {
      final sessionsData = _getSessionsDataFromSpecialists();
      if (sessionsData.isEmpty) {
        return SizedBox.shrink();
      }

      // قائمة الألوان المختلفة
      List<Color> legendColors = [
        AppColors.primary,
        AppColors.ment,
        AppColors.warning,
        AppColors.info,
        Color(0xFF9C27B0),
        Color(0xFF607D8B),
        Color(0xFF4CAF50),
        Color(0xFFFF9800),
        Color(0xFF795548),
        Color(0xFF009688),
      ];

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: sessionsData.take(10).map((data) { // عرض أول 10 أخصائيين
            final index = sessionsData.indexOf(data);
            Color barColor = legendColors[index % legendColors.length];

            return Padding(
              padding: EdgeInsets.only(right: 10),
              child: _buildLegendItem(
                data['name'],
                barColor,
                data['sessions'],
              ),
            );
          }).toList(),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getSessionsDataFromSpecialists() {
    final Map<String, int> specialistSessions = {};

    // جمع بيانات جميع الأخصائيين من أنواع الجلسات
    for (var sessionType in _sessionTypeStats) {
      final specialists = sessionType['specialists'] as List? ?? [];
      for (var specialist in specialists) {
        final specialistName = specialist['full_name'];
        final int sessionCount = _convertToInt(specialist['session_count'] ?? 0);

        if (specialistSessions.containsKey(specialistName)) {
          specialistSessions[specialistName] = (specialistSessions[specialistName] ?? 0) + sessionCount;
        } else {
          specialistSessions[specialistName] = sessionCount;
        }
      }
    }

    // تحويل الخريطة إلى قائمة
    final List<Map<String, dynamic>> sessionsData = [];

    specialistSessions.forEach((name, count) {
      sessionsData.add({
        'name': name.split(' ').last, // عرض الاسم الأخير فقط
        'fullName': name, // حفظ الاسم الكامل
        'sessions': count,
      });
    });

    // ترتيب تنازلي حسب عدد الجلسات
    sessionsData.sort((a, b) => b['sessions'].compareTo(a['sessions']));

    return sessionsData;
  }



  Color _getColorForSessionType(String sessionType, int index) {
    final colors = [
      AppColors.primary,
      AppColors.ment,
      AppColors.warning,
      AppColors.info,
      Color(0xFF9C27B0),
      Color(0xFF607D8B),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
    ];

    return colors[index % colors.length];
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              label.length > 15 ? '${label.substring(0, 12)}...' : label,
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 4),
          Text(
            '($value)',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _buildStatCard(
            'Active Specialists',
            _stats['activeSpecialists']?.toString() ?? '0',
            Icons.people_alt_rounded,
            AppColors.primary,
          ),
          _buildStatCard(
            'Absent Today',
            _stats['absentToday']?.toString() ?? '0',
            Icons.person_off_rounded,
            AppColors.error,
          ),
          _buildStatCard(
            'Vacation Requests',
            _stats['vacationRequests']?.toString() ?? '0',
            Icons.beach_access_rounded,
            AppColors.warning,
          ),
          _buildStatCard(
            'Session Types',
            _sessionTypeStats.length.toString(),
            Icons.list_alt_rounded,
            Color(0xFF9C27B0),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color cardColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 3),
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
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: cardColor, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: cardColor,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 0.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildActionButton(
                'Add Specialist',
                Icons.person_add_alt_1_rounded,
                AppColors.primary,
                    () => _showAddSpecialistDialog(),
              ),
              _buildActionButton(
                'Session Types',
                Icons.list_alt_rounded,
                Color(0xFF9C27B0),
                    () => _navigateToSessionTypes(),
              ),
              _buildActionButton(
                'View Schedule',
                Icons.schedule_rounded,
                Color(0xFF2196F3),
                    () => _navigateToSchedules(),
              ),
              _buildActionButton(
                'Add Session',
                Icons.add_circle_rounded,
                Color(0xFF4CAF50),
                    () => _navigateToAddSession(),
              ),
              _buildActionButton(
                'All Specialists',
                Icons.people_rounded,
                Color(0xFFFF9800),
                    () => _navigateToAllSpecialists(),
              ),
              _buildActionButton(
                'Vacations',
                Icons.beach_access_rounded,
                AppColors.warning,
                    () => _navigateToVacation(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialistsList() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
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
                'Recent Specialists',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              TextButton(
                onPressed: () => _navigateToAllSpecialists(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(50, 30),
                ),
                child: Text(
                  'View All →',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_specialistsList.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No specialists found',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._specialistsList.map((specialist) => _buildSpecialistItem(specialist)).toList(),
        ],
      ),
    );
  }

  Widget _buildSpecialistItem(Map<String, dynamic> specialist) {
    Color statusColor = _getStatusColor(specialist['status']);

    return GestureDetector(
      onTap: () => _editSpecialist(specialist),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.03),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.person_rounded,
                  size: 30,
                  color: statusColor,
                ),
              ),
            ),
            SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          specialist['name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          specialist['status'],
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '${specialist['specialty']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),

                  // ⬅️ التعديل: جعل Chips قابلة للتمرير
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildInfoChip('${specialist['sessionsThisMonth']} sessions', Icons.event_note_rounded),
                        SizedBox(width: 8),
                        _buildInfoChip('\$${specialist['salary']}', Icons.attach_money_rounded),
                        SizedBox(width: 8),
                        _buildInfoChip('${specialist['rating']}', Icons.star_rounded),
                        SizedBox(width: 8),
                        if (specialist['childrenAssigned'] > 0) ...[
                          _buildInfoChip('${specialist['childrenAssigned']} children', Icons.child_care_rounded),
                          SizedBox(width: 8),
                        ],
                        if (specialist['nextVacation'] != 'N/A') ...[
                          _buildInfoChip('Vacation: ${specialist['nextVacation']}', Icons.beach_access_rounded),
                          SizedBox(width: 8),
                        ],
                        _buildInfoChip(specialist['schedule'], Icons.schedule_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textGray),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacationRequests() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
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
                'Pending Vacations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              TextButton(
                onPressed: () => _viewAllVacations(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(50, 30),
                ),
                child: Text(
                  'View All →',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_vacationRequests.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No pending vacation requests',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._vacationRequests.map((request) => _buildVacationRequestItem(request)).toList(),
        ],
      ),
    );
  }

  Widget _buildVacationRequestItem(Map<String, dynamic> request) {
    Color priorityColor = request['priority'] == 'High'
        ? Color(0xFFFF6B6B)
        : Color(0xFFFFA726);

    return GestureDetector(
      onTap: () => _handleVacationRequest(request),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: priorityColor.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: priorityColor.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.beach_access_rounded,
                  color: priorityColor,
                  size: 24,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          request['specialistName'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          request['priority'],
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${request['vacationType']} • ${request['duration']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${request['startDate']} - ${request['endDate']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTypeRequests() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
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
                'New Session Types',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              TextButton(
                onPressed: () => _navigateToSessionTypes(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(50, 30),
                ),
                child: Text(
                  'View All →',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_sessionTypeRequests.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No pending session type requests',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._sessionTypeRequests.map((request) => _buildSessionTypeRequestItem(request)).toList(),
        ],
      ),
    );
  }

  Widget _buildSessionTypeRequestItem(Map<String, dynamic> request) {
    return GestureDetector(
      onTap: () => _handleSessionTypeRequest(request),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFF9C27B0).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF9C27B0).withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(0xFF9C27B0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.list_alt_rounded,
                  color: Color(0xFF9C27B0),
                  size: 24,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request['sessionType'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'By: ${request['specialistName']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${request['duration']} • \$${request['price']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 8),
                  if ((request['targetConditions'] as List).isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: (request['targetConditions'] as List<dynamic>)
                          .take(2)
                          .map((condition) {
                        return Chip(
                          label: Text(
                            condition.toString(),
                            style: TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Color(0xFFE1BEE7),
                          labelPadding: EdgeInsets.symmetric(horizontal: 8),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === دوال التنقل ===

  void _navigateToAllSpecialists() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialistsListScreen(),
      ),
    );
  }

  void _navigateToSessionTypes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionTypesScreen(),
      ),
    );
  }

  void _navigateToSchedules() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialistScheduleScreen(),
      ),
    );
  }

  void _navigateToVacation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VacationScreen(),
      ),
    );
  }

  void _navigateToAddSession() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSessionScreen(),
      ),
    );
  }

  void _showAddSpecialistDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController emailController = TextEditingController();
    TextEditingController phoneController = TextEditingController();
    TextEditingController specializationController = TextEditingController();
    TextEditingController experienceController = TextEditingController();
    TextEditingController salaryController = TextEditingController();

    String? selectedSpecialization;

    // استخراج أنواع الجلسات من البيانات الحقيقية فقط
    List<String> specializationsList = [];

    if (_sessionTypeStats.isNotEmpty) {
      for (var sessionType in _sessionTypeStats) {
        final sessionTypeName = sessionType['session_type_name']?.toString();
        if (sessionTypeName != null && sessionTypeName.isNotEmpty) {
          // إضافة فقط إذا كان الاسم موجود وغير مكرر
          if (!specializationsList.contains(sessionTypeName)) {
            specializationsList.add(sessionTypeName);
          }
        }
      }
    }

    // فرز القائمة أبجدياً
    specializationsList.sort();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.primary.withOpacity(0.1), width: 1),
            ),
            title: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add New Specialist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 16),

                    // Full Name Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: nameController,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                          labelText: 'Full Name *',
                          labelStyle: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.person_outline_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Email Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                          labelText: 'Email *',
                          labelStyle: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.email_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Phone Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                          labelText: 'Phone (Optional)',
                          labelStyle: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.phone_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Specialization Dropdown
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonFormField<String>(
                          value: selectedSpecialization,
                          onChanged: (String? value) {
                            setState(() {
                              selectedSpecialization = value;
                              specializationController.text = value == 'other' ? '' : (value ?? '');
                            });
                          },
                          items: [
                            // الخيار الافتراضي
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'Select Specialization *',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                            // خيارات من الباك
                            ...specializationsList.map((specialization) {
                              return DropdownMenuItem(
                                value: specialization,
                                child: Text(
                                  specialization,
                                  style: TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList(),

                            // خيار Other
                            DropdownMenuItem(
                              value: 'other',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text(
                                    'Other',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.medical_services_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            suffixIcon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          dropdownColor: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          iconSize: 0,
                          elevation: 2,
                        ),
                      ),
                    ),

                    // Custom Specialization Field (يظهر فقط إذا اختار "Other")
                    if (selectedSpecialization == 'other') ...[
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: TextField(
                          controller: specializationController,
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: InputBorder.none,
                            labelText: 'Enter Specialization *',
                            labelStyle: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(Icons.edit_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            floatingLabelStyle: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 16),

                    // Years Experience Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: experienceController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                          labelText: 'Years Experience (Optional)',
                          labelStyle: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.work_history_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Salary Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: salaryController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                          labelText: 'Monthly Salary (Optional)',
                          labelStyle: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.attach_money_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 8),

                    // Note about required fields
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent1.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Fields marked with * are required',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.accent1, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // التحقق من الحقول المطلوبة
                          if (nameController.text.isEmpty ||
                              emailController.text.isEmpty ||
                              (selectedSpecialization == null) ||
                              (selectedSpecialization == 'other' && specializationController.text.isEmpty)) {

                            _showErrorDialog('Please fill in all required fields (*)');
                            return;
                          }

                          try {
                            final Map<String, dynamic> requestBody = {
                              'full_name': nameController.text,
                              'email': emailController.text,
                              'specialization': selectedSpecialization == 'other'
                                  ? specializationController.text
                                  : selectedSpecialization!,
                            };

                            if (phoneController.text.isNotEmpty) {
                              requestBody['phone'] = phoneController.text;
                            }
                            if (experienceController.text.isNotEmpty) {
                              requestBody['years_experience'] = int.tryParse(experienceController.text);
                            }
                            if (salaryController.text.isNotEmpty) {
                              requestBody['salary'] = double.tryParse(salaryController.text);
                            }

                            final response = await ManagerSpecialistApiService.postRequest(
                              '/manager/specialists',
                              requestBody,
                            );

                            // إغلاق dialog الإضافة
                            Navigator.pop(context);

                            // عرض dialog النجاح
                            _showSuccessDialog(response['message'] ?? 'Specialist added successfully!');

                            // Refresh data مباشرة بعد النجاح
                            _loadRealData();

                          } catch (e) {
                            _showErrorDialog('Failed to add specialist: ${e.toString()}');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Add Specialist',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isRequired,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(
            color: AppColors.textLight,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
          prefixText: prefixText,
          prefixStyle: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

// دالة لعرض dialog النجاح
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.ment.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.ment,
                    size: 48,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Success!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textGray,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadRealData(); // تحديث البيانات مباشرة
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ment,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// دالة لعرض dialog الخطأ
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 12),
            Text(
              'Error',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          error,
          style: TextStyle(
            color: AppColors.textGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editSpecialist(Map<String, dynamic> specialist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Specialist Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.person, color: AppColors.primary),
                title: Text('Name'),
                subtitle: Text(specialist['name']),
              ),
              ListTile(
                leading: Icon(Icons.medical_services, color: AppColors.primary),
                title: Text('Specialty'),
                subtitle: Text(specialist['specialty']),
              ),
              ListTile(
                leading: Icon(Icons.attach_money, color: Colors.green),
                title: Text('Salary'),
                subtitle: Text('\$${specialist['salary']}'),
              ),
              ListTile(
                leading: Icon(Icons.event_note, color: AppColors.primary),
                title: Text('Sessions This Month'),
                subtitle: Text('${specialist['sessionsThisMonth']} sessions'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAllSpecialists();
            },
            child: Text('View Full Profile'),
          ),
        ],
      ),
    );
  }

  void _handleVacationRequest(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? selectedStatus;
          TextEditingController notesController = TextEditingController();

          return AlertDialog(
            title: Text('Vacation Request'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Specialist: ${request['specialistName']}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text('Duration: ${request['duration']}'),
                  Text('Dates: ${request['startDate']} - ${request['endDate']}'),
                  Text('Compensation: ${request['compensation']}'),
                  SizedBox(height: 10),
                  Text(
                    'Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(request['notes']),
                  SizedBox(height: 20),
                  Text(
                    'Action:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Approve'),
                          value: 'Approved',
                          groupValue: selectedStatus,
                          onChanged: (value) => setState(() => selectedStatus = value),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Reject'),
                          value: 'Rejected',
                          groupValue: selectedStatus,
                          onChanged: (value) => setState(() => selectedStatus = value),
                        ),
                      ),
                    ],
                  ),
                  if (selectedStatus == 'Rejected')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10),
                        Text('Rejection Notes:'),
                        TextField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Optional notes for rejection...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedStatus == null
                    ? null
                    : () async {
                  try {
                    final response = await ManagerVacationService.updateVacationRequestStatus(
                      requestId: int.parse(request['request_id'].toString()),
                      status: selectedStatus!,
                      managerNotes: notesController.text.isNotEmpty
                          ? notesController.text
                          : null,
                    );

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(response['message'] ?? 'Request ${selectedStatus!.toLowerCase()}'),
                        backgroundColor: selectedStatus == 'Approved'
                            ? AppColors.ment
                            : Colors.orange,
                      ),
                    );

                    // Refresh data
                    _loadRealData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(selectedStatus == null ? 'Select Action' : 'Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleSessionTypeRequest(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? selectedStatus;
          TextEditingController priceController = TextEditingController(
            text: request['price'].toString(),
          );

          return AlertDialog(
            title: Text('Session Type Request'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Session Type: ${request['sessionType']}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text('Category: ${request['category']}'),
                  Text('Duration: ${request['duration']}'),
                  Text('Original Price: \$${request['price']}'),
                  SizedBox(height: 10),
                  Text(
                    'Target Conditions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 6,
                    children: (request['targetConditions'] as List<dynamic>).map((condition) {
                      return Chip(label: Text(condition.toString()));
                    }).toList(),
                  ),
                  SizedBox(height: 10),
                  Text('Requested by: ${request['specialistName']}'),
                  SizedBox(height: 20),
                  Text(
                    'Action:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Approve'),
                          value: 'Approved',
                          groupValue: selectedStatus,
                          onChanged: (value) => setState(() => selectedStatus = value),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Reject'),
                          value: 'Rejected',
                          groupValue: selectedStatus,
                          onChanged: (value) => setState(() => selectedStatus = value),
                        ),
                      ),
                    ],
                  ),
                  if (selectedStatus == 'Approved')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10),
                        Text('Final Price:'),
                        TextField(
                          controller: priceController,
                          decoration: InputDecoration(
                            prefixText: '\$',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedStatus == null
                    ? null
                    : () async {
                  try {
                    final Map<String, dynamic> requestBody = {
                      'approval_status': selectedStatus!,
                    };

                    if (selectedStatus == 'Approved' && priceController.text.isNotEmpty) {
                      requestBody['price'] = double.tryParse(priceController.text);
                    }

                    final response = await ManagerSpecialistApiService.putRequest(
                      '/manager/session-types/${request['session_type_id']}/approval',
                      requestBody,
                    );

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(response['message'] ?? 'Request ${selectedStatus!.toLowerCase()}'),
                        backgroundColor: selectedStatus == 'Approved'
                            ? AppColors.ment
                            : Colors.orange,
                      ),
                    );

                    // Refresh data
                    _loadRealData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(selectedStatus == null ? 'Select Action' : 'Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _viewAllVacations() {
    // تنقل إلى صفحة إدارة الإجازات (يمكن إنشاؤها لاحقاً)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vacation Management'),
        content: Container(
          width: double.maxFinite,
          height: 200,
          child: Column(
            children: [
              Text('Vacation management screen would appear here'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // يمكن إضافة صفحة إدارة الإجازات لاحقاً
                },
                child: Text('Go to Vacation Management'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return AppColors.primary;
      case 'pending': return Colors.orange;
      case 'absent': return AppColors.warning;
      case 'inactive': return AppColors.textGray;
      case 'completed': return AppColors.ment;
      default: return AppColors.textGray;
    }
  }
}
