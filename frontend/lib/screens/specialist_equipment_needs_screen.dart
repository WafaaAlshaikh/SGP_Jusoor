import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/equipment_management_service.dart';

class SpecialistEquipmentNeedsScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const SpecialistEquipmentNeedsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<SpecialistEquipmentNeedsScreen> createState() => _SpecialistEquipmentNeedsScreenState();
}

class _SpecialistEquipmentNeedsScreenState extends State<SpecialistEquipmentNeedsScreen> {
  bool _loading = true;
  List<dynamic> _needs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await EquipmentManagementService.getNeedsForChild(childId: widget.childId);
      if (mounted) {
        setState(() {
          _needs = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load needs: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'allocated':
        return Colors.blue;
      case 'delivered':
        return AppColors.success;
      case 'matched':
        return AppColors.warning;
      case 'open':
        return AppColors.primary;
      default:
        return AppColors.textGray;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'allocated':
        return 'Allocated';
      case 'delivered':
        return 'Delivered';
      case 'matched':
        return 'Matched (Pending Manager)';
      case 'open':
        return 'Open';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Equipment Needs - ${widget.childName}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _needs.isEmpty
              ? Center(
                  child: Text(
                    'No equipment needs yet',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _needs.length,
                  itemBuilder: (context, index) {
                    final n = _needs[index] as Map<String, dynamic>;
                    final name = (n['equipment_name'] ?? '').toString();
                    final type = (n['equipment_type'] ?? '').toString();
                    final severity = (n['severity'] ?? 'medium').toString();
                    final status = (n['status'] ?? 'open').toString();
                    final score = n['priority_score'];
                    final reason = (n['reason'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _statusColor(status).withOpacity(0.25)),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (type.isNotEmpty)
                                _pill('Type: $type'),
                              _pill('Severity: $severity'),
                              if (score != null)
                                _pill('Priority: $score'),
                              _pill('Source: ${(n['source'] ?? '').toString()}'),
                            ],
                          ),
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              reason,
                              style: TextStyle(color: AppColors.textGray, fontSize: 13),
                            )
                          ]
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(color: AppColors.textDark, fontSize: 12),
      ),
    );
  }
}
