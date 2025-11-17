import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/specialist_api.dart';
import '../theme/app_colors.dart';

class AddSessionScreen extends StatefulWidget {
  const AddSessionScreen({Key? key}) : super(key: key);

  @override
  State<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  // Data
  List<dynamic> eligibleChildren = [];
  List<dynamic> sessionTypes = [];
  bool isLoadingChildren = true;
  bool isLoadingSessionTypes = true;
  String? errorMessage;

  // Selected values
  Set<int> selectedChildIds = {};
  int? selectedSessionTypeId;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String sessionType = 'Onsite'; // Online or Onsite
  TextEditingController notesController = TextEditingController();

  // Filter
  String? selectedCondition;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadEligibleChildren(),
      _loadSessionTypes(),
    ]);
  }

  Future<void> _loadEligibleChildren() async {
    setState(() {
      isLoadingChildren = true;
      errorMessage = null;
    });

    try {
      final response = await SpecialistService.getEligibleChildren();
      if (response['success'] == true) {
        setState(() {
          eligibleChildren = response['data'] ?? [];
          isLoadingChildren = false;
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load children';
          isLoadingChildren = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading children: ${e.toString()}';
        isLoadingChildren = false;
      });
    }
  }

  Future<void> _loadSessionTypes() async {
    setState(() {
      isLoadingSessionTypes = true;
    });

    try {
      final response = await SpecialistService.getAvailableSessionTypes(
        condition: selectedCondition,
      );
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
      setState(() {
        isLoadingSessionTypes = false;
      });
    }
  }

  Future<void> _submitSession() async {
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
    final timeStr = '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00';

    try {
      // Show loading dialog
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
        time: timeStr,
        sessionType: sessionType,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (response['success'] == true) {
        _showSuccess('Sessions created successfully. Approval requests sent to parents');
        // Reset form
        setState(() {
          selectedChildIds.clear();
          selectedSessionTypeId = null;
          selectedDate = null;
          selectedTime = null;
          notesController.clear();
        });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
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
              // Error message
              if (errorMessage != null)
                Container(
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
                ),

              // Children Selection Section
              _buildSectionTitle('Select Children'),
              if (isLoadingChildren)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (eligibleChildren.isEmpty)
                _buildEmptyState('No eligible children found')
              else
                _buildChildrenList(),

              const SizedBox(height: 24),

              // Session Type Selection
              _buildSectionTitle('Select Session Type'),
              if (isLoadingSessionTypes)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
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
              SizedBox(
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
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
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
          return CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  selectedChildIds.add(childId);
                } else {
                  selectedChildIds.remove(childId);
                }
              });
            },
            title: Text(
              child['full_name'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Condition: ${child['condition'] ?? 'Not specified'}',
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
          // Date picker
          ListTile(
            leading: const Icon(Icons.calendar_today, color: AppColors.primary),
            title: const Text('Date'),
            subtitle: Text(
              selectedDate != null
                  ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                  : 'Select date',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  selectedDate = date;
                });
              }
            },
          ),
          const Divider(),
          // Time picker
          ListTile(
            leading: const Icon(Icons.access_time, color: AppColors.primary),
            title: const Text('Time'),
            subtitle: Text(
              selectedTime != null
                  ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                  : 'Select time',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null) {
                setState(() {
                  selectedTime = time;
                });
              }
            },
          ),
        ],
      ),
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
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
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

