// lib/screens/manager/manager_donation_campaigns_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_dashboard_service.dart';

class ManagerDonationCampaignsScreen extends StatefulWidget {
  const ManagerDonationCampaignsScreen({Key? key}) : super(key: key);

  @override
  State<ManagerDonationCampaignsScreen> createState() => _ManagerDonationCampaignsScreenState();
}

class _ManagerDonationCampaignsScreenState extends State<ManagerDonationCampaignsScreen> {
  bool _isLoading = true;
  List<dynamic> _campaigns = [];

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  String _formatDate(dynamic v) {
    final dt = _parseDate(v);
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int? _daysLeft(dynamic endDate) {
    final end = _parseDate(endDate);
    if (end == null) return null;
    final now = DateTime.now();
    return end.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ManagerDashboardService.getDonationCampaigns();
      setState(() {
        _campaigns = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openCampaignDialog({Map<String, dynamic>? campaign}) async {
    final isEdit = campaign != null;

    final nameController = TextEditingController(text: campaign?['name']?.toString() ?? '');
    final descriptionController =
        TextEditingController(text: campaign?['description']?.toString() ?? '');
    final targetController = TextEditingController(
        text: campaign != null ? campaign['target_amount']?.toString() ?? '' : '');

    String status = campaign?['status']?.toString() ?? 'Upcoming';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Campaign' : 'Create Campaign'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target amount (JOD)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'Upcoming', child: Text('Upcoming')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'Archived', child: Text('Archived')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      status = val;
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Status',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final targetText = targetController.text.trim();
                if (name.isEmpty || targetText.isEmpty) {
                  return;
                }

                final body = <String, dynamic>{
                  'name': name,
                  'description': descriptionController.text.trim(),
                  'target_amount': double.tryParse(targetText) ?? 0,
                  'status': status,
                };

                try {
                  if (isEdit) {
                    await ManagerDashboardService.updateDonationCampaign(
                      campaign!['campaign_id'] as int,
                      body,
                    );
                  } else {
                    await ManagerDashboardService.createDonationCampaign(body);
                  }
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context, false);
                  }
                }
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _loadCampaigns();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: const Text('Donation Campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openCampaignDialog(),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCampaigns,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCampaignsSummary(),
                  const SizedBox(height: 12),
                  ..._campaigns.map((e) {
                    final c = e as Map<String, dynamic>;
                    return _buildCampaignTile(c);
                  }).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCampaignsSummary() {
    final campaigns = _campaigns.map((e) => e as Map<String, dynamic>).toList();
    final totalCollected = campaigns.fold<double>(0, (sum, c) => sum + _toDouble(c['total_donations']));
    final totalGoal = campaigns.fold<double>(0, (sum, c) => sum + _toDouble(c['target_amount']));
    final activeCount = campaigns.where((c) => (c['status'] ?? '').toString() == 'Active').length;
    final completionRate = totalGoal > 0 ? ((totalCollected / totalGoal) * 100).clamp(0.0, 100.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Campaigns Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  title: 'Total collected',
                  value: '${totalCollected.toStringAsFixed(0)} JOD',
                  icon: Icons.volunteer_activism,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiTile(
                  title: 'Campaigns goal',
                  value: '${totalGoal.toStringAsFixed(0)} JOD',
                  icon: Icons.flag,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  title: 'Active campaigns',
                  value: activeCount.toString(),
                  icon: Icons.campaign,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiTile(
                  title: 'Completion rate',
                  value: '${completionRate.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: AppColors.accent3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCampaignImpact(Map<String, dynamic> campaign) async {
    final campaignId = campaign['campaign_id'] as int?;
    if (campaignId == null) return;

    Map<String, dynamic>? impact;
    try {
      final result = await ManagerDashboardService.getDonationCampaignImpact(campaignId);
      impact = result;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load campaign impact: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted || impact == null) return;

    final double totalDonations = (impact['total_donations'] ?? 0).toDouble();
    final double targetAmount = (impact['target_amount'] ?? 0).toDouble();
    final double progress = (impact['progress_percentage'] ?? 0).toDouble();
    final double allocated = (impact['total_allocated_from_campaign'] ?? 0).toDouble();
    final int sessionsSupported = impact['supported_sessions_count'] ?? 0;
    final int childrenSupported = impact['supported_children_count'] ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      campaign['name']?.toString() ?? 'Campaign',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pop(context);
                      _openCampaignDialog(campaign: campaign);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                campaign['description']?.toString() ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress > 0 ? (progress / 100).clamp(0.0, 1.0) : 0.0,
                backgroundColor: Colors.grey.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent3),
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${totalDonations.toStringAsFixed(0)} / ${targetAmount.toStringAsFixed(0)} JOD',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${progress.toStringAsFixed(1)}% of target',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildImpactChip(
                    icon: Icons.event_available,
                    label: 'Sessions supported',
                    value: sessionsSupported.toString(),
                  ),
                  _buildImpactChip(
                    icon: Icons.child_care,
                    label: 'Children supported',
                    value: childrenSupported.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Allocated from this campaign: ${allocated.toStringAsFixed(0)} JOD',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImpactChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignTile(Map<String, dynamic> c) {
    final double target = (c['target_amount'] ?? 0).toDouble();
    final double total = (c['total_donations'] ?? 0).toDouble();
    final double progress = (c['progress_percentage'] ?? 0).toDouble();

    final donorsCount = _toInt(c['donors_count']);
    final remaining = (target - total) > 0 ? (target - total) : 0.0;
    final daysLeft = _daysLeft(c['end_date']);
    final startDate = _formatDate(c['start_date']);
    final endDate = _formatDate(c['end_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showCampaignImpact(c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    c['name']?.toString() ?? 'Campaign',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(c['status']?.toString() ?? ''),
              ],
            ),
            const SizedBox(height: 4),
            if ((c['description']?.toString().isNotEmpty ?? false))
              Text(
                c['description'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress > 0 ? (progress / 100).clamp(0.0, 1.0) : 0.0,
              backgroundColor: Colors.grey.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent3),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${total.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} JOD',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${progress.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetric(
                    label: 'Donors',
                    value: donorsCount.toString(),
                    icon: Icons.people,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMiniMetric(
                    label: 'Remaining',
                    value: '${remaining.toStringAsFixed(0)} JOD',
                    icon: Icons.savings,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMiniMetric(
                    label: 'Days left',
                    value: daysLeft == null ? '-' : (daysLeft < 0 ? '0' : daysLeft.toString()),
                    icon: Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Start: $startDate',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'End: $endDate',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showCampaignImpact(c),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.accent1.withOpacity(0.9)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('View analytics'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openCampaignDialog(campaign: c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Manage'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Active':
        color = Colors.green;
        break;
      case 'Completed':
        color = Colors.blueAccent;
        break;
      case 'Archived':
        color = Colors.grey;
        break;
      default:
        color = AppColors.warning;
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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
