import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/specialist_api.dart';
import '../theme/app_colors.dart';

class AddSessionScreen extends StatefulWidget {
  final String? preSelectedDate;
  final List<String> preSelectedFocusAreas;
  final int? childId;
  final String? childName;

  const AddSessionScreen({
    super.key,
    this.preSelectedDate,
    this.preSelectedFocusAreas = const [],
    this.childId,
    this.childName,
  });

  @override
  State<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  // Data
  List<dynamic> eligibleChildren = [];
  List<dynamic> sessionTypes = [];
  List<String> availableSlots = [];
  bool isLoadingChildren = true;
  bool isLoadingSessionTypes = true;
  bool isLoadingSlots = false;
  String? errorMessage;

  // Selected values
  Set<int> selectedChildIds = {};
  int? selectedSessionTypeId;
  DateTime? selectedDate;
  String? selectedTime;
  String sessionType = 'Onsite';
  TextEditingController notesController = TextEditingController();

  // Focus areas from AI recommendations
  List<String> focusAreas = [];

  // 🔥 متغير لتتبع إذا كان الطفل محدداً تلقائياً
  bool isAutoSelected = false;

  @override
  void initState() {
    super.initState();
    print('🚀 AddSessionScreen initialized');
    print('📋 Received data:');
    print('   - preSelectedDate: ${widget.preSelectedDate}');
    print('   - preSelectedFocusAreas: ${widget.preSelectedFocusAreas}');
    print('   - childId: ${widget.childId}');
    print('   - childName: ${widget.childName}');

    _initializePreSelectedData();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('🔄 AddSessionScreen dependencies changed');

    // تأكد من تحميل البيانات بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    print('📥 Loading data...');
    await Future.wait([
      _loadEligibleChildren(),
      _loadSessionTypes(),
    ]);

    // 🔥 بعد تحميل الأطفال، تحقق من التحديد التلقائي
    if (widget.childId != null && !selectedChildIds.contains(widget.childId)) {
      setState(() {
        selectedChildIds.add(widget.childId!);
        isAutoSelected = true;
      });
      print('✅ Force auto-selected child after data load: ${widget.childId}');
    }
  }

