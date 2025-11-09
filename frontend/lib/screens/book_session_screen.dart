// lib/screens/book_session_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../models/child_model.dart';
import '../models/booking_models.dart' as models;
import '../services/booking_service.dart';
import '../services/api_service.dart';

enum BookingStep { child, session, dateTime, review }

class BookSessionScreen extends StatefulWidget {
  const BookSessionScreen({super.key});

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  // Data lists
  List<Child> _children = [];
  List<Child> _filteredChildren = [];
  List<models.SessionType> _sessionTypes = [];
  List<models.AvailableSlot> _availableSlots = [];

  // Selected values
  Child? _selectedChild;
  int? _childInstitutionId;
  models.SessionType? _selectedSessionType;
  DateTime? _selectedDate;
  models.AvailableSlot? _selectedSlot;
  String _parentNotes = '';
  String _searchQuery = '';

  // New features
  double _totalPrice = 0.0;
  double _discount = 0.0;
  bool _hasInsurance = false;
  String _emergencyContact = '';
  String _specialRequirements = '';
  bool _hasEmergency = false;
  bool _isRecurring = false;
  int _recurringWeeks = 1;
  List<String> _recurringDays = [];

  // UI state
  bool _isLoading = false;
  bool _loadingChildren = false;
  bool _loadingSessionTypes = false;
  bool _loadingSlots = false;
  BookingStep _currentStep = BookingStep.child;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _loadDraft();
  }

  // ============ DRAFT MANAGEMENT ============
  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString('booking_draft');
      if (draftJson != null && mounted) {
        final draft = json.decode(draftJson);
        // يمكنك تحميل البيانات المحفوظة هنا
        print('Loaded draft: $draft');
      }
    } catch (e) {
      print('Error loading draft: $e');
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'childId': _selectedChild?.id,
        'sessionTypeId': _selectedSessionType?.sessionTypeId,
        'selectedDate': _selectedDate?.toIso8601String(),
        'slotTime': _selectedSlot?.time,
        'parentNotes': _parentNotes,
        'specialRequirements': _specialRequirements,
        'emergencyContact': _emergencyContact,
        'hasInsurance': _hasInsurance,
        'isRecurring': _isRecurring,
        'recurringWeeks': _recurringWeeks,
        'recurringDays': _recurringDays,
      };
      await prefs.setString('booking_draft', json.encode(draft));
      _hasUnsavedChanges = false;
    } catch (e) {
      print('Error saving draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('booking_draft');
      _hasUnsavedChanges = false;
    } catch (e) {
      print('Error clearing draft: $e');
    }
  }

  // ============ FORM VALIDATION ============
  bool _isFormValid() {
    return _selectedChild != null &&
        _selectedSessionType != null &&
        _selectedSlot != null &&
        _selectedDate != null;
  }

  double _calculateProgress() {
    int completed = 0;
    if (_selectedChild != null) completed++;
    if (_selectedSessionType != null) completed++;
    if (_selectedDate != null) completed++;
    if (_selectedSlot != null) completed++;
    return completed / 4;
  }

  // ============ INTERNET CHECK ============
  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;

      if (!hasConnection && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return hasConnection;
    } catch (e) {
      print('Error checking connectivity: $e');
      return true; // افترض وجود اتصال في حالة الخطأ
    }
  }

  // ============ DATA LOADING ============
  Future<void> _loadChildren() async {
    if (!await _checkInternetConnection()) return;

    setState(() {
      _loadingChildren = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final childrenData = await ApiService.getChildren(token: token);
      final allChildren = (childrenData['data'] as List).map((c) => Child.fromJson(c)).toList();

      final registeredChildren = allChildren.where((child) =>
      child.registrationStatus == 'Approved' &&
          child.currentInstitutionId != null
      ).toList();

      setState(() {
        _children = registeredChildren;
        _filteredChildren = registeredChildren;
        _loadingChildren = false;
      });

      if (registeredChildren.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No children registered with institutions yet'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error loading children: $e');
      setState(() {
        _loadingChildren = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load children: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterChildren(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredChildren = _children;
      } else {
        _filteredChildren = _children.where((child) =>
        child.fullName.toLowerCase().contains(query.toLowerCase()) ||
            (child.condition?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (child.currentInstitutionName?.toLowerCase().contains(query.toLowerCase()) ?? false)
        ).toList();
      }
    });
  }



  // List<models.SessionType> _filterSessionTypesByCondition(
  //     List<models.SessionType> sessionTypes,
  //     String? childCondition
  //     ) {
  //   if (childCondition == null || childCondition.isEmpty) {
  //     return sessionTypes;
  //   }
  //
  //   final conditionSessionMap = {
  //     'ASD': ['Behavioral Therapy', 'Speech Therapy', 'Occupational Therapy'],
  //     'ADHD': ['Behavioral Therapy', 'Occupational Therapy'],
  //     'Down Syndrome': ['Speech Therapy', 'Physical Therapy', 'Occupational Therapy'],
  //     'Speech & Language Disorder': ['Speech Therapy'],
  //   };
  //
  //   final suitableTypes = conditionSessionMap[childCondition] ?? [];
  //
  //   if (suitableTypes.isEmpty) {
  //     return sessionTypes;
  //   }
  //
  //   return sessionTypes.where((type) =>
  //       suitableTypes.any((suitable) =>
  //           type.name.toLowerCase().contains(suitable.toLowerCase())
  //       )
  //   ).toList();
  // }

  Future<void> _loadAvailableSlots() async {
    if (_selectedSessionType == null || _selectedDate == null || _childInstitutionId == null) return;

    if (!await _checkInternetConnection()) return;

    setState(() {
      _loadingSlots = true;
      _availableSlots = [];
      _selectedSlot = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

      final response = await BookingService.getAvailableSlots(
        token: token,
        institutionId: _childInstitutionId!,
        sessionTypeId: _selectedSessionType!.sessionTypeId,
        date: dateStr,
      );

      final slotsData = response['available_slots'] as List;
      final slots = slotsData.map((json) => models.AvailableSlot.fromJson(json)).toList();

      setState(() {
        _availableSlots = slots;
        _loadingSlots = false;
      });

      if (slots.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No available slots for selected date'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error loading slots: $e');
      setState(() {
        _loadingSlots = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load available slots: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculatePrice() {
    if (_selectedSessionType == null) return;

    double basePrice = _selectedSessionType!.price;

    _discount = 0.0;
    if (_hasInsurance) {
      _discount = basePrice * 0.2;
    }

    _totalPrice = basePrice - _discount;
    setState(() {});
  }

  bool _isDateValid(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    return difference >= 1;
  }

  void _showDateWarning() {
    if (_selectedDate != null && !_isDateValid(_selectedDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future date'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ============ STEP MANAGEMENT ============
  void _nextStep() {
    setState(() {
      switch (_currentStep) {
        case BookingStep.child:
          if (_selectedChild != null) _currentStep = BookingStep.session;
          break;
        case BookingStep.session:
          if (_selectedSessionType != null) _currentStep = BookingStep.dateTime;
          break;
        case BookingStep.dateTime:
          if (_selectedDate != null && _selectedSlot != null) _currentStep = BookingStep.review;
          break;
        case BookingStep.review:
          break;
      }
    });
    _saveDraft();
  }

  void _previousStep() {
    setState(() {
      switch (_currentStep) {
        case BookingStep.child:
          break;
        case BookingStep.session:
          _currentStep = BookingStep.child;
          break;
        case BookingStep.dateTime:
          _currentStep = BookingStep.session;
          break;
        case BookingStep.review:
          _currentStep = BookingStep.dateTime;
          break;
      }
    });
  }

  // ============ BOOKING FLOW ============
  void _showBookingSummary() {
    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required fields')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Booking', style: TextStyle(fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryItem('Child', _selectedChild!.fullName),
              _buildSummaryItem('Institution', _selectedChild!.currentInstitutionName ?? 'Not specified'),
              _buildSummaryItem('Session Type', '${_selectedSessionType!.name} (${_selectedSessionType!.duration} min)'),
              _buildSummaryItem('Specialist', _selectedSlot!.specialistName),
              _buildSummaryItem('Date', '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
              _buildSummaryItem('Time', _selectedSlot!.time),
              _buildSummaryItem('Price', '\$${_selectedSessionType!.price}'),
              if (_discount > 0)
                _buildSummaryItem('Insurance Discount', '-\$$_discount'),
              _buildSummaryItem('Total Amount', '\$$_totalPrice'),
              if (_isRecurring)
                _buildSummaryItem('Recurring', '$_recurringWeeks weeks'),
              if (_parentNotes.isNotEmpty)
                _buildSummaryItem('Notes', _parentNotes),
              if (_specialRequirements.isNotEmpty)
                _buildSummaryItem('Special Requirements', _specialRequirements),
              if (_hasEmergency && _emergencyContact.isNotEmpty)
                _buildSummaryItem('Emergency Contact', _emergencyContact),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bookSession();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Confirm Booking', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

// ⬇️⬇️⬇️ تحديث دالة الحجز في الـ State
  Future<void> _bookSession() async {
    if (!_isFormValid()) {
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

      final bookingResponse = await BookingService.bookSession(
        token: token,
        childId: _selectedChild!.id,
        institutionId: _childInstitutionId!,
        sessionTypeId: _selectedSessionType!.sessionTypeId,
        specialistId: _selectedSlot!.specialistId,
        date: dateStr,
        time: _selectedSlot!.time,
        parentNotes: _parentNotes.isNotEmpty ? _parentNotes : null,
      );

      // ⬇️⬇️⬇️ التصحيح هنا - تحقق من success بشكل صحيح
      if (bookingResponse.success) {
        await _clearDraft();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bookingResponse.message),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, {
          'success': true,
          'session_id': bookingResponse.sessionId,
          'status': bookingResponse.status,
          'message': bookingResponse.message,
        });
      } else {
        // عرض رسالة الخطأ للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bookingResponse.message),
            backgroundColor: Colors.red,
          ),
        );
      }

    } catch (e) {
      print('❌ Booking error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to book session: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // ⬇️⬇️⬇️ تحديث دالة جلب أنواع الجلسات
// lib/screens/book_session_screen.dart - تحديث _loadSessionTypes

  Future<void> _loadSessionTypes(Child child) async {
    if (child.currentInstitutionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Child is not registered with any institution'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _loadingSessionTypes = true;
      _sessionTypes = [];
      _selectedSessionType = null;
      _availableSlots = [];
      _selectedSlot = null;
      _childInstitutionId = child.currentInstitutionId;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // ⬇️⬇️⬇️ استبدل الاستدعاء القديم بالجديد
      final sessionTypes = await BookingService.getSuitableSessionTypes(
        token,
        child.id, // ⬅️ نرسل child_id بدل institution_id
      );

      setState(() {
        _sessionTypes = sessionTypes;
        _loadingSessionTypes = false;
      });

      if (sessionTypes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No suitable session types available for ${child.condition ?? "child\'s condition"}'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // عرض معلومات إضافية عن الجلسات المناسبة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${sessionTypes.length} suitable session types'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading session types: $e');
      setState(() { _loadingSessionTypes = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load session types: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildErrorWidget(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.red[700], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, DateTime date) {
    return FilterChip(
      label: Text(label),
      selected: _selectedDate?.day == date.day && _selectedDate?.month == date.month,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedDate = date;
            _availableSlots = [];
            _selectedSlot = null;
          });
          _showDateWarning();
          if (_selectedSessionType != null) {
            _loadAvailableSlots();
          }
        }
      },
    );
  }

  // ============ WILL POP SCOPE ============
  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('You have unsaved changes. Are you sure you want to leave?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      return shouldLeave ?? false;
    }
    return true;
  }

  // ============ BUILD METHOD ============
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Book New Session'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          actions: [
            if (_hasUnsavedChanges)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.save, color: Colors.orange),
              ),
          ],
        ),
        body: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _calculateProgress(),
                    backgroundColor: Colors.grey[200],
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_calculateProgress() * 100).toStringAsFixed(0)}% Complete',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Stepper
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCurrentStep(),
                    const SizedBox(height: 20),
                    _buildNavigationButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case BookingStep.child:
        return _buildChildStep();
      case BookingStep.session:
        return _buildSessionStep();
      case BookingStep.dateTime:
        return _buildDateTimeStep();
      case BookingStep.review:
        return _buildReviewStep();
    }
  }

  Widget _buildChildStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Select Child',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        const SizedBox(height: 16),

        // Search Bar
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search children by name, condition, or institution...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: _filterChildren,
        ),
        const SizedBox(height: 16),

        _buildChildSelection(),
      ],
    );
  }

  Widget _buildSessionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Select Session Type',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        const SizedBox(height: 16),
        _buildSessionTypeSelection(),
        if (_selectedSessionType != null) ...[
          const SizedBox(height: 16),
          _buildPriceSummary(),
        ],
      ],
    );
  }

  Widget _buildDateTimeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. Select Date & Time',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        const SizedBox(height: 16),
        _buildDateSelection(),
        if (_selectedSessionType != null && _selectedDate != null) ...[
          const SizedBox(height: 16),
          _buildRecurringSession(),
          const SizedBox(height: 16),
          _buildAvailableSlots(),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4. Review & Confirm',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        const SizedBox(height: 16),
        _buildNotesField(),
        const SizedBox(height: 16),
        _buildSpecialRequirements(),
        const SizedBox(height: 16),
        _buildEmergencyContact(),
        const SizedBox(height: 16),
        _buildDocumentUpload(),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep != BookingStep.child)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              child: const Text('Back'),
            ),
          ),
        if (_currentStep != BookingStep.child) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (_currentStep == BookingStep.review) {
                _showBookingSummary();
              } else {
                _nextStep();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
            ),
            child: Text(
              _currentStep == BookingStep.review ? 'Review & Book' : 'Next',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ============ EXISTING WIDGET METHODS (محدثة) ============
  Widget _buildChildSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Child',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _loadingChildren
            ? const LinearProgressIndicator()
            : _filteredChildren.isEmpty
            ? _buildErrorWidget(
          _searchQuery.isEmpty
              ? 'No children registered with institutions'
              : 'No children found for "$_searchQuery"',
          _loadChildren,
        )
            : Container(
          constraints: BoxConstraints(maxHeight: 120), // ⬅️ حد أقصى للارتفاع
          child: DropdownButtonFormField<Child>(
            value: _selectedChild,
            items: _filteredChildren.map((child) {
              return DropdownMenuItem<Child>(
                value: child,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // ⬅️ مهم
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2), // ⬅️ مسافة صغيرة
                      Text(
                        'Age: ${child.age} • ${child.condition ?? "No diagnosis"}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (child.currentInstitutionName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Institution: ${child.currentInstitutionName}',
                          style: const TextStyle(fontSize: 11, color: Colors.teal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Status: ${child.registrationStatus}',
                        style: TextStyle(
                          fontSize: 11,
                          color: child.registrationStatus == 'Approved'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (child) {
              setState(() {
                _selectedChild = child;
                _sessionTypes = [];
                _selectedSessionType = null;
                _availableSlots = [];
                _selectedSlot = null;
                _selectedDate = null;
                _totalPrice = 0.0;
                _discount = 0.0;
                _hasUnsavedChanges = true;
              });
              if (child != null) {
                _loadSessionTypes(child);
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Choose a child',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            isExpanded: true, // ⬅️ مهم للتجنب overflow
          ),
        ),
      ],
    );
  }
  Widget _buildInstitutionInfo() {
    return Card(
      elevation: 2,
      color: Colors.teal[50],
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.local_hospital, color: Colors.teal, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registered Institution',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  Text(
                    'Child will be booked with their registered institution',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        if (_selectedChild != null)
          _buildChildInfoCard(), // ⬅️ أضف هذه البطاقة الجديدة

        const SizedBox(height: 8),

        _loadingSessionTypes
            ? const LinearProgressIndicator()
            : _selectedChild == null
            ? Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Please select a child first',
            style: TextStyle(color: Colors.grey),
          ),
        )
            : _sessionTypes.isEmpty
            ? _buildErrorWidget(
          'No suitable session types available for ${_selectedChild!.condition ?? "child\'s condition"}',
              () => _loadSessionTypes(_selectedChild!),
        )
            : Column(
          children: [
            ..._sessionTypes.map((type) => _buildSessionTypeCard(type)),
          ],
        ),
      ],
    );
  }


  Widget _buildChildInfoCard() {
    return Card(
      elevation: 2,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.child_care, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  _selectedChild!.fullName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_selectedChild!.condition != null)
              Text(
                'Condition: ${_selectedChild!.condition}',
                style: const TextStyle(fontSize: 12),
              ),
            if (_selectedChild!.currentInstitutionName != null)
              Text(
                'Institution: ${_selectedChild!.currentInstitutionName}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

// ⬇️⬇️⬇️ أضف هذه الدالة الجديدة لعرض كل جلسة كبطاقة
  Widget _buildSessionTypeCard(models.SessionType type) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: _selectedSessionType?.sessionTypeId == type.sessionTypeId
          ? Colors.teal[50]
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(
          _getSessionTypeIcon(type.category),
          color: Colors.teal,
          size: 24,
        ),
        title: Text(
          type.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${type.duration} min • \$${type.price} • ${type.category}',
              style: const TextStyle(fontSize: 12),
            ),
            if (type.suitabilityReason.isNotEmpty)
              Text(
                type.suitabilityReason,
                style: TextStyle(
                  fontSize: 11,
                  color: type.isSuitable ? Colors.green : Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
            Text(
              'Specialist: ${type.specialistSpecialization}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: _selectedSessionType?.sessionTypeId == type.sessionTypeId
            ? const Icon(Icons.check_circle, color: Colors.teal, size: 24)
            : null,
        onTap: () {
          setState(() {
            _selectedSessionType = type;
            _availableSlots = [];
            _selectedSlot = null;
            _hasUnsavedChanges = true;
          });
          _calculatePrice();
          if (_selectedDate != null) {
            _loadAvailableSlots();
          }
        },
      ),
    );
  }

// ⬇️⬇️⬇️ دالة مساعدة للأيقونات
  IconData _getSessionTypeIcon(String category) {
    switch (category.toLowerCase()) {
      case 'speech':
        return Icons.record_voice_over;
      case 'behavioral':
        return Icons.psychology;
      case 'occupational':
        return Icons.accessible;
      case 'educational':
        return Icons.school;
      default:
        return Icons.medical_services;
    }
  }


  Widget _buildPriceSummary() {
    _calculatePrice();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildPriceRow('Session Price', '\$${_selectedSessionType!.price}'),
            if (_discount > 0)
              _buildPriceRow('Insurance Discount', '-\$$_discount'),
            const Divider(height: 16),
            _buildPriceRow('Total Amount', '\$$_totalPrice', isTotal: true),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _hasInsurance,
                  onChanged: (value) {
                    setState(() {
                      _hasInsurance = value ?? false;
                      _hasUnsavedChanges = true;
                    });
                    _calculatePrice();
                  },
                ),
                const Text('I have insurance coverage', style: TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.teal : Colors.black,
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
          'Select Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Quick Date Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildDateChip('Tomorrow', DateTime.now().add(const Duration(days: 1))),
            _buildDateChip('In 3 days', DateTime.now().add(const Duration(days: 3))),
            _buildDateChip('Next week', DateTime.now().add(const Duration(days: 7))),
          ],
        ),
        const SizedBox(height: 12),

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
                  border: OutlineInputBorder(),
                  hintText: 'Choose a date',
                  suffixIcon: Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                      _availableSlots = [];
                      _selectedSlot = null;
                      _hasUnsavedChanges = true;
                    });
                    _showDateWarning();
                    if (_selectedSessionType != null) {
                      _loadAvailableSlots();
                    }
                  }
                },
              ),
            ),
            if (_selectedSessionType != null && _selectedDate != null)
              IconButton(
                icon: const Icon(Icons.refresh, size: 24),
                onPressed: _loadAvailableSlots,
                tooltip: 'Refresh available slots',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecurringSession() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _isRecurring,
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value ?? false;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
                const Text(
                  'Make this a recurring session',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              const Text('Repeat for:', style: TextStyle(fontSize: 14)),
              Slider(
                value: _recurringWeeks.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                label: '$_recurringWeeks weeks',
                onChanged: (value) {
                  setState(() {
                    _recurringWeeks = value.toInt();
                    _hasUnsavedChanges = true;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text('Select days:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) {
                  final isSelected = _recurringDays.contains(day);
                  return FilterChip(
                    label: Text(day, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _recurringDays.add(day);
                        } else {
                          _recurringDays.remove(day);
                        }
                        _hasUnsavedChanges = true;
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableSlots() {
    if (_selectedSessionType == null || _selectedDate == null) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Time Slots',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        if (_loadingSlots)
          const Center(child: CircularProgressIndicator()),

        if (!_loadingSlots && _availableSlots.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availableSlots.length,
              itemBuilder: (context, index) {
                final slot = _availableSlots[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: _selectedSlot?.time == slot.time
                      ? Colors.teal[50]
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    leading: const Icon(Icons.access_time, color: Colors.teal, size: 20),
                    title: Text(
                      '${slot.time} - ${slot.specialistName}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${slot.duration} min • \$${slot.price}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Day: ${slot.dayOfWeek}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: _selectedSlot?.time == slot.time
                        ? const Icon(Icons.check_circle, color: Colors.teal, size: 20)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedSlot = slot;
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),
                );
              },
            ),
          ),

        if (!_loadingSlots && _availableSlots.isEmpty)
          _buildErrorWidget(
            'No available slots for selected date',
            _loadAvailableSlots,
          ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Notes (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Any special requests or notes for the specialist...',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          maxLines: 3,
          onChanged: (value) {
            _parentNotes = value;
            _hasUnsavedChanges = true;
          },
        ),
      ],
    );
  }

  Widget _buildSpecialRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Special Requirements',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: const InputDecoration(
            hintText: 'Any allergies, medications, or special needs...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          maxLines: 2,
          onChanged: (value) {
            _specialRequirements = value;
            _hasUnsavedChanges = true;
          },
        ),
      ],
    );
  }

  Widget _buildEmergencyContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _hasEmergency,
              onChanged: (value) {
                setState(() {
                  _hasEmergency = value ?? false;
                  _hasUnsavedChanges = true;
                });
              },
            ),
            const Text(
              'Add Emergency Contact Information',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (_hasEmergency)
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Emergency Contact Number',
              border: OutlineInputBorder(),
              hintText: '+962XXXXXXXXX',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            onChanged: (value) {
              _emergencyContact = value;
              _hasUnsavedChanges = true;
            },
          ),
      ],
    );
  }

  Widget _buildDocumentUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Documents (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Medical reports, assessments, or previous session notes',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file, size: 18),
          label: const Text('Attach Files', style: TextStyle(fontSize: 14)),
          onPressed: () {
            // TODO: Implement file picker
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File upload feature coming soon')),
            );
          },
        ),
      ],
    );
  }
}