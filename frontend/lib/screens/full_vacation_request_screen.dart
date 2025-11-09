import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/vacation_service.dart';
import '../services/activity_service.dart';
class VacationRequest {
  int id;
  DateTime startDate;
  DateTime endDate;
  String status; // Pending / Approved / Rejected
  String? reason;

  VacationRequest({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
  });

  // دالة لتحويل من JSON
  factory VacationRequest.fromJson(Map<String, dynamic> json) {
    return VacationRequest(
      id: json['request_id'] ?? json['id'] ?? 0,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      status: json['status'] ?? 'Pending',
      reason: json['reason'],
    );
  }
}

class VacationRequestScreen extends StatefulWidget {
  const VacationRequestScreen({Key? key}) : super(key: key);

  @override
  State<VacationRequestScreen> createState() => _VacationRequestScreenState();
}

class _VacationRequestScreenState extends State<VacationRequestScreen> {
  List<VacationRequest> myRequests = [];
  List<DateTime> unavailableDates = [];
  DateTime? selectedStart;
  DateTime? selectedEnd;
  TextEditingController reasonController = TextEditingController();
  bool isLoading = false;
  bool isEditing = false;
  int? editingRequestId;
  String _selectedFilter = 'All';

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  // الحصول على القائمة المصفاة
  List<VacationRequest> get filteredRequests {
    switch (_selectedFilter) {
      case 'Pending':
        return myRequests.where((req) => req.status == 'Pending').toList();
      case 'Approved':
        return myRequests.where((req) => req.status == 'Approved').toList();
      case 'Rejected':
        return myRequests.where((req) => req.status == 'Rejected').toList();
      default:
        return myRequests;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadVacations();
    _loadUnavailableDates();
  }

  // تحميل طلبات الإجازة من API
  Future<void> _loadVacations() async {
    setState(() => isLoading = true);
    try {
      final data = await VacationService.getMyVacations();
      setState(() {
        myRequests = data.map((json) => VacationRequest.fromJson(json)).toList();
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load vacations');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // تحميل الأيام غير المتاحة
  Future<void> _loadUnavailableDates() async {
    try {
      final dates = await VacationService.getUnavailableDates();
      setState(() {
        unavailableDates = dates;
      });
    } catch (e) {
      print('Error loading unavailable dates: $e');
    }
  }

  // إظهار رسالة خطأ
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // إظهار رسالة نجاح
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // الحصول على ألوان الأيام في التقويم
  Color _getDayColor(DateTime day) {
    // تلوين الأيام غير المتاحة (فيها جلسات) - لون أحمر
    if (unavailableDates.any((date) =>
    date.year == day.year && date.month == day.month && date.day == day.day)) {
      return Colors.red.withOpacity(0.7);
    }

    // تلوين أيام الإجازات
    for (var req in myRequests) {
      if (!day.isBefore(req.startDate) && !day.isAfter(req.endDate)) {
        switch (req.status) {
          case 'Approved':
            return Colors.green.withOpacity(0.7);
          case 'Pending':
            return Colors.orange.withOpacity(0.7);
          case 'Rejected':
            return Colors.red.withOpacity(0.7);
        }
      }
    }

    return Colors.transparent;
  }

  // الحصول على لون النص بناءً على الخلفية
  Color _getTextColor(DateTime day) {
    final bgColor = _getDayColor(day);
    if (bgColor == Colors.transparent) return Colors.black;

    final luminance = bgColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // اختيار تاريخ البدء
  Future<void> pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedStart ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7815A0),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedStart = picked);
  }

  // اختيار تاريخ الانتهاء
  Future<void> pickEndDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedEnd ?? selectedStart ?? DateTime.now(),
      firstDate: selectedStart ?? DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7815A0),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedEnd = picked);
  }

