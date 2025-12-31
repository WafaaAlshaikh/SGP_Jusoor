import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/equipment_management_service.dart';

class ParentEquipmentAllocationsScreen extends StatefulWidget {
  final int? childId;

  const ParentEquipmentAllocationsScreen({super.key, this.childId});

  @override
  State<ParentEquipmentAllocationsScreen> createState() => _ParentEquipmentAllocationsScreenState();
}

class _ParentEquipmentAllocationsScreenState extends State<ParentEquipmentAllocationsScreen> {
  bool _isLoading = true;
  bool _isLoadingChildren = true;
  bool _isConfirming = false;

  String _errorMessage = '';
  List<dynamic> _children = [];
  int? _selectedChildId;

  List<dynamic> _allocations = [];

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.childId;
    _loadChildren();
    _loadAllocations();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoadingChildren = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        setState(() => _isLoadingChildren = false);
        return;
      }

      final resp = await ApiService.getChildren(token: token);
      final list = resp['data'] ?? [];

      final normalized = <Map<String, dynamic>>[];
      for (final c in list) {
        if (c is Map<String, dynamic>) {
          final rawId = c['child_id'] ?? c['id'];
          final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
          if (id == null) continue;

          normalized.add({
            ...c,
            'child_id': id,
            'name': c['name'] ?? c['full_name'] ?? 'Child',
          });
        }
      }

      if (mounted) {
        setState(() {
          _children = normalized;
          _isLoadingChildren = false;

          // If selected child is no longer in the list, reset to All
          if (_selectedChildId != null) {
            final exists = normalized.any((c) => c['child_id'] == _selectedChildId);
            if (!exists) _selectedChildId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingChildren = false;
        });
      }
    }
  }

  Future<void> _loadAllocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await EquipmentManagementService.getParentAllocations(childId: _selectedChildId);
      if (mounted) {
        setState(() {
          _allocations = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmReceipt(int allocationId) async {
    if (_isConfirming) return;

    setState(() => _isConfirming = true);
    try {
      await EquipmentManagementService.parentConfirmReceipt(allocationId: allocationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Receipt confirmed'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _loadAllocations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_receipt':
        return AppColors.warning;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textGray;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_receipt':
        return 'Pending receipt';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
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
        title: const Text(
          'Allocated Equipment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllocations,
          )
        ],
      ),
      body: Column(
        children: [
          if (widget.childId == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedChildId,
                          isExpanded: true,
                          hint: const Text('All children'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All children'),
                            ),
                            ..._children.map((c) {
                              final id = c['child_id'] ?? c['id'];
                              final name = c['name'] ?? c['full_name'] ?? 'Child';
                              return DropdownMenuItem<int?>(
                                value: id is int ? id : int.tryParse(id.toString()),
                                child: Text(name.toString()),
                              );
                            }).toList(),
                          ],
                          onChanged: _isLoadingChildren
                              ? null
                              : (val) {
                                  setState(() => _selectedChildId = val);
                                  _loadAllocations();
                                },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _allocations.isEmpty
                        ? Center(
                            child: Text(
                              'No allocated equipment found',
                              style: TextStyle(color: AppColors.textGray),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _allocations.length,
                            itemBuilder: (context, index) {
                              final a = _allocations[index] as Map<String, dynamic>;
                              final allocId = a['allocation_id'];
                              final status = (a['status'] ?? '').toString();
                              final child = a['child'] as Map<String, dynamic>?;
                              final inventory = a['inventoryItem'] as Map<String, dynamic>?;

                              final childName = (child?['name'] ?? '').toString();
                              final itemName = (inventory?['equipment_name'] ?? '').toString();
                              final condition = (inventory?['condition'] ?? '').toString();

                              final canConfirm = status == 'pending_receipt';

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
                                            itemName.isNotEmpty ? itemName : 'Equipment',
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
                                        if (childName.isNotEmpty) _pill('Child: $childName'),
                                        if (condition.isNotEmpty) _pill('Condition: $condition'),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: Container()),
                                        if (canConfirm)
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: (allocId == null || _isConfirming)
                                                ? null
                                                : () => _confirmReceipt(
                                                      allocId is int ? allocId : int.parse(allocId.toString()),
                                                    ),
                                            child: Text(_isConfirming ? 'Confirming...' : 'Confirm receipt'),
                                          ),
                                      ],
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
          )
        ],
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
