// screens/reminder_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/models/reminder.dart';
import 'package:frontend/services/reminder_service.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class ReminderSelectionScreen extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final DateTime sessionDateTime;

  const ReminderSelectionScreen({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    required this.sessionDateTime,
  });

  @override
  State<ReminderSelectionScreen> createState() => _ReminderSelectionScreenState();
}

class _ReminderSelectionScreenState extends State<ReminderSelectionScreen> {
  final List<ReminderOption> _reminderOptions = [
    ReminderOption('5 minutes before', Duration(minutes: 5)),
    ReminderOption('15 minutes before', Duration(minutes: 15)),
    ReminderOption('30 minutes before', Duration(minutes: 30)),
    ReminderOption('1 hour before', Duration(hours: 1)),
    ReminderOption('2 hours before', Duration(hours: 2)),
    ReminderOption('1 day before', Duration(days: 1)),
    ReminderOption('Custom time', null), // Custom option
  ];

  ReminderOption? _selectedOption;
  TimeOfDay? _customTime;
  DateTime? _customDateTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Reminder'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Info Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sessionTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEE, MMM d, y').format(widget.sessionDateTime),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('h:mm a').format(widget.sessionDateTime),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Reminder Options
            Text(
              'When would you like to be reminded?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: _reminderOptions.length,
                itemBuilder: (context, index) {
                  final option = _reminderOptions[index];
                  return _buildReminderOption(option, index);
                },
              ),
            ),

            // Custom Time Picker (shown only when custom is selected)
            if (_selectedOption?.title == 'Custom time' && _customDateTime != null)
              Column(
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Custom reminder time:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, h:mm a').format(_customDateTime!),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            // Set Reminder Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedOption != null ? _setReminder : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Set Reminder',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderOption(ReminderOption option, int index) {
    final isSelected = _selectedOption == option;
    DateTime? reminderTime;

    if (option.duration != null) {
      reminderTime = widget.sessionDateTime.subtract(option.duration!);
    } else if (_customDateTime != null) {
      reminderTime = _customDateTime;
    }

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: isSelected ? 1.5 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectOption(option, index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppColors.primary : Colors.grey[800],
                      ),
                    ),
                    if (reminderTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('MMM d, h:mm a').format(reminderTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? AppColors.primary : Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (option.title == 'Custom time')
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: AppColors.primary),
                  onPressed: () => _pickCustomTime(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectOption(ReminderOption option, int index) async {
    if (option.title == 'Custom time') {
      await _pickCustomTime();
      if (_customDateTime != null) {
        setState(() {
          _selectedOption = option;
        });
      }
    } else {
      setState(() {
        _selectedOption = option;
        _customDateTime = null;
      });
    }
  }

  Future<void> _pickCustomTime() async {
    // First pick a date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.sessionDateTime,
      firstDate: DateTime.now(),
      lastDate: widget.sessionDateTime,
    );

    if (pickedDate != null) {
      // Then pick a time
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(widget.sessionDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _customDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          // Ensure custom time is before session time
          if (_customDateTime!.isAfter(widget.sessionDateTime)) {
            _customDateTime = widget.sessionDateTime.subtract(Duration(minutes: 30));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Reminder time adjusted to be before session'),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _setReminder() async {
    try {
      DateTime reminderTime;

      if (_selectedOption?.title == 'Custom time' && _customDateTime != null) {
        reminderTime = _customDateTime!;
      } else if (_selectedOption?.duration != null) {
        reminderTime = widget.sessionDateTime.subtract(_selectedOption!.duration!);
      } else {
        return;
      }

      // Save reminder to database
      final reminder = SessionReminder(
        sessionId: widget.sessionId,
        sessionTitle: widget.sessionTitle,
        sessionDateTime: widget.sessionDateTime,
        reminderTime: reminderTime,
      );

      await ReminderService().scheduleReminder(reminder);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder set for ${DateFormat('MMM d, h:mm a').format(reminderTime)}'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context, true);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to set reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class ReminderOption {
  final String title;
  final Duration? duration;

  ReminderOption(this.title, this.duration);
}