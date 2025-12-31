import 'package:flutter/material.dart';
import 'package:frontend/screens/equipment_donation_screen.dart';
import 'package:frontend/services/api_service.dart';
import '../theme/app_colors.dart';

class EquipmentCampaignsScreen extends StatefulWidget {
  const EquipmentCampaignsScreen({super.key});

  @override
  State<EquipmentCampaignsScreen> createState() => _EquipmentCampaignsScreenState();
}

class _EquipmentCampaignsScreenState extends State<EquipmentCampaignsScreen> {
  bool _loadingInstitutions = true;
  bool _loadingCampaigns = false;
  String? _error;

  List<Map<String, dynamic>> _institutions = [];
  int? _selectedInstitutionId;
  Map<String, dynamic>? _selectedInstitution;

  List<Map<String, dynamic>> _campaigns = [];

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    try {
      setState(() {
        _loadingInstitutions = true;
        _error = null;
      });

      final institutions = await ApiService.getEquipmentInstitutions();

      if (!mounted) return;
      setState(() {
        _institutions = institutions;
        _loadingInstitutions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load institutions';
        _loadingInstitutions = false;
      });
    }
  }

  Future<void> _loadCampaigns(int institutionId) async {
    try {
      setState(() {
        _loadingCampaigns = true;
        _error = null;
        _campaigns = [];
      });

      final campaigns = await ApiService.getInstitutionEquipmentCampaigns(institutionId);

      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _loadingCampaigns = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load campaigns';
        _loadingCampaigns = false;
      });
    }
  }

  void _selectInstitution(Map<String, dynamic> inst) {
    final id = inst['institution_id'];
    if (id is! int) return;

    setState(() {
      _selectedInstitutionId = id;
      _selectedInstitution = inst;
    });

    _loadCampaigns(id);
  }

  Future<void> _openCampaignDetails(Map<String, dynamic> campaign) async {
    final campaignId = campaign['campaign_id'];
    if (campaignId is! int) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return FutureBuilder<Map<String, dynamic>>(
              future: ApiService.getEquipmentCampaignDetails(campaignId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(child: Text('Failed to load campaign details'));
                }

                final c = snapshot.data!;
                final equipmentName = (c['equipment_name'] ?? '').toString();
                final equipmentType = (c['equipment_type'] ?? '').toString();
                final qtyNeeded = (c['quantity_needed'] ?? 1);
                final qtyFulfilled = (c['quantity_fulfilled'] ?? 0);
                final status = (c['status'] ?? '').toString();

                final inst = _selectedInstitution;
                final instId = inst?['institution_id'] is int ? inst!['institution_id'] as int : null;
                final instName = (inst?['name'] ?? '').toString();

                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 14,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Text(
                        equipmentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (equipmentType.isNotEmpty)
                        Text(
                          equipmentType,
                          style: const TextStyle(color: AppColors.textGray),
                        ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.accent2.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(label: 'Institution', value: instName.isEmpty ? '—' : instName),
                            const SizedBox(height: 6),
                            _InfoRow(label: 'Quantity Needed', value: qtyNeeded.toString()),
                            const SizedBox(height: 6),
                            _InfoRow(label: 'Quantity Fulfilled', value: qtyFulfilled.toString()),
                            const SizedBox(height: 6),
                            _InfoRow(label: 'Status', value: status),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: instId == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EquipmentDonationScreen(
                                      institutionId: instId,
                                      institutionName: instName,
                                      equipmentName: equipmentName,
                                      categoryId: c['category_id'] is int ? c['category_id'] as int : null,
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.volunteer_activism),
                        label: const Text('Donate This Equipment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Equipment Campaigns'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadInstitutions();
          if (_selectedInstitutionId != null) {
            await _loadCampaigns(_selectedInstitutionId!);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.accent2.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose an institution',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 10),
                  if (_loadingInstitutions)
                    const LinearProgressIndicator(minHeight: 3)
                  else
                    DropdownButtonFormField<int>(
                      value: _selectedInstitutionId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _institutions
                          .where((x) => x['institution_id'] is int)
                          .map(
                            (inst) => DropdownMenuItem<int>(
                              value: inst['institution_id'] as int,
                              child: Text((inst['name'] ?? '').toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final inst = _institutions.firstWhere(
                          (x) => x['institution_id'] == val,
                          orElse: () => <String, dynamic>{},
                        );
                        if (inst.isNotEmpty) {
                          _selectInstitution(inst);
                        }
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(0.25)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_selectedInstitutionId == null)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text('Select an institution to view equipment campaigns'),
                ),
              )
            else if (_loadingCampaigns)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_campaigns.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text('No open equipment campaigns found.')),
              )
            else
              ..._campaigns.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CampaignCard(
                    campaign: c,
                    onTap: () => _openCampaignDetails(c),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Map<String, dynamic> campaign;
  final VoidCallback onTap;

  const _CampaignCard({
    required this.campaign,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (campaign['equipment_name'] ?? '').toString();
    final type = (campaign['equipment_type'] ?? '').toString();
    final status = (campaign['status'] ?? '').toString();
    final needed = (campaign['quantity_needed'] ?? 1);
    final fulfilled = (campaign['quantity_fulfilled'] ?? 0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accent2.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.medical_services, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Equipment Campaign' : title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (type.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(type, style: const TextStyle(color: AppColors.textGray)),
                    ],
                    const SizedBox(height: 6),
                    Text('Needed: $needed | Fulfilled: $fulfilled', style: const TextStyle(color: AppColors.textGray)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _statusColor(status).withOpacity(0.25)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.primary;
      case 'partially_fulfilled':
        return Colors.orange;
      case 'fulfilled':
        return AppColors.success;
      case 'closed':
        return Colors.grey;
      default:
        return AppColors.textGray;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textGray),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}
