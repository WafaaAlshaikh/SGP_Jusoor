// lib/widgets/reschedule_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

class RescheduleBottomSheet extends StatefulWidget {
  final Session session;
  final VoidCallback? onRescheduled;

  const RescheduleBottomSheet({
    super.key,
    required this.session,
    this.onRescheduled,
  });

  @override
  State<RescheduleBottomSheet> createState() => _RescheduleBottomSheetState();
}

class _RescheduleBottomSheetState extends State<RescheduleBottomSheet> {
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;
  bool _loadingSlots = false;
  List<String> _availableSlots = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots();
  }

  Future<void> _loadAvailableSlots() async {
    setState(() => _loadingSlots = true);

    try {
      // TODO: Replace with actual API call to get available slots
      await Future.delayed(const Duration(seconds: 1));

      // Mock data - replace with real API response
      setState(() {
        _availableSlots = [
          '09:00 AM', '10:30 AM', '11:00 AM',
          '02:00 PM', '03:30 PM', '04:00 PM'
        ];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load available slots: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loadingSlots = false);
    }
  }

  Future<void> _rescheduleSession() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both date and time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ تحقق محسن من الحالات المسموح بها
    final allowedStatuses = ['pending', 'Pending Approval', 'upcoming', 'Scheduled'];
    final currentStatus = widget.session.displayStatus?.toLowerCase() ??
        widget.session.status?.toLowerCase() ?? '';

    print('🔍 Checking session status: ${widget.session.status}');
    print('🔍 Session display status: ${widget.session.displayStatus}');
    print('🔍 Current status for check: $currentStatus');

    if (!allowedStatuses.any((status) => currentStatus.contains(status.toLowerCase()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot reschedule - Current status: ${widget.session.displayStatus ?? widget.session.status}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ تحويل الوقت من AM/PM إلى 24 ساعة
    final convertedTime = _convertTo24HourFormat(_selectedTime!);
    print('🕒 Time conversion: $_selectedTime -> $convertedTime');

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Convert sessionId to int if needed
      final sessionId = int.tryParse(widget.session.sessionId) ?? 0;

      final success = await ApiService.rescheduleSession(
        token,
        sessionId,
        _selectedDate!,
        convertedTime, // ⬅️ استخدام الوقت المحول
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session rescheduled successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          widget.onRescheduled?.call();
        }
      } else {
        throw Exception('Failed to reschedule session');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reschedule: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

// ✅ دالة لتحويل الوقت من AM/PM إلى 24 ساعة
  String _convertTo24HourFormat(String time12Hour) {
    try {
      // إزالة المسافات الزائدة وتحويل للحروف الصغيرة
      final cleanedTime = time12Hour.trim().toUpperCase();

      // فصل الوقت عن AM/PM
      final timePart = cleanedTime.split(' ')[0];
      final period = cleanedTime.contains('PM') ? 'PM' : 'AM';

      // فصل الساعات والدقائق
      final parts = timePart.split(':');
      if (parts.length != 2) {
        throw FormatException('Invalid time format: $time12Hour');
      }

      int hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);

      // التحويل لـ 24 ساعة
      if (period == 'PM' && hours < 12) {
        hours += 12;
      } else if (period == 'AM' && hours == 12) {
        hours = 0;
      }

      // تنسيق النتيجة
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';

    } catch (e) {
      print('❌ Error converting time: $e');
      // في حالة الخطأ، ارجع الوقت كما هو (قد يحتاج المستخدم لإصلاحه)
      return time12Hour;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 24),

          // Current Session Info
          _buildCurrentSessionInfo(),
          const SizedBox(height: 24),

          // Date Selection
          _buildDateSelection(),
          const SizedBox(height: 24),

          // Time Slots
          _buildTimeSlots(),
          const SizedBox(height: 24),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  // ... باقي الدوال تبقى كما هي بدون تغيير ...
  // (نفس الدوال اللي في الكود السابق)

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Reschedule Session',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildCurrentSessionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Schedule',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.session.date} at ${widget.session.time}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'With ${widget.session.specialistName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select New Date',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a date within the next 30 days',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedDate == null
                    ? 'Choose a date'
                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedDate == null ? Colors.grey : Colors.black,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                      _selectedTime = null;
                    });
                    _loadAvailableSlots();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlots() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Time Slots',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedDate == null
                ? 'Please select a date first'
                : 'Available slots for ${_selectedDate!.day}/${_selectedDate!.month}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          if (_loadingSlots)
            const Center(child: CircularProgressIndicator()),

          if (!_loadingSlots && _selectedDate != null)
            Expanded(
              child: _availableSlots.isEmpty
                  ? _buildNoSlotsAvailable()
                  : _buildTimeSlotsGrid(),
            ),

          if (!_loadingSlots && _selectedDate == null)
            _buildSelectDatePrompt(),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.5,
      ),
      itemCount: _availableSlots.length,
      itemBuilder: (context, index) {
        final slot = _availableSlots[index];
        final isSelected = _selectedTime == slot;

        return GestureDetector(
          onTap: () => setState(() => _selectedTime = slot),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? ParentAppColors.primaryTeal : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? ParentAppColors.primaryTeal : Colors.grey[300]!,
              ),
            ),
            child: Center(
              child: Text(
                slot,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoSlotsAvailable() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Available Slots',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No available time slots for ${_selectedDate!.day}/${_selectedDate!.month}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadAvailableSlots,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectDatePrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Select a Date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please select a date to see available time slots',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _rescheduleSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: ParentAppColors.primaryTeal,
            ),
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text(
              'Reschedule',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}