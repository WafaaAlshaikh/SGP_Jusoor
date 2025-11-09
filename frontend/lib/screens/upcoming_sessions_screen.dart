// lib/screens/upcoming_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpcomingSessionsScreen extends StatefulWidget {
  final List<dynamic> upcomingSessions;

  const UpcomingSessionsScreen({
    super.key,
    required this.upcomingSessions,
  });

  @override
  State<UpcomingSessionsScreen> createState() => _UpcomingSessionsScreenState();
}

class _UpcomingSessionsScreenState extends State<UpcomingSessionsScreen> {
  late List<dynamic> _upcomingSessions;

  String selectedChild = 'All';
  String? selectedType;
  String? selectedDateFilter;

  @override
  void initState() {
    super.initState();
    _upcomingSessions = List.from(widget.upcomingSessions);
  }

  // ===============================================================
  // فلترة الجلسات
  // ===============================================================
  List<dynamic> filterSessions(List<dynamic> sessions) {
    return sessions.where((s) {
      bool matchesChild = selectedChild == 'All' || s['childName'] == selectedChild;
      bool matchesType = selectedType == null || s['sessionType'] == selectedType;
      bool matchesDate = true;

      if (selectedDateFilter == 'Today') {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        matchesDate = s['date'] == today;
      } else if (selectedDateFilter == 'This Week') {
        final sessionDate = DateTime.tryParse(s['date'] ?? '') ?? DateTime.now();
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        matchesDate = sessionDate.isAfter(startOfWeek) && sessionDate.isBefore(endOfWeek);
      }

      // التأكد من أن الجلسة قادمة وليست مكتملة
      bool isUpcoming = s['status'] != 'Completed' && s['status'] != 'Cancelled';

      return matchesChild && matchesType && matchesDate && isUpcoming;
    }).toList();
  }

