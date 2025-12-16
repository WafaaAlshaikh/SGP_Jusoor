import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ParentWorkshopsScreen extends StatefulWidget {
  const ParentWorkshopsScreen({Key? key}) : super(key: key);

  @override
  State<ParentWorkshopsScreen> createState() => _ParentWorkshopsScreenState();
}

class _ParentWorkshopsScreenState extends State<ParentWorkshopsScreen> {
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
      final result = await ApiService.getParentWorkshops(token);

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _register(int workshopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final result = await ApiService.registerForWorkshop(
        token,
        workshopId: workshopId,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Registered successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadWorkshops();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to register'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Workshops'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workshops.isEmpty
              ? const Center(child: Text('No workshops available for this institution'))
              : RefreshIndicator(
                  onRefresh: _loadWorkshops,
                  child: ListView.builder(
                    itemCount: _workshops.length,
                    itemBuilder: (context, index) {
                      final w = _workshops[index];
                      final mode = w['mode']?.toString() ?? 'offline';
                      final title = w['title']?.toString() ?? '';
                      final desc = w['description']?.toString() ?? '';
                      final date = w['date']?.toString() ?? '';
                      final start = w['start_time']?.toString() ?? '';
                      final end = w['end_time']?.toString() ?? '';
                      final status = w['status']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text('Date: $date  |  $start - $end'),
                              const SizedBox(height: 2),
                              Text('Mode: ${mode == 'online' ? 'Online' : 'In-person'}'),
                              const SizedBox(height: 2),
                              Text('Status: $status'),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final id = w['workshop_id'];
                                    if (id is int) {
                                      _register(id);
                                    } else if (id is String) {
                                      _register(int.tryParse(id) ?? 0);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Invalid workshop id'),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.event_available),
                                  label: const Text('Register'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