  void _initializePreSelectedData() {
    print('🎯 Initializing pre-selected data...');

    // التحقق من التاريخ المسبق
    if (widget.preSelectedDate != null) {
      print('📅 Processing pre-selected date: ${widget.preSelectedDate}');

      try {
        final date = DateTime.parse(widget.preSelectedDate!);
        setState(() {
          selectedDate = date;
        });
        print('✅ Date successfully set to: $selectedDate');

        // تحميل الأوقات المتاحة فوراً
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadAvailableSlots();
        });
      } catch (e) {
        print('❌ Error parsing date: $e');
        // استخدام تاريخ افتراضي إذا فشل التحليل
        setState(() {
          selectedDate = DateTime.now().add(Duration(days: 1));
        });
      }
    } else {
      print('❌ No pre-selected date provided');
    }
  }

  Future<void> _loadEligibleChildren() async {
    if (!mounted) return;

    setState(() {
      isLoadingChildren = true;
      errorMessage = null;
    });

    try {
      final response = await SpecialistService.getEligibleChildren();
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          eligibleChildren = response['data'] ?? [];

          // 🔥 تحديد الطفل تلقائياً بعد تحميل البيانات
          if (widget.childId != null &&
              !selectedChildIds.contains(widget.childId)) {
            selectedChildIds.add(widget.childId!);
            isAutoSelected = true;
            print('✅ Auto-selected child: ${widget.childId}');
          }

          isLoadingChildren = false;
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load children';
          isLoadingChildren = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error loading children: ${e.toString()}';
        isLoadingChildren = false;
      });
    }
  }

  Future<void> _loadSessionTypes() async {
    if (!mounted) return;

    setState(() {
      isLoadingSessionTypes = true;
    });

    try {
      final response = await SpecialistService.getAvailableSessionTypes();
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          sessionTypes = response['data'] ?? [];
          isLoadingSessionTypes = false;
        });
      } else {
        setState(() {
          isLoadingSessionTypes = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingSessionTypes = false;
      });
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (selectedDate == null) return;
    if (!mounted) return;

    setState(() {
      isLoadingSlots = true;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      final response = await SpecialistService.getAvailableSlots(dateStr);
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          availableSlots =
              List<String>.from(response['data']['available_slots'] ?? []);
          selectedTime = null;
          isLoadingSlots = false;
        });
      } else {
        setState(() {
          availableSlots = [];
          selectedTime = null;
          isLoadingSlots = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        availableSlots = [];
        selectedTime = null;
        isLoadingSlots = false;
      });
    }
  }

  Future<void> _submitSession() async {
    if (widget.preSelectedDate != null && selectedDate != null) {
    final aiDate = DateTime.parse(widget.preSelectedDate!);
    if (selectedDate != aiDate) {
      // طلب تأكيد إذا غير التاريخ الموصى به
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Change AI Recommended Date?'),
          content: Text('You are using a different date than the AI recommendation. Do you want to proceed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Use AI Date'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Proceed Anyway'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) {
        // العودة للتاريخ الموصى به
        setState(() {
          selectedDate = DateTime.parse(widget.preSelectedDate!);
          selectedTime = null;
        });
        await _loadAvailableSlots();
        return;
      }
    }
  }
    if (selectedChildIds.isEmpty) {
      _showError('Please select at least one child');
      return;
    }

    if (selectedSessionTypeId == null) {
      _showError('Please select a session type');
      return;
    }

    if (selectedDate == null) {
      _showError('Please select a date');
      return;
    }

    if (selectedTime == null) {
      _showError('Please select a time');
      return;
    }

    // Format date and time
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);

    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final response = await SpecialistService.addSessionsForChildren(
        childIds: selectedChildIds.toList(),
        sessionTypeId: selectedSessionTypeId!,
        date: dateStr,
        time: '$selectedTime:00',
        sessionType: sessionType,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (response['success'] == true) {
        _showSuccess(
            'Sessions created successfully. Approval requests sent to parents');
        // Reset form
        if (mounted) {
          setState(() {
            selectedChildIds.clear();
            selectedSessionTypeId = null;
            selectedDate = null;
            selectedTime = null;
            notesController.clear();
          });
        }
        // Navigate back after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        _showError(response['message'] ?? 'Failed to create sessions');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      _showError('Error creating sessions: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Add New Session',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recommended Focus Areas
              if (focusAreas.isNotEmpty) _buildRecommendedFocusAreas(),

              // Error message
              if (errorMessage != null) _buildErrorMessage(),

              // Children Selection Section
              _buildSectionTitle('Select Children'),
              if (isLoadingChildren)
                _buildLoadingIndicator()
              else if (eligibleChildren.isEmpty)
                _buildEmptyState('No eligible children found')
              else
                _buildChildrenList(),

              const SizedBox(height: 24),

              // Session Type Selection
              _buildSectionTitle('Select Session Type'),
              if (isLoadingSessionTypes)
                _buildLoadingIndicator()
              else if (sessionTypes.isEmpty)
                _buildEmptyState('No session types available')
              else
                _buildSessionTypesList(),

              const SizedBox(height: 24),

              // Date and Time Selection
              _buildSectionTitle('Select Date & Time'),
              _buildDateTimeSelection(),

              const SizedBox(height: 24),

              // Session Type (Online/Onsite)
              _buildSectionTitle('Session Location Type'),
              _buildSessionTypeToggle(),

              const SizedBox(height: 24),

              // Notes
              _buildSectionTitle('Notes (Optional)'),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add additional notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              _buildSubmitButton(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 الدالة المفقودة - إضافة زر الإرسال
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitSession,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Add Sessions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Widget for recommended focus areas
  Widget _buildRecommendedFocusAreas() {
    final hasRecommendations =
        focusAreas.isNotEmpty || widget.childName != null;

    if (!hasRecommendations) return SizedBox();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.green[700], size: 24),
              SizedBox(width: 12),
              Text(
                'AI Recommended Session',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (widget.childName != null)
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.green[700], size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Child: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.childName!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          if (focusAreas.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focus Areas:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: focusAreas
                        .map((area) => Chip(
                              label: Text(area),
                              backgroundColor: Colors.green[100],
                              labelStyle: TextStyle(color: Colors.green[800]),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 8),
          Text(
            'This session has been pre-configured based on AI progress analysis',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textGray,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildChildrenList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: eligibleChildren.map((child) {
          final childId = child['child_id'] as int;
          final isSelected = selectedChildIds.contains(childId);
          final isAutoSelectedChild =
              isAutoSelected && childId == widget.childId;
          final childName = child['full_name'] ?? 'Unknown';
          final childCondition = child['condition'] ?? 'Not specified';

          print(
              '👶 Child in list: $childId, Selected: $isSelected, Auto: $isAutoSelectedChild');

          return Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: isAutoSelectedChild
                ? BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 2),
                  )
                : null,
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    selectedChildIds.add(childId);
                    print('➕ Added child: $childId');
                  } else {
                    selectedChildIds.remove(childId);
                    print('➖ Removed child: $childId');
                    // إذا كان الطفل محدد تلقائياً وألغى التحديد، نزيل العلامة
                    if (isAutoSelectedChild) {
                      isAutoSelected = false;
                      print('🔁 Auto-selection disabled');
                    }
                  }
                });
              },
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      childName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isAutoSelectedChild
                            ? Colors.green[800]
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (isAutoSelectedChild) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'AI Selected',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Condition: $childCondition',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12,
                    ),
                  ),
                  if (isAutoSelectedChild)
                    Text(
                      'Recommended based on progress analysis',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              secondary: isAutoSelectedChild
                  ? Icon(Icons.psychology, color: Colors.green, size: 24)
                  : Icon(Icons.person_outline,
                      color: Colors.grey[600], size: 24),
              activeColor: AppColors.primary,
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSessionTypesList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: sessionTypes.map((type) {
          final typeId = type['session_type_id'] as int;
          final isSelected = selectedSessionTypeId == typeId;
          return RadioListTile<int>(
            value: typeId,
            groupValue: selectedSessionTypeId,
            onChanged: (value) {
              setState(() {
                selectedSessionTypeId = value;
              });
            },
            title: Text(
              type['name'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Duration: ${type['duration']} min | Price: ${type['price']} JOD',
              style: const TextStyle(
                color: AppColors.textGray,
                fontSize: 12,
              ),
            ),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateTimeSelection() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        // Date picker مع تحسينات
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.green),
            title: const Text('Session Date', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedDate != null
                      ? DateFormat('EEEE, MMMM d, yyyy').format(selectedDate!)
                      : 'No date selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selectedDate != null ? Colors.green[800] : Colors.grey,
                  ),
                ),
                if (widget.preSelectedDate != null && selectedDate != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '✅ AI Recommended Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.preSelectedDate != null && selectedDate != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'AI',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green),
              ],
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.green, // header background color
                        onPrimary: Colors.white, // header text color
                        onSurface: Colors.black, // body text color
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green, // button text color
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null && mounted) {
                setState(() {
                  selectedDate = date;
                  selectedTime = null;
                });
                await _loadAvailableSlots();
                
                // إشعار عند تغيير التاريخ الموصى به
                if (widget.preSelectedDate != null && 
                    date != DateTime.parse(widget.preSelectedDate!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ You changed the AI recommended date'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
        ),
        
        const Divider(),
        
        // Time selection
        ListTile(
          leading: const Icon(Icons.access_time, color: AppColors.primary),
          title: const Text('Available Times'),
          subtitle: _buildTimeSelection(),
        ),
      ],
    ),
  );
}

  Widget _buildTimeSelection() {
    if (selectedDate == null) {
      return const Text(
        'Please select a date first',
        style: TextStyle(color: AppColors.textGray),
      );
    }

    if (isLoadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (availableSlots.isEmpty) {
      return const Text(
        'No available slots for this date',
        style: TextStyle(color: AppColors.error),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableSlots.map((slot) {
        final isSelected = selectedTime == slot;
        return ChoiceChip(
          label: Text(slot),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              selectedTime = selected ? slot : null;
            });
          },
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleOption(
              'Onsite',
              'Onsite',
              Icons.location_on,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildToggleOption(
              'Online',
              'Online',
              Icons.video_call,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, String value, IconData icon) {
    final isSelected = sessionType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          sessionType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textGray,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
