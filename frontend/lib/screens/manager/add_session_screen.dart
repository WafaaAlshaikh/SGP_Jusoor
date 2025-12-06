import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AddSessionScreen extends StatefulWidget {
  @override
  _AddSessionScreenState createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  TextEditingController _childController = TextEditingController();
  TextEditingController _specialistController = TextEditingController();
  TextEditingController _dateController = TextEditingController();
  TextEditingController _timeController = TextEditingController();
  TextEditingController _notesController = TextEditingController();

  // Form Values
  String _selectedSessionType = '';
  String _selectedDuration = '60';
  String _selectedPaymentStatus = 'Pending';
  bool _isRecurring = false;
  String _recurrenceType = 'Weekly';
  int _recurrenceCount = 1;

  // Available Options
  List<String> _sessionTypes = [
    'Speech Therapy',
    'Behavioral Therapy',
    'Occupational Therapy',
    'Educational Therapy',
    'Play Therapy',
    'Music Therapy',
    'Art Therapy',
    'Social Skills Group',
  ];

  List<String> _durations = ['30', '45', '60', '90', '120'];
  List<String> _paymentStatuses = ['Pending', 'Paid', 'Insurance', 'Sponsored'];
  List<String> _recurrenceTypes = ['Daily', 'Weekly', 'Bi-weekly', 'Monthly'];

  // Sample Data
  List<Map<String, dynamic>> _availableChildren = [
    {'id': 'C001', 'name': 'Ahmed Ali', 'age': 8, 'diagnosis': 'ASD'},
    {'id': 'C002', 'name': 'Fatima Mohammed', 'age': 6, 'diagnosis': 'Speech Delay'},
    {'id': 'C003', 'name': 'Omar Khalid', 'age': 10, 'diagnosis': 'ADHD'},
    {'id': 'C004', 'name': 'Layla Hassan', 'age': 7, 'diagnosis': 'Down Syndrome'},
    {'id': 'C005', 'name': 'Mohammed Salem', 'age': 5, 'diagnosis': 'Suspected ASD'},
  ];

  List<Map<String, dynamic>> _availableSpecialists = [
    {'id': 'SP001', 'name': 'Dr. Sarah Ahmed', 'specialty': 'Speech Therapy'},
    {'id': 'SP002', 'name': 'Dr. Michael Chen', 'specialty': 'Behavioral Therapy'},
    {'id': 'SP003', 'name': 'Dr. Lisa Johnson', 'specialty': 'Occupational Therapy'},
    {'id': 'SP004', 'name': 'Dr. James Wilson', 'specialty': 'Educational Therapy'},
    {'id': 'SP005', 'name': 'Dr. Fatima Al-Masri', 'specialty': 'Play Therapy'},
  ];

  @override
  void initState() {
    super.initState();
    // Set default date to tomorrow
    DateTime tomorrow = DateTime.now().add(Duration(days: 1));
    _dateController.text = "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";
    _timeController.text = "09:00";
  }

  void _showChildSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Select Child',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search children...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _availableChildren.length,
                itemBuilder: (context, index) {
                  final child = _availableChildren[index];
                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            child['name'].split(' ').map((n) => n[0]).take(2).join(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      title: Text(child['name']),
                      subtitle: Text('Age: ${child['age']} • ${child['diagnosis']}'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        _childController.text = child['name'];
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpecialistSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Select Specialist',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search specialists...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _availableSpecialists.length,
                itemBuilder: (context, index) {
                  final specialist = _availableSpecialists[index];
                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(specialist['name']),
                      subtitle: Text(specialist['specialty']),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        _specialistController.text = specialist['name'];
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026, 12, 31),
    );

    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _timeController.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  double _calculatePrice() {
    double basePrice = 0;

    switch (_selectedSessionType) {
      case 'Speech Therapy': basePrice = 120; break;
      case 'Behavioral Therapy': basePrice = 150; break;
      case 'Occupational Therapy': basePrice = 110; break;
      case 'Educational Therapy': basePrice = 100; break;
      case 'Play Therapy': basePrice = 90; break;
      case 'Music Therapy': basePrice = 95; break;
      case 'Art Therapy': basePrice = 90; break;
      case 'Social Skills Group': basePrice = 180; break;
      default: basePrice = 100;
    }

    int duration = int.tryParse(_selectedDuration) ?? 60;
    return basePrice * (duration / 60);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm Session Booking'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildConfirmationRow('Child', _childController.text),
                _buildConfirmationRow('Specialist', _specialistController.text),
                _buildConfirmationRow('Session Type', _selectedSessionType),
                _buildConfirmationRow('Date', _dateController.text),
                _buildConfirmationRow('Time', _timeController.text),
                _buildConfirmationRow('Duration', '${_selectedDuration} minutes'),
                _buildConfirmationRow('Estimated Price', '\$${_calculatePrice().toStringAsFixed(2)}'),
                _buildConfirmationRow('Payment Status', _selectedPaymentStatus),
                if (_isRecurring) ...[
                  _buildConfirmationRow('Recurrence', '$_recurrenceType for $_recurrenceCount times'),
                ],
                if (_notesController.text.isNotEmpty)
                  _buildConfirmationRow('Notes', _notesController.text),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close confirmation
                Navigator.pop(context); // Close form

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Session booked successfully!'),
                    backgroundColor: AppColors.ment,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: Text('Confirm Booking'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        SizedBox(height: 8),
        child,
        SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Session'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child Selection
              _buildFormField(
                label: 'Child',
                required: true,
                child: TextFormField(
                  controller: _childController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Select child',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.arrow_drop_down),
                      onPressed: _showChildSelection,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a child';
                    }
                    return null;
                  },
                ),
              ),

              // Specialist Selection
              _buildFormField(
                label: 'Specialist',
                required: true,
                child: TextFormField(
                  controller: _specialistController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Select specialist',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.arrow_drop_down),
                      onPressed: _showSpecialistSelection,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a specialist';
                    }
                    return null;
                  },
                ),
              ),

              // Session Type
              _buildFormField(
                label: 'Session Type',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: _selectedSessionType.isNotEmpty ? _selectedSessionType : null,
                  decoration: InputDecoration(
                    hintText: 'Select session type',
                    border: OutlineInputBorder(),
                  ),
                  items: _sessionTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSessionType = value ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a session type';
                    }
                    return null;
                  },
                ),
              ),

              // Date and Time
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      label: 'Date',
                      required: true,
                      child: TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Select date',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.calendar_today),
                            onPressed: _selectDate,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a date';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(
                      label: 'Time',
                      required: true,
                      child: TextFormField(
                        controller: _timeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Select time',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.access_time),
                            onPressed: _selectTime,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a time';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // Duration
              _buildFormField(
                label: 'Duration',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: _selectedDuration,
                  decoration: InputDecoration(
                    hintText: 'Select duration',
                    border: OutlineInputBorder(),
                  ),
                  items: _durations.map((duration) {
                    return DropdownMenuItem(
                      value: duration,
                      child: Text('$duration minutes'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDuration = value ?? '60';
                    });
                  },
                ),
              ),

              // Price Display
              if (_selectedSessionType.isNotEmpty)
                _buildFormField(
                  label: 'Estimated Price',
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent1,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Price:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '\$${_calculatePrice().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Payment Status
              _buildFormField(
                label: 'Payment Status',
                child: DropdownButtonFormField<String>(
                  value: _selectedPaymentStatus,
                  decoration: InputDecoration(
                    hintText: 'Select payment status',
                    border: OutlineInputBorder(),
                  ),
                  items: _paymentStatuses.map((status) {
                    Color statusColor = status == 'Paid' ? Colors.green :
                    status == 'Pending' ? Colors.orange :
                    status == 'Insurance' ? Colors.blue :
                    Colors.purple;

                    return DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(status),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentStatus = value ?? 'Pending';
                    });
                  },
                ),
              ),

              // Recurring Session
              _buildFormField(
                label: 'Recurring Session',
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Schedule as recurring session'),
                      value: _isRecurring,
                      onChanged: (value) {
                        setState(() {
                          _isRecurring = value;
                        });
                      },
                    ),

                    if (_isRecurring) ...[
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _recurrenceType,
                              decoration: InputDecoration(
                                labelText: 'Repeat every',
                                border: OutlineInputBorder(),
                              ),
                              items: _recurrenceTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _recurrenceType = value ?? 'Weekly';
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              initialValue: _recurrenceCount.toString(),
                              decoration: InputDecoration(
                                labelText: 'Number of times',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _recurrenceCount = int.tryParse(value) ?? 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Notes
              _buildFormField(
                label: 'Notes',
                child: TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    hintText: 'Additional notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),

              // Submit Button
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(Icons.add_circle),
                label: Text(
                  'Add Session',
                  style: TextStyle(fontSize: 16),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}