  // تفعيل وضع التعديل
  void _enableEditMode(VacationRequest request) {
    setState(() {
      isEditing = true;
      editingRequestId = request.id;
      selectedStart = request.startDate;
      selectedEnd = request.endDate;
      reasonController.text = request.reason ?? '';
    });

    // Scroll to form
    Future.delayed(Duration(milliseconds: 300), () {
      Scrollable.ensureVisible(context);
    });
  }

  // إلغاء التعديل
  void _cancelEdit() {
    setState(() {
      isEditing = false;
      editingRequestId = null;
      selectedStart = null;
      selectedEnd = null;
      reasonController.clear();
    });
  }

  // إرسال أو تحديث طلب الإجازة
  Future<void> submitRequest() async {
    if (selectedStart == null || selectedEnd == null) {
      _showErrorSnackbar("Please select both dates");
      return;
    }

    if (selectedEnd!.isBefore(selectedStart!)) {
      _showErrorSnackbar("End date cannot be before start date");
      return;
    }

    setState(() => isLoading = true);

    final result = isEditing
        ? await VacationService.updateVacation(
      id: editingRequestId!,
      startDate: selectedStart!,
      endDate: selectedEnd!,
      reason: reasonController.text.isNotEmpty ? reasonController.text : null,
    )
        : await VacationService.createVacation(
      startDate: selectedStart!,
      endDate: selectedEnd!,
      reason: reasonController.text.isNotEmpty ? reasonController.text : null,
    );

    setState(() => isLoading = false);

    if (result['success'] == true) {
      // 🆕 أضف النشاط هنا بعد النجاح
      if (isEditing) {
        await ActivityService.addActivity(
            'Vacation request updated (${DateFormat('MMM dd').format(selectedStart!)} - ${DateFormat('MMM dd').format(selectedEnd!)})',
            'vacation'
        );
      } else {
        await ActivityService.addActivity(
            'New vacation request submitted (${DateFormat('MMM dd').format(selectedStart!)} - ${DateFormat('MMM dd').format(selectedEnd!)})',
            'vacation'
        );
      }

      _showSuccessSnackbar(result['message']);
      await _loadVacations();
      _cancelEdit();
    } else {
      _showErrorSnackbar(result['message']);
    }
  }

  // حذف طلب الإجازة
  Future<void> deleteRequest(VacationRequest req) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Vacation Request", style: TextStyle(color: Color(0xFF7815A0))),
        content: const Text("Are you sure you want to delete this vacation request?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);
    final result = await VacationService.deleteVacation(req.id);
    setState(() => isLoading = false);

    if (result['success'] == true) {
      _showSuccessSnackbar(result['message']);
      await _loadVacations();
    } else {
      _showErrorSnackbar(result['message']);
    }
  }

