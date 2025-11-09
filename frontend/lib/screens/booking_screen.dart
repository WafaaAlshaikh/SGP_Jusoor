// screens/booking_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../models/booking_models.dart'as models;
import '../services/booking_service.dart'as service;

class BookingScreen extends StatefulWidget {
  final Child child;
  final int institutionId;

  const BookingScreen({
    super.key,
    required this.child,
    required this.institutionId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<models.SessionType> _sessionTypes = []; // ⬅️ استخدم models.
  models.SessionType? _selectedSessionType; // ⬅️ استخدم models.
  DateTime? _selectedDate;
  List<models.AvailableSlot> _availableSlots = []; // ⬅️ استخدم models.
  models.AvailableSlot? _selectedSlot; // ⬅️ استخدم models.
  String _parentNotes = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSessionTypes();
  }

  Future<void> _loadSessionTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final sessionTypes = await service.BookingService.getInstitutionSessionTypes(
          token,
          widget.institutionId
      );

      setState(() {
        _sessionTypes = sessionTypes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load session types: $e')),
        );
      }
    }
  }

// في booking_screen.dart - عدل دالة _loadAvailableSlots
  Future<void> _loadAvailableSlots() async {
    print('🎯 _loadAvailableSlots called');
    print('📅 Selected Date: $_selectedDate');
    print('🏥 Institution ID: ${widget.institutionId}');
    print('📋 Session Type ID: ${_selectedSessionType?.sessionTypeId}');

    if (_selectedSessionType == null || _selectedDate == null) return;

    setState(() { _isLoading = true; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

      final response = await service.BookingService.getAvailableSlots(
        token: token,
        institutionId: widget.institutionId,
        sessionTypeId: _selectedSessionType!.sessionTypeId,
        date: dateStr,
      );

      // ⬇️⬇️⬇️ التصحيح هنا ⬇️⬇️⬇️
      final slotsData = response['available_slots'] as List;
      print('🔍 Raw slots data: $slotsData'); // Debugging

      final slots = slotsData.map((json) => models.AvailableSlot.fromJson(json)).toList(); // ⬅️ استخدم models.
      setState(() {
        _availableSlots = slots;
        _selectedSlot = null;
      });

    } catch (e) {
      print('❌ Error loading slots: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load available slots: $e')),
        );
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }
// في booking_screen.dart - عدل دالة _bookSession
  Future<void> _bookSession() async {
    if (_selectedSessionType == null || _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required fields')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

      print('🎯 Booking Debug:'); // ⬅️ أضف debugging
      print(' - Child ID: ${widget.child.id}');
      print(' - Institution ID: ${widget.institutionId}');
      print(' - Session Type ID: ${_selectedSessionType!.sessionTypeId}');
      print(' - Specialist ID: ${_selectedSlot!.specialistId}');
      print(' - Date: $dateStr');
      print(' - Time: ${_selectedSlot!.time}');

      final response = await service.BookingService.bookSession(
        token: token,
        childId: widget.child.id, // ⬅️ تأكد من هذا
        institutionId: widget.institutionId,
        sessionTypeId: _selectedSessionType!.sessionTypeId,
        specialistId: _selectedSlot!.specialistId,
        date: dateStr,
        time: _selectedSlot!.time,
        parentNotes: _parentNotes.isNotEmpty ? _parentNotes : null,
      );

      print('✅ Booking Response: $response');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session booked successfully - pending approval')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Booking Error: $e'); // ⬅️ شوف الخطأ بالضبط
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book session: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Session'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الطفل
            Card(
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal[100],
                  child: Text(
                    widget.child.fullName.isNotEmpty ? widget.child.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  widget.child.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Age: ${widget.child.age} • ${widget.child.condition ?? "No diagnosis"}'),
              ),
            ),

            const SizedBox(height: 20),

            // اختيار نوع الجلسة
            DropdownButtonFormField<models.SessionType>( // ⬅️ استخدم models.
              value: _selectedSessionType,
              items: _sessionTypes.map((type) {
                return DropdownMenuItem<models.SessionType>( // ⬅️ استخدم models.
                  value: type,
                  child: Text('${type.name} - ${type.duration}min - \$${type.price}'),
                );
              }).toList(),
              onChanged: (type) {
                setState(() {
                  _selectedSessionType = type;
                  _availableSlots = [];
                  _selectedSlot = null;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Session Type',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // اختيار التاريخ
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                        text: _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : ''
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                          _availableSlots = [];
                          _selectedSlot = null;
                        });
                        _loadAvailableSlots();
                      }
                    },
                  ),
                ),

                if (_selectedSessionType != null && _selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadAvailableSlots,
                    tooltip: 'Refresh available slots',
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // الأوقات المتاحة
            // في جزء عرض الأوقات المتاحة - عدل ليكون كالتالي:
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_availableSlots.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Time Slots (${_availableSlots.length}):',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _availableSlots.length,
                        itemBuilder: (context, index) {
                          final slot = _availableSlots[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: _selectedSlot?.time == slot.time
                                ? Colors.teal[50]
                                : null,
                            child: ListTile(
                              leading: const Icon(Icons.access_time, color: Colors.teal),
                              title: Text('${slot.time} - ${slot.specialistName}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${slot.duration} min • \$${slot.price}'),
                                  Text('Day: ${slot.dayOfWeek}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              trailing: _selectedSlot?.time == slot.time
                                  ? const Icon(Icons.check_circle, color: Colors.teal)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedSlot = slot;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else if (_selectedSessionType != null && _selectedDate != null)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No available slots for selected date',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        'Try selecting a different date or session type',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                const Center(
                  child: Text('Select session type and date to see available slots'),
                ),

            const SizedBox(height: 16),

            // ملاحظات الأهل
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Any special requests or notes...',
              ),
              maxLines: 3,
              onChanged: (value) => _parentNotes = value,
            ),

            const SizedBox(height: 20),

            // زر الحجز
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text(
                  'Book Session',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}