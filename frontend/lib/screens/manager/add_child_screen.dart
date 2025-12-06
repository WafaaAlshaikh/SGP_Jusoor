import 'package:flutter/material.dart';
import '../../services/manager_children_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';

class AddChildScreen extends StatefulWidget {
  @override
  _AddChildScreenState createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Parent selection
  String _parentSelection = 'existing';
  Map<String, dynamic>? _selectedParent;
  List<Map<String, dynamic>> _parentsList = [];
  bool _loadingParents = false;

  // Parent form
  final GlobalKey<FormState> _parentFormKey = GlobalKey<FormState>();
  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  final TextEditingController _parentAddressController = TextEditingController();
  final TextEditingController _parentOccupationController = TextEditingController();

  // Child form
  final GlobalKey<FormState> _childFormKey = GlobalKey<FormState>();
  final TextEditingController _childNameController = TextEditingController();
  final TextEditingController _childBirthDateController = TextEditingController();
  String? _selectedGender;
  final TextEditingController _childAddressController = TextEditingController();
  final TextEditingController _childCityController = TextEditingController();
  final TextEditingController _childSchoolController = TextEditingController();
  final TextEditingController _childMedicalHistoryController = TextEditingController();
  final TextEditingController _childNotesController = TextEditingController();

  // Session booking
  bool _bookSession = true;
  DateTime? _selectedDate;
  String? _selectedTime;
  Map<String, dynamic>? _selectedSpecialist;
  Map<String, dynamic>? _selectedSlot;
  Map<String, dynamic>? _selectedDay;
  List<Map<String, dynamic>> _availableDays = [];
  Map<String, dynamic>? _closestSlot;
  bool _loadingSpecialists = false;
  final TextEditingController _sessionNotesController = TextEditingController();

  // Overall state
  bool _isSubmitting = false;
  Map<String, dynamic>? _submissionResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadParents();