  // ===============================================================
  // واجهة الصفحة
  // ===============================================================
  @override
  Widget build(BuildContext context) {
    final List<String> allChildren = _upcomingSessions
        .map((s) => s['childName']?.toString() ?? 'Unknown')
        .toSet()
        .toList()
        .cast<String>();

    final List<String> allTypes = _upcomingSessions
        .map((s) => s['sessionType']?.toString() ?? 'Unknown')
        .toSet()
        .toList()
        .cast<String>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجلسات القادمة'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // ===================== زر الفلاتر =====================
          _buildFilterButton(allChildren, allTypes),
          const Divider(),

          Expanded(
            child: _buildSessionList(
              filterSessions(_upcomingSessions),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // زر الفلاتر
  // ===============================================================
  Widget _buildFilterButton(List<String> allChildren, List<String> allTypes) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.filter_list),
        label: const Text('فلترة الجلسات'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => _buildFilterSheet(allChildren, allTypes),
          );
        },
      ),
    );
  }

  // ===============================================================
  // BottomSheet للفلترة
  // ===============================================================
  Widget _buildFilterSheet(List<String> allChildren, List<String> allTypes) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('اختر الطفل:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('الكل'),
                selected: selectedChild == 'All',
                onSelected: (_) => setState(() => selectedChild = 'All'),
              ),
              ...allChildren.map((c) => ChoiceChip(
                label: Text(c),
                selected: selectedChild == c,
                onSelected: (_) => setState(() => selectedChild = c),
              )),
            ],
          ),
          const SizedBox(height: 16),
          const Text('اختر النوع:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('الكل'),
                selected: selectedType == null,
                onSelected: (_) => setState(() => selectedType = null),
              ),
              ...allTypes.map((t) => ChoiceChip(
                label: Text(t),
                selected: selectedType == t,
                onSelected: (_) => setState(() => selectedType = t),
              )),
            ],
          ),
          const SizedBox(height: 16),
          const Text('اختر التاريخ:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('الكل'),
                selected: selectedDateFilter == null,
                onSelected: (_) => setState(() => selectedDateFilter = null),
              ),
              ChoiceChip(
                label: const Text('اليوم'),
                selected: selectedDateFilter == 'Today',
                onSelected: (_) => setState(() => selectedDateFilter = 'Today'),
              ),
              ChoiceChip(
                label: const Text('هذا الأسبوع'),
                selected: selectedDateFilter == 'This Week',
                onSelected: (_) => setState(() => selectedDateFilter = 'This Week'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تطبيق الفلاتر'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // بناء قائمة الجلسات
  // ===============================================================
  Widget _buildSessionList(List<dynamic> sessions) {
    if (sessions.isEmpty) {
      return const Center(
          child: Text('لا توجد جلسات قادمة حالياً',
              style: TextStyle(fontSize: 16)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final s = sessions[index];
        return _buildSessionCard(s);
      },
    );
  }

  // ===============================================================
  // بطاقة الجلسة
  // ===============================================================
  Widget _buildSessionCard(dynamic s) {
    final dateTime = DateTime.tryParse('${s['date']} ${s['time']}') ?? DateTime.now();
    final diff = dateTime.difference(DateTime.now());
    final countdown = diff.isNegative
        ? 'بدأت'
        : 'تبدأ بعد ${diff.inHours} ساعة و ${diff.inMinutes % 60} دقيقة';

    Color statusColor = _getStatusColor(s['status']);

    double progress = (diff.inSeconds > 0
        ? 1 - (diff.inSeconds / Duration(days: 1).inSeconds).clamp(0.0, 1.0)
        : 1.0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: s['childPhoto'] != null && s['childPhoto'].isNotEmpty
                      ? NetworkImage(s['childPhoto'])
                      : null,
                  backgroundColor: Colors.teal[200],
                  child: s['childPhoto'] == null || s['childPhoto'].isEmpty
                      ? Text(
                    s['childName'] != null && s['childName'].isNotEmpty
                        ? s['childName'][0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['childName'] ?? 'غير معروف',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${s['specialistName'] ?? 'أخصائي غير محدد'} • ${s['institutionName'] ?? ''}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        color: Colors.teal,
                        strokeWidth: 4,
                      ),
                      Center(
                        child: Icon(
                          Icons.access_time,
                          size: 20,
                          color: Colors.teal[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              DateFormat('EEE, d MMM yyyy • hh:mm a').format(dateTime),
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 5),
            Text(
              'النوع: ${s['sessionType'] ?? 'N/A'} | المدة: ${s['duration']} دقيقة | السعر: \$${s['price']}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s['status'] ?? '',
                style: TextStyle(
                    color: statusColor, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            Text('⏰ $countdown'),
            const SizedBox(height: 10),
            if (s['location'] != null && s['location'].isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(s['location'])}');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.location_on, color: Colors.teal),
                      ),
                      Expanded(
                          child: Text(
                            s['location'],
                            style: TextStyle(color: Colors.teal[800]),
                          )),
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.map, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.teal),
                  label: const Text('تأكيد'),
                  onPressed: () => _confirmSession(s['sessionId']),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('إلغاء'),
                  onPressed: () => _cancelSession(s['sessionId']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // وظائف الأزرار
  // ===============================================================
  void _confirmSession(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) return;

    try {
      await ApiService.confirmSession(token, id.toString());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم تأكيد الجلسة #$id ✅')));
      setState(() {
        _upcomingSessions.removeWhere((s) => s['sessionId'] == id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  void _cancelSession(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) return;

    try {
      await ApiService.cancelSession(token, id.toString());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم إلغاء الجلسة #$id ❌')));
      setState(() {
        _upcomingSessions.removeWhere((s) => s['sessionId'] == id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  // ===============================================================
  // ألوان الحالة
  // ===============================================================
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Scheduled':
        return Colors.blue;
      case 'Confirmed':
        return Colors.green;
      case 'Cancelled':
        return Colors.grey;
      case 'Completed':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }
}