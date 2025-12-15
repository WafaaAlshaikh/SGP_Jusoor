import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_specialist_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // إذا مش موجود
class SpecialistScheduleScreen extends StatefulWidget {
  final int? specialistId;
  final String? specialistName;

  // Constructor العادي
  const SpecialistScheduleScreen({
    this.specialistId,
    this.specialistName,
    Key? key,
  }) : super(key: key);

  // Constructor للتنقل من صفحة الـ Report
  factory SpecialistScheduleScreen.fromReport({
    required int specialistId,
    required String specialistName,
  }) {
    return SpecialistScheduleScreen(
      specialistId: specialistId,
      specialistName: specialistName,
    );
  }

  @override
  _SpecialistScheduleScreenState createState() => _SpecialistScheduleScreenState();
}

class _SpecialistScheduleScreenState extends State<SpecialistScheduleScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allSpecialists = [];
  Map<String, List<Map<String, dynamic>>> _dailySchedules = {};
  Map<String, dynamic> _selectedSpecialist = {};
  bool _showAllSpecialists = true;
  String? _fcmToken;
  String _selectedDay = 'Monday';
  List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];


  Future<void> _getFCMToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');

      if (token != null) {
        setState(() {
          _fcmToken = token;
        });
        print('📱 FCM Token loaded for schedule notifications');
      }
    } catch (e) {
      print('⚠️ Error loading FCM token: $e');
    }
  }

  // 🔥 دالة إرسال إشعارات الجداول
  Future<void> _sendScheduleNotification({
    required String action,
    required String dayOfWeek,
    String? startTime,
    String? endTime,
    int? numberOfSchedules,
  }) async {
    try {
      if (_fcmToken == null) {
        print('⚠️ No FCM token for schedule notification');
        return;
      }

      print('📅 Sending schedule $action notification...');

      // إعداد البيانات حسب نوع الإجراء
      String title;
      String body;
      Map<String, dynamic> data = {
        'type': 'schedule_change',
        'action': action,
        'day_of_week': dayOfWeek,
        'timestamp': DateTime.now().toIso8601String(),
      };

      switch (action) {
        case 'added':
          title = '📅 New Schedule Added';
          body = 'New schedule added for $dayOfWeek: $startTime - $endTime';
          data['start_time'] = startTime;
          data['end_time'] = endTime;
          break;

        case 'updated':
          title = '🔄 Schedule Updated';
          body = 'Schedule for $dayOfWeek has been updated';
          if (startTime != null) data['start_time'] = startTime;
          if (endTime != null) data['end_time'] = endTime;
          break;

        case 'deleted':
          title = '🗑️ Schedule Deleted';
          body = 'Schedule for $dayOfWeek has been deleted';
          break;

        case 'bulk_added':
          title = '📋 Schedules Added';
          body = '$numberOfSchedules schedules have been added';
          data['count'] = numberOfSchedules.toString();
          break;

        default:
          title = '📅 Schedule Modified';
          body = 'Your schedule has been modified';
      }

      // إرسال الإشعار عبر API
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/notifications/test'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': _fcmToken!,
          'title': title,
          'body': body,
          ...data,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Schedule notification sent successfully');
      } else {
        print('⚠️ Failed to send schedule notification: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending schedule notification: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _getFCMToken();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // إذا تم تمرير specialistId من الـ Report، قم بتحميل بياناته مباشرة
    if (widget.specialistId != null && _selectedSpecialist.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSpecialistDetails(widget.specialistId!);
        setState(() {
          _showAllSpecialists = false;
        });
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // جلب جميع الأخصائيين وجداولهم
      final specialistsResponse = await ManagerSpecialistService.getAllSpecialists();
      final specialistsData = specialistsResponse['data'] ?? {};
      final allSpecialists = specialistsData['all_specialists'] as List? ?? [];

      // تحويل بيانات الأخصائيين
      _allSpecialists = allSpecialists.map((spec) {
        final personalInfo = spec['personal_info'] ?? {};
        final professionalInfo = spec['professional_info'] ?? {};
        final schedules = spec['schedules'] as List? ?? [];

        return {
          'id': spec['specialist_id'],
          'name': personalInfo['full_name'],
          'specialty': professionalInfo['specialization'],
          'email': personalInfo['email'],
          'phone': personalInfo['phone'] ?? 'N/A',
          'schedules': schedules,
          'approval_status': professionalInfo['approval_status'],
        };
      }).toList();

      // بناء جداول اليومية من بيانات الأخصائيين
      _buildDailySchedulesFromSpecialists();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _buildDailySchedulesFromSpecialists() {
    // تهيئة الخريطة لكل يوم
    _dailySchedules = {};
    for (var day in _days) {
      _dailySchedules[day] = [];
    }

    // ملء الجداول لكل أخصائي
    for (var specialist in _allSpecialists) {
      final schedules = specialist['schedules'] as List;

      for (var schedule in schedules) {
        final dayOfWeek = schedule['day_of_week'] as String?;
        if (dayOfWeek != null && _days.contains(dayOfWeek)) {
          final specialistSchedule = {
            'specialist_id': specialist['id'],
            'specialistName': specialist['name'],
            'specialty': specialist['specialty'],
            'start_time': schedule['start_time'] ?? '',
            'end_time': schedule['end_time'] ?? '',
            'time': '${schedule['start_time'] ?? ''} - ${schedule['end_time'] ?? ''}',
            'schedule_id': schedule['schedule_id'],
          };

          _dailySchedules[dayOfWeek]!.add(specialistSchedule);
        }
      }
    }

    // ترتيب الأخصائيين في كل يوم حسب الاسم
    for (var day in _days) {
      _dailySchedules[day]!.sort((a, b) => a['specialistName'].compareTo(b['specialistName']));
    }
  }

  Future<void> _loadSpecialistDetails(int specialistId) async {
    try {
      final response = await ManagerSpecialistService.getSpecialistDetails(specialistId);
      final specialistData = response['data'] ?? {};

      setState(() {
        _selectedSpecialist = {
          'id': specialistData['specialist_id'],
          'name': specialistData['personal_info']['full_name'],
          'specialty': specialistData['professional_info']['specialization'],
          'email': specialistData['personal_info']['email'],
          'phone': specialistData['personal_info']['phone'] ?? 'N/A',
          'approval_status': specialistData['professional_info']['approval_status'],
          'schedules': specialistData['schedules'] ?? [],
        };
      });
    } catch (e) {
      print('Error loading specialist details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load specialist details'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDaySelector() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _days.map((day) {
                bool isSelected = _selectedDay == day;
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.accent2,
                          width: 1.5,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialistCard(Map<String, dynamic> specialist) {
    bool hasSchedule = (specialist['schedules'] as List).isNotEmpty;
    bool isActive = specialist['approval_status'] == 'approved';

    // الحصول على عدد الجداول لهذا اليوم
    final todaySchedules = _getSpecialistSchedulesForDay(specialist['id'], _selectedDay);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: hasSchedule ? AppColors.primary.withOpacity(0.1) : AppColors.accent2,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _loadSpecialistDetails(specialist['id']);
            setState(() {
              _showAllSpecialists = false;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isActive
                          ? [AppColors.primary, AppColors.primaryLight]
                          : [AppColors.accent3, AppColors.accent4],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (specialist['name'] as String).split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),

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
                        ],
                      ),

                      SizedBox(height: 6),

                      Text(
                        specialist['specialty'],
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: 12),

                      // إذا كان لديه جدول في اليوم المحدد، عرض وقت العمل
                      if (todaySchedules.isNotEmpty) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: todaySchedules.map((schedule) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 4),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '${schedule['start_time']} - ${schedule['end_time']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 8),
                      ],

                      // عرض حالة الجدول
                      Row(
                        children: [
                          // Schedule Status
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: hasSchedule
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.accent1,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  hasSchedule ? Icons.schedule_rounded : Icons.schedule_outlined,
                                  size: 14,
                                  color: hasSchedule ? AppColors.primary : AppColors.textLight,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  hasSchedule ? 'Has Schedule' : 'No Schedule',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: hasSchedule ? AppColors.primary : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 8),

                          // Days Count
                          if (hasSchedule)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accent2,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                    size: 14,
                                    color: AppColors.primaryDark,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '${specialist['schedules'].length} days',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8),

                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSpecialistSchedulesForDay(int specialistId, String day) {
    final allSchedules = _dailySchedules[day] ?? [];
    return allSchedules.where((schedule) => schedule['specialist_id'] == specialistId).toList();
  }

  Widget _buildDailyView() {
    final daySchedules = _dailySchedules[_selectedDay] ?? [];

    if (daySchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded,
              size: 80,
              color: AppColors.accent4,
            ),
            SizedBox(height: 20),
            Text(
              'No schedules for',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _selectedDay,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Add schedules for specialists in the specialists view',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with day info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDay,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${daySchedules.length} specialist${daySchedules.length > 1 ? 's' : ''} scheduled',
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
          ),
        ),

        // List of specialists with schedules
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: daySchedules.length,
            itemBuilder: (context, index) {
              final schedule = daySchedules[index];

              // البحث عن الأخصائي للحصول على معلومات إضافية
              Map<String, dynamic> specialist = {};
              try {
                specialist = _allSpecialists.firstWhere(
                      (spec) => spec['id'] == schedule['specialist_id'],
                );
              } catch (e) {
                // إذا لم يتم العثور على الأخصائي، استخدم البيانات الأساسية
              }

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (schedule['specialistName'] as String).split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    schedule['specialistName'],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text(
                        schedule['specialty'],
                        style: TextStyle(color: AppColors.textGray),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent1,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              schedule['time'] ?? '',
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
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                  ),
                  onTap: () {
                    _loadSpecialistDetails(schedule['specialist_id']);
                    setState(() {
                      _showAllSpecialists = false;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialistDetailView() {
    if (_selectedSpecialist.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final schedules = _selectedSpecialist['schedules'] as List? ?? [];
    bool isActive = _selectedSpecialist['approval_status'] == 'approved';

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          Container(
            margin: EdgeInsets.only(bottom: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  _selectedSpecialist = {};
                  _showAllSpecialists = true;
                }),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Back to Specialists',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Specialist Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 15,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isActive
                              ? [AppColors.primary, AppColors.primaryLight]
                              : [AppColors.accent3, AppColors.accent4],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (_selectedSpecialist['name'] as String).split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedSpecialist['name'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _selectedSpecialist['specialty'],
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // Contact Info
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildContactItem(Icons.email_rounded, _selectedSpecialist['email']),
                      SizedBox(height: 12),
                      _buildContactItem(Icons.phone_rounded, _selectedSpecialist['phone']),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Schedule Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Schedule',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addWeeklySchedule(_selectedSpecialist['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: Icon(Icons.calendar_month_rounded, size: 18),
                label: Text('Add Schedule'),
              ),
            ],
          ),

          SizedBox(height: 16),

          if (schedules.isEmpty)
            Container(
              padding: EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent2,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 60,
                    color: AppColors.accent4,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No Schedule Assigned',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Add a schedule to start booking sessions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: schedules.map((schedule) {
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent2,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      schedule['day_of_week'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: Text(
                      '${schedule['start_time']} - ${schedule['end_time']}',
                      style: TextStyle(
                        color: AppColors.textGray,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_rounded, size: 18),
                          onPressed: () => _editSchedule(schedule),
                          color: AppColors.primary,
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_rounded, size: 18),
                          onPressed: () => _deleteSchedule(schedule['schedule_id']),
                          color: AppColors.error,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String value) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addWeeklySchedule(int specialistId) async {
    TextEditingController startTimeController = TextEditingController(text: '09:00');
    TextEditingController endTimeController = TextEditingController(text: '17:00');
    List<String> selectedDays = [];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Add Weekly Schedule',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Days Selection
                    Text(
                      'Select Working Days',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _days.map((day) {
                        bool isSelected = selectedDays.contains(day);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedDays.remove(day);
                              } else {
                                selectedDays.add(day);
                              }
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.accent2,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              day.substring(0, 3),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 20),

                    // Time Selection
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.accent2,
                                    width: 1.5,
                                  ),
                                ),
                                child: TextField(
                                  controller: startTimeController,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12),
                                    hintText: 'HH:MM',
                                    prefixIcon: Icon(Icons.access_time_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.accent2,
                                    width: 1.5,
                                  ),
                                ),
                                child: TextField(
                                  controller: endTimeController,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12),
                                    hintText: 'HH:MM',
                                    prefixIcon: Icon(Icons.access_time_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    if (selectedDays.isEmpty)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please select at least one day',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                ),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedDays.isEmpty ? null : () {
                  Navigator.pop(context, {
                    'days': selectedDays,
                    'startTime': startTimeController.text,
                    'endTime': endTimeController.text,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('Add Schedule'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result['days'] != null) {
      try {
        List<Map<String, dynamic>> schedulesToAdd = [];
        for (var day in result['days']) {
          schedulesToAdd.add({
            'day_of_week': day,
            'start_time': result['startTime'],
            'end_time': result['endTime'],
          });
        }

        // 👇 عدل استدعاء الـ service لإضافة التوكن
        await ManagerSpecialistService.addMultipleSchedules(
          specialistId: specialistId,
          schedules: schedulesToAdd,
          specialistFcmToken: _fcmToken, // 👈 أضف هذا
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weekly schedule added successfully'),
            backgroundColor: AppColors.ment,
          ),
        );

        // 🔥 إرسال الإشعار
        if (_fcmToken != null && schedulesToAdd.isNotEmpty) {
          _sendScheduleNotification(
            action: 'bulk_added',
            dayOfWeek: schedulesToAdd.first['day_of_week'],
            numberOfSchedules: schedulesToAdd.length,
          ).catchError((e) {
            print('⚠️ Schedule notification failed, but schedule was added');
          });
        }

        // إعادة تحميل البيانات
        await _loadData();
        await _loadSpecialistDetails(specialistId);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add schedule: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editSchedule(Map<String, dynamic> schedule) async {
    TextEditingController startTimeController = TextEditingController(text: schedule['start_time']);
    TextEditingController endTimeController = TextEditingController(text: schedule['end_time']);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 12),
            Text(
              'Edit Schedule',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    schedule['day_of_week'],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Time',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent2,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: startTimeController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                      hintText: 'HH:MM',
                      hintStyle: TextStyle(color: AppColors.textLight),
                      prefixIcon: Icon(Icons.access_time_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End Time',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent2,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: endTimeController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                      hintText: 'HH:MM',
                      hintStyle: TextStyle(color: AppColors.textLight),
                      prefixIcon: Icon(Icons.access_time_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textGray,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (startTimeController.text.isNotEmpty && endTimeController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'start': startTimeController.text,
                  'end': endTimeController.text,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // 👇 عدل استدعاء الـ service لإضافة التوكن
        await ManagerSpecialistService.updateSchedule(
          scheduleId: schedule['schedule_id'],
          startTime: result['start'],
          endTime: result['end'],
          specialistFcmToken: _fcmToken, // 👈 أضف هذا
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Schedule updated successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // 🔥 إرسال الإشعار
        if (_fcmToken != null) {
          _sendScheduleNotification(
            action: 'updated',
            dayOfWeek: schedule['day_of_week'],
            startTime: result['start'],
            endTime: result['end'],
          ).catchError((e) {
            print('⚠️ Schedule update notification failed');
          });
        }

        // تحديث البيانات
        await _loadData();
        await _loadSpecialistDetails(_selectedSpecialist['id']);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to update schedule'),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteSchedule(int scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            SizedBox(width: 12),
            Text(
              'Delete Schedule',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded,
                size: 24,
                color: AppColors.warning,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Are you sure you want to delete this schedule?',
                  style: TextStyle(
                    color: AppColors.textGray,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textGray,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_rounded, size: 18),
                SizedBox(width: 6),
                Text('Delete'),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // نحتاج لمعرفة يوم الجدول قبل الحذف
        String scheduleDay = '';
        if (_selectedSpecialist.isNotEmpty) {
          final schedules = _selectedSpecialist['schedules'] as List;
          final schedule = schedules.firstWhere(
                (s) => s['schedule_id'] == scheduleId,
            orElse: () => {},
          );
          scheduleDay = schedule['day_of_week'] ?? '';
        }

        // 👇 عدل استدعاء الـ service لإضافة التوكن
        await ManagerSpecialistService.deleteSchedule(
          scheduleId: scheduleId,
          specialistFcmToken: _fcmToken, // 👈 أضف هذا
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Schedule deleted successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // 🔥 إرسال الإشعار
        if (_fcmToken != null && scheduleDay.isNotEmpty) {
          _sendScheduleNotification(
            action: 'deleted',
            dayOfWeek: scheduleDay,
          ).catchError((e) {
            print('⚠️ Schedule delete notification failed');
          });
        }

        // تحديث البيانات
        await _loadData();
        if (_selectedSpecialist.isNotEmpty) {
          await _loadSpecialistDetails(_selectedSpecialist['id']);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to delete schedule'),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.specialistName != null
              ? '${widget.specialistName}\'s Schedule'
              : 'Specialist Schedules',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 20),
            Text(
              'Loading schedules...',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Day Selector (يظهر فقط في Daily View)
          if (!_showAllSpecialists && _selectedSpecialist.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildDaySelector(),
            ),

          // Toggle Button (يظهر فقط إذا لم يكن هناك أخصائي محدد)
          if (widget.specialistId == null || _showAllSpecialists)
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent2,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _showAllSpecialists = true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _showAllSpecialists ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                size: 18,
                                color: _showAllSpecialists ? Colors.white : AppColors.textGray,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'All Specialists',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _showAllSpecialists ? Colors.white : AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          _showAllSpecialists = false;
                          _selectedSpecialist = {};
                        }),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_showAllSpecialists && _selectedSpecialist.isEmpty
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: !_showAllSpecialists && _selectedSpecialist.isEmpty
                                    ? Colors.white
                                    : AppColors.textGray,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Daily View',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: !_showAllSpecialists && _selectedSpecialist.isEmpty
                                      ? Colors.white
                                      : AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _showAllSpecialists
                ? Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                itemCount: _allSpecialists.length,
                itemBuilder: (context, index) {
                  return _buildSpecialistCard(_allSpecialists[index]);
                },
              ),
            )
                : _selectedSpecialist.isEmpty
                ? _buildDailyView()
                : _buildSpecialistDetailView(),
          ),
        ],
      ),
    );
  }
}