import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/equipment_management_service.dart';

class ManagerEquipmentCampaignsScreen extends StatefulWidget {
  const ManagerEquipmentCampaignsScreen({super.key});

  @override
  State<ManagerEquipmentCampaignsScreen> createState() => _ManagerEquipmentCampaignsScreenState();
}

class _ManagerEquipmentCampaignsScreenState extends State<ManagerEquipmentCampaignsScreen> {
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _campaigns = [];
  String _statusFilter = 'open';

  int _page = 1;
  int _pages = 1;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await EquipmentManagementService.getManagerEquipmentCampaigns(
        status: _statusFilter.isEmpty ? null : _statusFilter,
        page: _page,
        limit: 20,
      );

      final campaignsRaw = result['campaigns'];
      final pagination = result['pagination'] as Map<String, dynamic>?;

      final campaigns = (campaignsRaw is List)
          ? campaignsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _campaigns = campaigns;
        _pages = (pagination?['pages'] ?? 1) is int ? (pagination?['pages'] ?? 1) as int : 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openUpdateDialog(Map<String, dynamic> campaign) async {
    final campaignId = campaign['campaign_id'];
    if (campaignId is! int) return;

    String status = (campaign['status'] ?? 'open').toString();
    final qtyController = TextEditingController(text: (campaign['quantity_fulfilled'] ?? 0).toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Equipment Campaign'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('open')),
                  DropdownMenuItem(value: 'partially_fulfilled', child: Text('partially_fulfilled')),
                  DropdownMenuItem(value: 'fulfilled', child: Text('fulfilled')),
                  DropdownMenuItem(value: 'closed', child: Text('closed')),
                ],
                onChanged: (v) {
                  if (v != null) status = v;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity fulfilled'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final q = int.tryParse(qtyController.text.trim());

                try {
                  await EquipmentManagementService.updateManagerEquipmentCampaign(
                    campaignId: campaignId,
                    status: status,
                    quantityFulfilled: q,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) Navigator.pop(context, false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
              child: const Text('Save'),
            )
          ],
        );
      },
    );

    if (result == true) {
      await _loadCampaigns();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Equipment Campaigns'),
        backgroundColor: AppColors.primaryDark,
        actions: [
          IconButton(
            onPressed: _loadCampaigns,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('open')),
                      DropdownMenuItem(value: 'partially_fulfilled', child: Text('partially_fulfilled')),
                      DropdownMenuItem(value: 'fulfilled', child: Text('fulfilled')),
                      DropdownMenuItem(value: 'closed', child: Text('closed')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _statusFilter = v;
                        _page = 1;
                      });
                      _loadCampaigns();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load: $_error'),
                ),
              ),
            )
          else if (_campaigns.isEmpty)
            const Expanded(child: Center(child: Text('No campaigns found')))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadCampaigns,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _campaigns.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _campaigns.length) {
                      return _PaginationBar(
                        page: _page,
                        pages: _pages,
                        onPrev: _page > 1
                            ? () {
                                setState(() => _page -= 1);
                                _loadCampaigns();
                              }
                            : null,
                        onNext: _page < _pages
                            ? () {
                                setState(() => _page += 1);
                                _loadCampaigns();
                              }
                            : null,
                      );
                    }

                    final c = _campaigns[index];
                    final title = (c['equipment_name'] ?? '').toString();
                    final type = (c['equipment_type'] ?? '').toString();
                    final status = (c['status'] ?? '').toString();
                    final needed = (c['quantity_needed'] ?? 1).toString();
                    final fulfilled = (c['quantity_fulfilled'] ?? 0).toString();
                    final priority = (c['priority_score_snapshot'] ?? 0).toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent2.withOpacity(0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _openUpdateDialog(c),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title.isEmpty ? 'Equipment Campaign' : title,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                ),
                                _StatusChip(status: status),
                              ],
                            ),
                            if (type.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(type, style: const TextStyle(color: AppColors.textGray)),
                            ],
                            const SizedBox(height: 8),
                            Text('Needed: $needed | Fulfilled: $fulfilled | Priority: $priority',
                                style: const TextStyle(color: AppColors.textGray)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _openUpdateDialog(c),
                                    child: const Text('Manage'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'open':
        color = AppColors.primary;
        break;
      case 'partially_fulfilled':
        color = Colors.orange;
        break;
      case 'fulfilled':
        color = Colors.green;
        break;
      case 'closed':
        color = Colors.grey;
        break;
      default:
        color = AppColors.textGray;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int pages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.page,
    required this.pages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(onPressed: onPrev, child: const Text('Prev')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Page $page / $pages'),
          ),
          TextButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}