    // تحميل الأخصائيين المتاحين مع التاريخ الحالي
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableSpecialists();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _parentNameController.dispose();
    _parentEmailController.dispose();
    _parentPhoneController.dispose();
    _parentAddressController.dispose();
    _parentOccupationController.dispose();
    _childNameController.dispose();
    _childBirthDateController.dispose();
    _childAddressController.dispose();
    _childCityController.dispose();
    _childSchoolController.dispose();
    _childMedicalHistoryController.dispose();
    _childNotesController.dispose();
    _sessionNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadParents() async {
    setState(() {
      _loadingParents = true;
    });

    try {
      final response = await ManagerChildrenService.getParentsList();
      if (response['success'] == true) {
        setState(() {
          _parentsList = List<Map<String, dynamic>>.from(response['data']['parents']);
        });
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      setState(() {
        _loadingParents = false;
      });
    }
  }

  Future<void> _loadAvailableSpecialists({DateTime? specificDate}) async {
    print('Loading available specialists...');

    String? dateParam;
    if (specificDate != null) {
      dateParam = DateFormat('yyyy-MM-dd').format(specificDate);
    } else {
      dateParam = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    print('Date parameter: $dateParam');

    setState(() {
      _loadingSpecialists = true;
      _availableDays = [];
      _selectedDay = null;
      _selectedSpecialist = null;
      _selectedSlot = null;
      _closestSlot = null;
    });

    try {
      final response = await ManagerChildrenService.getAvailableSpecialists(date: dateParam);
      print('API Response success: ${response['success']}');

      if (response['success'] == true) {
        final data = response['data'];
        print('- Available days: ${data['total_available_days']}');
        print('- Total slots: ${data['total_available_slots']}');
        print('- Closest slot: ${data['closest_available_slot']}');

        setState(() {
          _availableDays = List<Map<String, dynamic>>.from(
              data['available_days'] ?? []
          );
          _closestSlot = data['closest_available_slot'];

          print('Loaded ${_availableDays.length} days with available slots');

          if (_closestSlot != null && _availableDays.isNotEmpty) {
            _autoSelectClosestSlot();
          }
        });

        if (_availableDays.isEmpty) {
          _showErrorSnackBar('No available slots found in the next 14 days.');
        }
      }
    } catch (e) {
      print('Error loading available specialists: $e');
      _showErrorSnackBar('Error loading available slots: ${e.toString()}');
    } finally {
      setState(() {
        _loadingSpecialists = false;
      });
    }
  }

  void _autoSelectClosestSlot() {
    if (_closestSlot != null && _availableDays.isNotEmpty) {
      // البحث عن اليوم المناسب
      for (var day in _availableDays) {
        if (day['date'] == _closestSlot!['date']) {
          setState(() {
            _selectedDay = day;
            _selectedDate = DateTime.parse(day['date']);

            // البحث عن الأخصائي المناسب
            final specialists = List<Map<String, dynamic>>.from(
                day['specialists'] ?? []
            );

            bool found = false;
            for (var specialist in specialists) {
              final slots = List<Map<String, dynamic>>.from(
                  specialist['available_slots'] ?? []
              );

              // البحث عن الموعد المناسب
              for (var slot in slots) {
                if (slot['start_time'] == _closestSlot!['start_time'] &&
                    slot['end_time'] == _closestSlot!['end_time']) {
                  _selectedSpecialist = specialist;
                  _selectedSlot = slot;
                  _selectedTime = '${slot['display_start_time']} - ${slot['display_end_time']}';
                  found = true;
                  break;
                }
              }

              if (found) break;
            }

            // إذا لم نجد الموعد الدقيق، نأخذ أول موعد متاح
            if (!found && specialists.isNotEmpty) {
              _selectedSpecialist = specialists.first;
              final slots = List<Map<String, dynamic>>.from(
                  _selectedSpecialist!['available_slots'] ?? []
              );
              if (slots.isNotEmpty) {
                _selectedSlot = slots.first;
                _selectedTime = '${slots.first['display_start_time']} - ${slots.first['display_end_time']}';
              }
            }
          });
          break;
        }
      }
    } else if (_availableDays.isNotEmpty) {
      // إذا لم يكن هناك closestSlot، نأخذ أول يوم متاح
      _selectFirstAvailableDay();
    }
  }

  void _selectFirstAvailableDay() {
    if (_availableDays.isNotEmpty) {
      setState(() {
        _selectedDay = _availableDays.first;
        _selectedDate = DateTime.parse(_selectedDay!['date']);

        final specialists = List<Map<String, dynamic>>.from(
            _selectedDay!['specialists'] ?? []
        );

        if (specialists.isNotEmpty) {
          _selectedSpecialist = specialists.first;
          final slots = List<Map<String, dynamic>>.from(
              _selectedSpecialist!['available_slots'] ?? []
          );

          if (slots.isNotEmpty) {
            _selectedSlot = slots.first;
            _selectedTime = '${slots.first['display_start_time']} - ${slots.first['display_end_time']}';
          }
        }
      });
    }
  }

  bool _validateForms() {
    // التحقق من معلومات الأب
    if (_parentSelection == 'existing' && _selectedParent == null) {
      _showErrorSnackBar('Please select a parent');
      _tabController.animateTo(0);
      return false;
    }

    if (_parentSelection == 'new') {
      if (_parentFormKey.currentState == null) {
        _showErrorSnackBar('Please complete parent information');
        _tabController.animateTo(0);
        return false;
      }

      if (!_parentFormKey.currentState!.validate()) {
        _tabController.animateTo(0);
        return false;
      }
    }

    // التحقق من معلومات الطفل الأساسية فقط
    if (_childNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Child name is required');
      _tabController.animateTo(1);
      return false;
    }

    if (_childBirthDateController.text.trim().isEmpty) {
      _showErrorSnackBar('Birth date is required');
      _tabController.animateTo(1);
      return false;
    }

    if (_selectedGender == null) {
      _showErrorSnackBar('Please select child gender');
      _tabController.animateTo(1);
      return false;
    }

    return true;
  }

  Future<void> _submitForm() async {
    if (!_validateForms()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      Map<String, dynamic> parentData;
      if (_parentSelection == 'existing' && _selectedParent != null) {
        parentData = {
          'parent_id': _selectedParent!['parent_id'],
        };
      } else {
        if (!_parentFormKey.currentState!.validate()) {
          setState(() {
            _isSubmitting = false;
            _tabController.animateTo(0);
          });
          return;
        }

        parentData = {
          'full_name': _parentNameController.text.trim(),
          'email': _parentEmailController.text.trim(),
          'phone': _parentPhoneController.text.trim(),
          'address': _parentAddressController.text.trim(),
          'occupation': _parentOccupationController.text.trim(),
        };
      }

      // بناء بيانات الطفل (الحقول الأساسية فقط مطلوبة)
      final childData = {
        'full_name': _childNameController.text.trim(),
        'date_of_birth': _childBirthDateController.text,
        'gender': _selectedGender,
        // الحقول الاختيارية - فقط إذا كانت تحتوي على بيانات
        'address': _childAddressController.text.trim().isNotEmpty
            ? _childAddressController.text.trim()
            : null,
        'city': _childCityController.text.trim().isNotEmpty
            ? _childCityController.text.trim()
            : null,
        'school_info': _childSchoolController.text.trim().isNotEmpty
            ? _childSchoolController.text.trim()
            : null,
        'medical_history': _childMedicalHistoryController.text.trim().isNotEmpty
            ? _childMedicalHistoryController.text.trim()
            : null,
        'additional_notes': _childNotesController.text.trim().isNotEmpty
            ? _childNotesController.text.trim()
            : null,
      };

      Map<String, dynamic>? sessionData;
      if (_bookSession && _selectedDate != null && _selectedSlot != null && _selectedSpecialist != null) {
        sessionData = {
          'book_session': true,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          'start_time': _selectedSlot!['start_time'],
          'specialist_id': _selectedSpecialist!['id'],
          'notes': _sessionNotesController.text.trim().isNotEmpty
              ? _sessionNotesController.text.trim()
              : null,
        };
      }

      final response = await ManagerChildrenService.addNewChild(
        parentData: parentData,
        childData: childData,
        sessionData: sessionData,
      );

      if (response['success'] == true) {
        setState(() {
          _submissionResult = response['data'];
        });

        _showSuccessDialog();
      } else {
        _showErrorSnackBar(response['message'] ?? 'Failed to add child');
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 64,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Child Added Successfully',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            if (_submissionResult != null) ...[
              _buildResultItem('Child Name', _submissionResult!['child']['full_name']),
              _buildResultItem('Child ID', _submissionResult!['child']['child_identifier']),
              if (_submissionResult!['parent']['is_new'] == true)
                _buildResultItem('New Parent', 'Yes - Email sent'),
              if (_submissionResult!['session'] != null)
                _buildResultItem('Session Booked', 'Yes'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'Close',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _resetForm();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Add Another',
              style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _parentSelection = 'existing';
      _selectedParent = null;
      _parentNameController.clear();
      _parentEmailController.clear();
      _parentPhoneController.clear();
      _parentAddressController.clear();
      _parentOccupationController.clear();
      _childNameController.clear();
      _childBirthDateController.clear();
      _selectedGender = null;
      _childAddressController.clear();
      _childCityController.clear();
      _childSchoolController.clear();
      _childMedicalHistoryController.clear();
      _childNotesController.clear();
      _bookSession = true;
      _selectedDate = null;
      _selectedTime = null;
      _selectedSpecialist = null;
      _selectedSlot = null;
      _selectedDay = null;
      _availableDays = [];
      _sessionNotesController.clear();
      _submissionResult = null;
      _tabController.animateTo(0);
    });

    _loadAvailableSpecialists();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedDay = null;
        _selectedSpecialist = null;
        _selectedSlot = null;
        _selectedTime = null;
      });

      try {
        final dateStr = DateFormat('yyyy-MM-dd').format(picked);
        final response = await ManagerChildrenService.getAvailableSpecialists(date: dateStr);

        if (response['success'] == true) {
          final data = response['data'];
          setState(() {
            _availableDays = List<Map<String, dynamic>>.from(
                data['available_days'] ?? []
            );

            if (_availableDays.isNotEmpty) {
              _autoSelectClosestSlot();
            } else {
              _showErrorSnackBar('No available slots for selected date');
            }
          });
        }
      } catch (e) {
        _showErrorSnackBar('Error loading slots for selected date');
      }
    }
  }

