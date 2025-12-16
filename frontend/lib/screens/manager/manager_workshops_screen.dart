import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class ManagerWorkshopsScreen extends StatefulWidget {
  const ManagerWorkshopsScreen({Key? key}) : super(key: key);

  @override
  State<ManagerWorkshopsScreen> createState() => _ManagerWorkshopsScreenState();
}

class _ManagerWorkshopsScreenState extends State<ManagerWorkshopsScreen> {
  bool _isLoading = true;
  List<dynamic> _workshops = [];

  @override
  void initState() {
    super.initState();
    _loadWorkshops();
  }

  Future<void> _loadWorkshops() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final result = await ApiService.getManagerWorkshops(token);

      if (result['success'] == true) {
        setState(() {
          _workshops = result['data'] ?? [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load workshops'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateWorkshopDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final linkController = TextEditingController();
    String mode = 'offline';
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    int maxParticipants = 20;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Create Parent Workshop'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: mode,
                      items: const [
                        DropdownMenuItem(value: 'offline', child: Text('In-person (Offline)')),
                        DropdownMenuItem(value: 'online', child: Text('Online')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setInnerState(() {
                          mode = val;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Mode'),
                    ),
                    const SizedBox(height: 8),
                    if (mode == 'offline')
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Location address'),
                      ),
                    if (mode == 'online')
                      TextField(
                        controller: linkController,
                        decoration: const InputDecoration(labelText: 'Online link'),
                      ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(selectedDate == null
                          ? 'Select date'
                          : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 1),
                        );
                        if (picked != null) {
                          setInnerState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(startTime == null
                          ? 'Select start time'
                          : startTime!.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (picked != null) {
                          setInnerState(() {
                            startTime = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(endTime == null
                          ? 'Select end time'
                          : endTime!.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 12, minute: 0),
                        );
                        if (picked != null) {
                          setInnerState(() {
                            endTime = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Max participants:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            min: 5,
                            max: 50,
                            divisions: 9,
                            label: maxParticipants.toString(),
                            value: maxParticipants.toDouble(),
                            onChanged: (v) {
                              setInnerState(() {
                                maxParticipants = v.toInt();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        selectedDate == null ||
                        startTime == null ||
                        endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all required fields'),
                        ),
                      );
                      return;
                    }

                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('token') ?? '';

                    final dateStr = '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                    final startStr = '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                    final endStr = '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';

                    final result = await ApiService.createManagerWorkshop(
                      token,
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      mode: mode,
                      onlineLink: mode == 'online' && linkController.text.trim().isNotEmpty
                          ? linkController.text.trim()
                          : null,
                      locationAddress: mode == 'offline' && locationController.text.trim().isNotEmpty
                          ? locationController.text.trim()
                          : null,
                      date: dateStr,
                      startTime: startStr,
                      endTime: endStr,
                      maxParticipants: maxParticipants,
                      status: 'published',
                    );

                    if (result['success'] == true) {
                      Navigator.pop(context);
                      await _loadWorkshops();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? 'Workshop created'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? 'Failed to create workshop'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Workshops'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateWorkshopDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workshops.isEmpty
              ? const Center(child: Text('No workshops yet'))
              : ListView.builder(
                  itemCount: _workshops.length,
                  itemBuilder: (context, index) {
                    final w = _workshops[index];
                    final mode = w['mode']?.toString() ?? 'offline';
                    final status = w['status']?.toString() ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ListTile(
                        title: Text(w['title'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (w['description'] != null &&
                                (w['description'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  w['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text('Date: ${w['date'] ?? ''} | ${w['start_time'] ?? ''} - ${w['end_time'] ?? ''}'),
                            const SizedBox(height: 2),
                            Text('Mode: ${mode == 'online' ? 'Online' : 'In-person'}'),
                            const SizedBox(height: 2),
                            Text('Max participants: ${w['max_participants'] ?? 0}'),
                            const SizedBox(height: 4),
                            Text('Status: ${status}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
