import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddSessionScreen extends StatefulWidget {
  const AddSessionScreen({Key? key}) : super(key: key);

  @override
  State<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  // بيانات النموذج
  final _formKey = GlobalKey<FormState>();
  int? _selectedChildId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _duration = 60;
  double _price = 0.0;
  String _sessionType = 'Onsite';
  bool _isLoading = false;

  // بيانات وهمية للعرض
  final List<Map<String, dynamic>> _children = [
    {'id': 1, 'name': 'أحمد محمد', 'age': 8, 'disability': 'توحد'},
    {'id': 2, 'name': 'سارة خالد', 'age': 6, 'disability': 'صعوبات تعلم'},
    {'id': 3, 'name': 'ياسمين علي', 'age': 7, 'disability': 'إعاقة سمعية'},
    {'id': 4, 'name': 'محمد حسن', 'age': 9, 'disability': 'شلل دماغي'},
  ];

  // بيانات المؤسسة (ثابتة للأخصائي)
  final Map<String, dynamic> _specialistInstitution = {
    'name': 'مركز جسور للتربية الخاصة',
    'address': 'عمان - الشميساني'
  };

  // اختيار التاريخ
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // اختيار الوقت
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7815A0),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // محاكاة إرسال النموذج
  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedChildId == null) {
      _showSnackbar('Please select a child', isError: true);
      return;
    }

    if (_selectedDate == null) {
      _showSnackbar('Please select a date', isError: true);
      return;
    }

    if (_selectedTime == null) {
      _showSnackbar('Please select a time', isError: true);
      return;
    }

    // محاكاة التحميل
    setState(() => _isLoading = true);

    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isLoading = false);

      // عرض بيانات الجلسة
      _showSessionSummary();
    });
  }

  // عرض ملخص الجلسة
  void _showSessionSummary() {
    final selectedChild = _children.firstWhere((child) => child['id'] == _selectedChildId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Session Created Successfully!',
          style: TextStyle(color: Color(0xFF7815A0)),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryItem('Child', selectedChild['name'] as String),
              _buildSummaryItem('Date', DateFormat('MMM dd, yyyy').format(_selectedDate!)),
              _buildSummaryItem('Time', _selectedTime!.format(context)),
              _buildSummaryItem('Duration', '$_duration minutes'),
              _buildSummaryItem('Type', _sessionType),
              if (_sessionType == 'Onsite')
                _buildSummaryItem('Institution', _specialistInstitution['name'] as String),
              _buildSummaryItem('Price', '$_price JOD'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('Create Another'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
              Navigator.pop(context); // العودة للصفحة السابقة
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7815A0),
            ),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // إعادة تعيين النموذج
  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _selectedChildId = null;
      _selectedDate = null;
      _selectedTime = null;
      _duration = 60;
      _price = 0.0;
      _sessionType = 'Onsite';
    });
  }

  // رسائل المستخدم
  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF7815A0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Session',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF7815A0),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showSnackbar('This is a demo form. No actual data will be saved.');
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF8F5FF),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Information Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Row(
                            children: [
                              Icon(
                                Icons.event_available,
                                color: const Color(0xFF7815A0),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Session Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7815A0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Child Selection
                          _buildChildDropdown(),
                          const SizedBox(height: 16),

                          // Date & Time Row
                          Row(
                            children: [
                              Expanded(child: _buildDateButton()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTimeButton()),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Duration & Price Row
                          Row(
                            children: [
                              Expanded(child: _buildDurationField()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildPriceField()),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Session Type
                          _buildSessionTypeSelector(),
                          const SizedBox(height: 16),

                          // Institution Info (للجلسات الحضورية)
                          if (_sessionType == 'Onsite') _buildInstitutionInfo(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Session Preview Card
                  if (_selectedChildId != null || _selectedDate != null || _selectedTime != null)
                    _buildSessionPreview(),

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _resetForm,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Colors.grey),
                          ),
                          child: const Text(
                            'Reset Form',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF7815A0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 20, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Create Session',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // بناء dropdown الأطفال
  Widget _buildChildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Child *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7815A0),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: _selectedChildId,
          items: _children.map<DropdownMenuItem<int>>((child) {
            return DropdownMenuItem<int>(
              value: child['id'] as int,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    child['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${child['age']} years • ${child['disability']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedChildId = value),
          validator: (value) => value == null ? 'Please select a child' : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7815A0), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          isExpanded: true,
          hint: const Text('Choose a child'),
        ),
      ],
    );
  }

  // بناء معلومات المؤسسة (للجلسات الحضورية)
  Widget _buildInstitutionInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Institution',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7815A0),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF7815A0).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7815A0).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.business, color: const Color(0xFF7815A0), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _specialistInstitution['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _specialistInstitution['address'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'This session will be scheduled at your assigned institution',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  // باقي الدوال تبقى كما هي...
  Widget _buildDateButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session Date *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7815A0),
          ),
        ),
        const SizedBox(height: 6),
        ElevatedButton(
          onPressed: _selectDate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.grey),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedDate == null
                    ? 'Select Date'
                    : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                style: TextStyle(
                  color: _selectedDate == null ? Colors.grey : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(Icons.calendar_today, color: Color(0xFF7815A0), size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session Time *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7815A0),
          ),
        ),
        const SizedBox(height: 6),
        ElevatedButton(
          onPressed: _selectTime,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.grey),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedTime == null ? 'Select Time' : _selectedTime!.format(context),
                style: TextStyle(
                  color: _selectedTime == null ? Colors.grey : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(Icons.access_time, color: Color(0xFF7815A0), size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Duration (minutes) *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7815A0),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _duration.toString(),
          keyboardType: TextInputType.number,
          onChanged: (value) => setState(() => _duration = int.tryParse(value) ?? 60),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Enter duration';
            final val = int.tryParse(value);
            if (val == null || val <= 0) return 'Must be positive';
            return null;
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7815A0), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixText: 'min',
          ),
        ),
      ],
    );
  }

  Widget _buildPriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price (JOD)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7815A0),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _price.toStringAsFixed(2),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) => setState(() => _price = double.tryParse(value) ?? 0.0),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final val = double.tryParse(value);
              if (val == null || val < 0) return 'Cannot be negative';
            }
            return null;
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7815A0), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixText: 'JOD',
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session Type *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7815A0),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSessionTypeCard(
                label: 'Onsite',
                description: 'At ${_specialistInstitution['name']}',
                isSelected: _sessionType == 'Onsite',
                onTap: () => setState(() => _sessionType = 'Onsite'),
                icon: Icons.business,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSessionTypeCard(
                label: 'Online',
                description: 'Virtual session',
                isSelected: _sessionType == 'Online',
                onTap: () => setState(() => _sessionType = 'Online'),
                icon: Icons.video_call,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionTypeCard({
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF7815A0) : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7815A0).withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF7815A0) : Colors.grey,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? const Color(0xFF7815A0) : Colors.grey,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? const Color(0xFF7815A0) : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionPreview() {
    final selectedChild = _children.firstWhere(
          (child) => child['id'] == _selectedChildId,
      orElse: () => {'name': 'No child selected', 'age': '', 'disability': ''},
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.remove_red_eye, size: 18, color: Color(0xFF7815A0)),
                SizedBox(width: 8),
                Text(
                  'Session Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7815A0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPreviewItem('Child', '${selectedChild['name']} (${selectedChild['age']} years)'),
            if (_selectedDate != null)
              _buildPreviewItem('Date', DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate!)),
            if (_selectedTime != null)
              _buildPreviewItem('Time', _selectedTime!.format(context)),
            _buildPreviewItem('Duration', '$_duration minutes'),
            _buildPreviewItem('Type', _sessionType),
            if (_sessionType == 'Onsite')
              _buildPreviewItem('Institution', _specialistInstitution['name'] as String),
            _buildPreviewItem('Price', '$_price NIC'),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}