  Widget _buildParentSelectionStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parent Information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Select existing parent or add new one',
            style: TextStyle(
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text('Existing Parent'),
                  selected: _parentSelection == 'existing',
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _parentSelection == 'existing'
                        ? AppColors.textWhite
                        : AppColors.textDark,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _parentSelection = 'existing';
                    });
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ChoiceChip(
                  label: Text('New Parent'),
                  selected: _parentSelection == 'new',
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _parentSelection == 'new'
                        ? AppColors.textWhite
                        : AppColors.textDark,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _parentSelection = 'new';
                    });
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 32),

          if (_parentSelection == 'existing') ...[
            Text(
              'Select Parent',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 16),

            if (_loadingParents)
              Center(child: CircularProgressIndicator(color: AppColors.primary))
            else if (_parentsList.isEmpty)
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent2),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.group_off,
                      size: 48,
                      color: AppColors.textLight,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No parents found',
                      style: TextStyle(
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._parentsList.map((parent) {
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        parent['user']['full_name'].substring(0, 1),
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      parent['user']['full_name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parent['user']['email'],
                          style: TextStyle(
                            color: AppColors.textGray,
                          ),
                        ),
                        if (parent['children'].isNotEmpty)
                          Text(
                            '${parent['children'].length} children',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    trailing: Radio<Map<String, dynamic>>(
                      value: parent,
                      groupValue: _selectedParent,
                      onChanged: (value) {
                        setState(() {
                          _selectedParent = value;
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    onTap: () {
                      setState(() {
                        _selectedParent = parent;
                      });
                    },
                    tileColor: _selectedParent?['parent_id'] == parent['parent_id']
                        ? AppColors.accent1
                        : AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _selectedParent?['parent_id'] == parent['parent_id']
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
          ],

          if (_parentSelection == 'new') ...[
            Form(
              key: _parentFormKey,
              child: Column(
                children: [
                  _buildFormField(
                    controller: _parentNameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    controller: _parentEmailController,
                    label: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    controller: _parentPhoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    controller: _parentAddressController,
                    label: 'Address',
                    icon: Icons.location_on,
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    controller: _parentOccupationController,
                    label: 'Occupation',
                    icon: Icons.work,
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 32),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                if (_parentSelection == 'existing' && _selectedParent == null) {
                  _showErrorSnackBar('Please select a parent');
                  return;
                }
                if (_parentSelection == 'new') {
                  if (_parentFormKey.currentState == null) {
                    _showErrorSnackBar('Please complete parent information');
                    return;
                  }
                  if (!_parentFormKey.currentState!.validate()) {
                    return;
                  }
                }
                _tabController.animateTo(1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Next: Child Information',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildInfoStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Child Information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Enter child details (Name, Birth Date, and Gender are required)',
            style: TextStyle(
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 24),

          Form(
            key: _childFormKey,
            child: Column(
              children: [
                // الاسم (مطلوب)
                _buildFormField(
                  controller: _childNameController,
                  label: 'Child Full Name *',
                  icon: Icons.child_care,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Child name is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // تاريخ الميلاد (مطلوب)
                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(DateTime.now().year - 3),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: ColorScheme.light(
                              primary: AppColors.primary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (picked != null) {
                      setState(() {
                        _childBirthDateController.text =
                            DateFormat('yyyy-MM-dd').format(picked);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: _buildFormField(
                      controller: _childBirthDateController,
                      label: 'Date of Birth *',
                      icon: Icons.cake,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Birth date is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // الجنس (مطلوب)
                Text(
                  'Gender *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Male'),
                        selected: _selectedGender == 'Male',
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedGender == 'Male'
                              ? AppColors.textWhite
                              : AppColors.textDark,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedGender = 'Male';
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Female'),
                        selected: _selectedGender == 'Female',
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedGender == 'Female'
                              ? AppColors.textWhite
                              : AppColors.textDark,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedGender = 'Female';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // باقي الحقول (اختيارية)
                _buildFormField(
                  controller: _childAddressController,
                  label: 'Address (Optional)',
                  icon: Icons.home,
                  maxLines: 2,
                  // بدون validator
                ),
                SizedBox(height: 16),

                _buildFormField(
                  controller: _childCityController,
                  label: 'City (Optional)',
                  icon: Icons.location_city,
                  // بدون validator
                ),
                SizedBox(height: 16),

                _buildFormField(
                  controller: _childSchoolController,
                  label: 'School Information (Optional)',
                  icon: Icons.school,
                  maxLines: 2,
                  // بدون validator
                ),
                SizedBox(height: 16),

                _buildFormField(
                  controller: _childMedicalHistoryController,
                  label: 'Medical History (Optional)',
                  icon: Icons.medical_services,
                  maxLines: 3,
                  // بدون validator
                ),
                SizedBox(height: 16),

                _buildFormField(
                  controller: _childNotesController,
                  label: 'Additional Notes (Optional)',
                  icon: Icons.note,
                  maxLines: 3,
                  // بدون validator
                ),
              ],
            ),
          ),

          SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  _tabController.animateTo(0);
                },
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // التحقق من المعلومات الأساسية فقط
                  if (_childNameController.text.trim().isEmpty) {
                    _showErrorSnackBar('Child name is required');
                    return;
                  }
                  if (_childBirthDateController.text.trim().isEmpty) {
                    _showErrorSnackBar('Birth date is required');
                    return;
                  }
                  if (_selectedGender == null) {
                    _showErrorSnackBar('Please select gender');
                    return;
                  }
                  _tabController.animateTo(2);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Next: Session Booking',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionBookingStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Booking',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Book General evaluation session',
            style: TextStyle(
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 24),

          Row(
            children: [
              Switch(
                value: _bookSession,
                onChanged: (value) {
                  setState(() {
                    _bookSession = value;
                    if (value && _availableDays.isEmpty) {
                      _loadAvailableSpecialists();
                    }
                  });
                },
                activeColor: AppColors.primary,
              ),
              SizedBox(width: 12),
              Text(
                'Book General Session',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),

          if (_bookSession) ...[
            SizedBox(height: 24),

            Text(
              'Select Date',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accent2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Search Specific Date',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _selectedDate == null
                                ? 'Tap to select a date'
                                : 'Searching: ${DateFormat('MMM d, yyyy').format(_selectedDate!)}',
                            style: TextStyle(
                              color: _selectedDate == null
                                  ? AppColors.textLight
                                  : AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: AppColors.textGray,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Available Days & Times',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadAvailableSpecialists,
                  icon: Icon(Icons.refresh, color: AppColors.primary),
                  tooltip: 'Refresh available slots',
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Select a day to view available time slots',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),

            if (_loadingSpecialists)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Loading available days and times...',
                        style: TextStyle(
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_availableDays.isEmpty)
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent2),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: AppColors.textLight,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No available slots found',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try selecting a different date or check back later',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _availableDays.map((day) {
                  final isSelected = _selectedDay?['date'] == day['date'];
                  final specialists = List<Map<String, dynamic>>.from(
                      day['specialists'] ?? []
                  );

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: isSelected,
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.accent1,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('d').format(DateTime.parse(day['date'])),
                              style: TextStyle(
                                color: isSelected ? AppColors.textWhite : AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              DateFormat('E').format(DateTime.parse(day['date'])),
                              style: TextStyle(
                                color: isSelected ? AppColors.textWhite : AppColors.textGray,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        DateFormat('EEEE, MMMM d').format(DateTime.parse(day['date'])),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: Text(
                        '${day['available_slots_count']} available time slots',
                        style: TextStyle(
                          color: AppColors.textGray,
                        ),
                      ),
                      trailing: Icon(
                        isSelected ? Icons.expand_less : Icons.expand_more,
                        color: isSelected ? AppColors.primary : AppColors.textLight,
                      ),
                      onExpansionChanged: (expanded) {
                        if (expanded) {
                          setState(() {
                            _selectedDay = day;
                            _selectedDate = DateTime.parse(day['date']);

                            if (specialists.isNotEmpty && _selectedSpecialist == null) {
                              _selectedSpecialist = specialists[0];
                              final slots = List<Map<String, dynamic>>.from(
                                  _selectedSpecialist!['available_slots'] ?? []
                              );
                              if (slots.isNotEmpty && _selectedSlot == null) {
                                _selectedSlot = slots[0];
                                _selectedTime = '${slots[0]['display_start_time']} - ${slots[0]['display_end_time']}';
                              }
                            }
                          });
                        }
                      },
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.accent1.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(day['date'])),
                                      style: TextStyle(color: AppColors.textDark),
                                    ),
                                    SizedBox(width: 16),
                                    Icon(Icons.access_time, size: 16, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text(
                                      '${day['available_slots_count']} slots available',
                                      style: TextStyle(color: AppColors.textDark),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),

                              Text(
                                'Available Specialists:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 12),

                              ...specialists.map((specialist) {
                                final isSpecSelected = _selectedSpecialist?['id'] == specialist['id'];
                                final slots = List<Map<String, dynamic>>.from(
                                    specialist['available_slots'] ?? []
                                );

                                return Card(
                                  margin: EdgeInsets.only(bottom: 12),
                                  color: isSpecSelected ? AppColors.accent1 : AppColors.card,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isSpecSelected ? AppColors.primary : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: ExpansionTile(
                                    initiallyExpanded: isSpecSelected,
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primaryLight,
                                      child: specialist['profile_picture'] != null
                                          ? ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.network(
                                          specialist['profile_picture'],
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                          : Text(
                                        specialist['name'].substring(0, 1),
                                        style: TextStyle(
                                          color: AppColors.textWhite,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      specialist['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${specialist['specialization']} • ${slots.length} slots',
                                      style: TextStyle(
                                        color: AppColors.textGray,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: Icon(
                                      isSpecSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isSpecSelected ? AppColors.primary : AppColors.textLight,
                                    ),
                                    onExpansionChanged: (expanded) {
                                      if (expanded) {
                                        setState(() {
                                          _selectedSpecialist = specialist;
                                        });
                                      }
                                    },
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.work, size: 14, color: AppColors.primary),
                                                SizedBox(width: 8),
                                                Text(
                                                  specialist['specialization'] ?? 'General',
                                                  style: TextStyle(
                                                    color: AppColors.textDark,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                SizedBox(width: 16),
                                                Icon(Icons.star, size: 14, color: AppColors.primary),
                                                SizedBox(width: 8),
                                                Text(
                                                  '${specialist['years_experience'] ?? 0} yrs exp',
                                                  style: TextStyle(
                                                    color: AppColors.textDark,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),

                                            Text(
                                              'Available Time Slots:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textDark,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: 8),

                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: slots.map((slot) {
                                                final isSlotSelected = _selectedSlot?['start_time'] ==
                                                    slot['start_time'] &&
                                                    _selectedSpecialist?['id'] == specialist['id'];

                                                return GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedSlot = slot;
                                                      _selectedSpecialist = specialist;
                                                      _selectedTime = '${slot['display_start_time']} - ${slot['display_end_time']}';
                                                      _selectedDate = DateTime.parse(day['date']);
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: isSlotSelected
                                                          ? AppColors.primary
                                                          : AppColors.card,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: isSlotSelected
                                                            ? AppColors.primary
                                                            : AppColors.accent2,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          slot['display_start_time'],
                                                          style: TextStyle(
                                                            color: isSlotSelected
                                                                ? AppColors.textWhite
                                                                : AppColors.textDark,
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          'to',
                                                          style: TextStyle(
                                                            color: isSlotSelected
                                                                ? AppColors.textWhite.withOpacity(0.8)
                                                                : AppColors.textGray,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                        Text(
                                                          slot['display_end_time'],
                                                          style: TextStyle(
                                                            color: isSlotSelected
                                                                ? AppColors.textWhite
                                                                : AppColors.textDark,
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),

                                            if (_selectedSpecialist?['id'] == specialist['id'] && _selectedSlot != null)
                                              Container(
                                                margin: EdgeInsets.only(top: 16),
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: AppColors.success.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: AppColors.success.withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.check_circle, color: AppColors.success, size: 20),
                                                    SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Selected Appointment',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.success,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          SizedBox(height: 2),
                                                          Text(
                                                            '${DateFormat('EEEE, MMMM d').format(DateTime.parse(day['date']))} • ${_selectedSlot!['display_start_time']} - ${_selectedSlot!['display_end_time']}',
                                                            style: TextStyle(
                                                              color: AppColors.textDark,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          SizedBox(height: 2),
                                                          Text(
                                                            'With ${specialist['name']}',
                                                            style: TextStyle(
                                                              color: AppColors.textGray,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            SizedBox(height: 24),

            _buildFormField(
              controller: _sessionNotesController,
              label: 'Session Notes (Optional)',
              icon: Icons.note_add,
              maxLines: 3,
            ),

            if (_selectedDay != null && _selectedSpecialist != null && _selectedSlot != null)
              Container(
                margin: EdgeInsets.only(top: 24),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_available, color: AppColors.primary),
                        SizedBox(width: 12),
                        Text(
                          'Automatically Selected Session',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildSummaryItem('Date', DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!)),
                    _buildSummaryItem('Time', _selectedTime ?? 'Not selected'),
                    _buildSummaryItem('Specialist', _selectedSpecialist!['name']),
                    _buildSummaryItem('Specialization', _selectedSpecialist!['specialization'] ?? 'General'),
                    SizedBox(height: 8),
                    Text(
                      'Note: This is the earliest available slot. You can change it below.',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],

          SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  _tabController.animateTo(1);
                },
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.textWhite,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  'Add Child',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textGray,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isRequired = false, // إضافة معلمة جديدة
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label, // إضافة نجمة للحقول المطلوبة
        labelStyle: TextStyle(color: AppColors.textGray),
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        fillColor: AppColors.card,
        filled: true,
      ),
      style: TextStyle(color: AppColors.textDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textWhite),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            'Add New Child',
            style: TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.yal,
            labelColor: AppColors.yal,
            unselectedLabelColor: AppColors.textWhite.withOpacity(0.7),
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: Icon(Icons.person),
                text: 'Parent',
              ),
              Tab(
                icon: Icon(Icons.child_care),
                text: 'Child',
              ),
              Tab(
                icon: Icon(Icons.calendar_today),
                text: 'Session',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildParentSelectionStep(),
            _buildChildInfoStep(),
            _buildSessionBookingStep(),
          ],
        ),
      ),
    );
  }
}