  // الحصول على أيقونة الحالة
  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'Rejected':
        return const Icon(Icons.cancel, color: Colors.red, size: 20);
      case 'Pending':
      default:
        return const Icon(Icons.access_time, color: Colors.orange, size: 20);
    }
  }

  // الحصول على لون الحالة
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
      default:
        return Colors.orange;
    }
  }

  // بناء شريط الفلاتر
  Widget _buildFilterBar() {
    final filters = ['All', 'Pending', 'Approved', 'Rejected'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedFilter = filter);
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF7815A0),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF7815A0),
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF7815A0) : Colors.grey[300]!,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // بناء إحصائيات سريعة
  Widget _buildStatsCard() {
    final pendingCount = myRequests.where((req) => req.status == 'Pending').length;
    final approvedCount = myRequests.where((req) => req.status == 'Approved').length;
    final rejectedCount = myRequests.where((req) => req.status == 'Rejected').length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(pendingCount, 'Pending', Colors.orange),
            _buildStatItem(approvedCount, 'Approved', Colors.green),
            _buildStatItem(rejectedCount, 'Rejected', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(int count, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // رسالة الحالة الفارغة
  String _getEmptyStateMessage() {
    switch (_selectedFilter) {
      case 'All':
        return "Submit your first vacation request to get started!";
      case 'Pending':
        return "No pending vacation requests";
      case 'Approved':
        return "No approved vacation requests";
      case 'Rejected':
        return "No rejected vacation requests";
      default:
        return "No vacation requests found";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Vacation Requests",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF7815A0),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: const Color(0xFFF8F5FF),
        child: isLoading && myRequests.isEmpty
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF7815A0))),
              SizedBox(height: 16),
              Text(
                "Loading your vacations...",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadVacations,
          color: const Color(0xFF7815A0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // ------------------- Calendar Section -------------------
                _buildCalendarSection(),
                const SizedBox(height: 24),

                // ------------------- Quick Stats -------------------
                if (myRequests.isNotEmpty) ...[
                  _buildStatsCard(),
                  const SizedBox(height: 20),
                ],

                // ------------------- Request Form -------------------
                _buildRequestForm(),
                const SizedBox(height: 24),

                // ------------------- Requests List -------------------
                _buildRequestsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF7815A0), size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Vacation Calendar",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7815A0),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<CalendarFormat>(
                  icon: const Icon(Icons.view_week, color: Color(0xFF7815A0)),
                  onSelected: (format) => setState(() => _calendarFormat = format),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: CalendarFormat.month, child: Text('Month View')),
                    const PopupMenuItem(value: CalendarFormat.twoWeeks, child: Text('2 Weeks View')),
                    const PopupMenuItem(value: CalendarFormat.week, child: Text('Week View')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime(2100),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) => setState(() => _calendarFormat = format),
              onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF7815A0),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                selectedDecoration: BoxDecoration(
                  color: Colors.orange.shade400,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: const TextStyle(color: Colors.red),
                outsideDaysVisible: false,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7815A0),
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return Container(
                    decoration: BoxDecoration(
                      color: _getDayColor(day),
                      shape: BoxShape.circle,
                    ),
                    margin: const EdgeInsets.all(1),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: _getTextColor(day),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(Colors.red, "Sessions", Icons.event_busy),
        _buildLegendItem(Colors.orange, "Pending", Icons.access_time),
        _buildLegendItem(Colors.green, "Approved", Icons.check_circle),
        _buildLegendItem(Colors.red, "Rejected", Icons.cancel),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEditing ? Icons.edit : Icons.add_circle,
                  color: const Color(0xFF7815A0),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? "Edit Vacation Request" : "New Vacation Request",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7815A0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton("Start Date", selectedStart, pickStartDate),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateButton("End Date", selectedEnd, pickEndDate),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: "Reason (optional)",
                labelStyle: const TextStyle(color: Color(0xFF7815A0)),
                hintText: "Enter the reason for your vacation...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFF7815A0), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            if (isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelEdit,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : submitRequest,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF7815A0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text(
                        "Update Request",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : submitRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF7815A0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        "Submit Request",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7815A0),
          ),
        ),
        const SizedBox(height: 6),
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7815A0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  date == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(date),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.calendar_today, size: 18, color: Colors.white),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    final requests = filteredRequests;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with filter - redesigned to prevent overflow
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt, color: Color(0xFF7815A0), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      "My Vacation Requests",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7815A0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (myRequests.isNotEmpty) _buildFilterBar(),
              ],
            ),
            const SizedBox(height: 16),

            if (requests.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildRequestCard(requests[index]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.beach_access,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "No vacation requests",
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateMessage(),
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(VacationRequest req) {
    final duration = req.endDate.difference(req.startDate).inDays + 1;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: _getStatusColor(req.status), width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _getStatusIcon(req.status),
                      const SizedBox(width: 8),
                      Text(
                        req.status.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(req.status),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  if (req.status == 'Pending')
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                          onPressed: () => _enableEditMode(req),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          onPressed: () => deleteRequest(req),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${DateFormat('MMM dd, yyyy').format(req.startDate)} - ${DateFormat('MMM dd, yyyy').format(req.endDate)}",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (req.reason != null && req.reason!.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req.reason!,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    "$duration day${duration > 1 ? 's' : ''}",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    "Submitted ${DateFormat('MMM dd').format(req.startDate)}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}