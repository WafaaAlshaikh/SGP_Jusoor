import 'package:flutter/material.dart';
import 'package:frontend/screens/donation_screen.dart';
import 'package:frontend/screens/equipment_donation_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class EquipmentCampaignsScreen extends StatefulWidget {
  const EquipmentCampaignsScreen({super.key});

  @override
  State<EquipmentCampaignsScreen> createState() => _EquipmentCampaignsScreenState();
}

class _EquipmentCampaignsScreenState extends State<EquipmentCampaignsScreen> {
  bool _loadingCampaigns = true;
  String? _error;

  List<Map<String, dynamic>> _campaigns = [];

  bool _isLoadingAI = false;
  String? _aiSummary;
  List<Map<String, dynamic>> _aiRecommendations = [];

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
    _loadDonorAIRecommendations();
  }

  Future<void> _loadDonorAIRecommendations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ?? '').trim();
      if (token.isEmpty) return;

      if (!mounted) return;
      setState(() {
        _isLoadingAI = true;
      });

      final result = await ApiService.getDonorAIRecommendations(token, limit: 6);

      if (!mounted) return;
      if (result['success'] == true) {
        final recs = (result['recommendations'] as List?) ?? [];
        setState(() {
          _aiSummary = result['ai_summary']?.toString();
          _aiRecommendations = recs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoadingAI = false;
        });
      } else {
        setState(() {
          _aiSummary = null;
          _aiRecommendations = [];
          _isLoadingAI = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiSummary = null;
        _aiRecommendations = [];
        _isLoadingAI = false;
      });
    }
  }

  Future<void> _loadCampaigns() async {
    try {
      setState(() {
        _loadingCampaigns = true;
        _error = null;
        _campaigns = [];
      });

      final campaigns = await ApiService.getOpenEquipmentCampaigns();

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

                final instObj = (c['institution'] is Map) ? Map<String, dynamic>.from(c['institution'] as Map) : null;
                final instId = (instObj?['institution_id'] is int)
                    ? instObj!['institution_id'] as int
                    : (c['institution_id'] is int ? c['institution_id'] as int : null);
                final instName = (instObj?['name'] ?? '').toString();

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
                                    builder: (_) => CombinedEquipmentScreen(
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
          await _loadCampaigns();
          await _loadDonorAIRecommendations();
        },
        child: SingleChildScrollView( // <-- تغيير من ListView إلى SingleChildScrollView
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              
              // AI Recommendations Section
              if (_isLoadingAI)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.primary.withOpacity(0.06),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Expanded(child: Text('Loading AI suggestions...')),
                    ],
                  ),
                )
              else if (_aiRecommendations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Suggestions for You',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if ((_aiSummary ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _aiSummary!,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],
                      const SizedBox(height: 16),
                      
                      // تحديد ارتفاع ثابت لـ ListView الأفقي
                      SizedBox(
                        height: 160, // <-- ارتفاع محدد لمنع التجاوز
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _aiRecommendations.length,
                          itemBuilder: (context, index) {
                            final r = _aiRecommendations[index];
                            final id = r['institution_id'];
                            final name = (r['name'] ?? '').toString();
                            final reasons = (r['reasons'] is List)
                                ? (r['reasons'] as List).map((x) => x.toString()).toList()
                                : <String>[];

                            return Container(
                              width: 300,
                              margin: EdgeInsets.only(
                                right: index == _aiRecommendations.length - 1 ? 0 : 12,
                              ),
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.isEmpty ? 'Institution' : name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded( // <-- إضافة Expanded للنص
                                        child: Text(
                                          reasons.isNotEmpty 
                                              ? reasons.join(', ') 
                                              : 'Suggested for you',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: id is int
                                                  ? () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => DonationScreen(
                                                            institutionId: id,
                                                            institutionName: name,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  : null,
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                side: BorderSide(color: AppColors.primary),
                                              ),
                                              child: const Text(
                                                'Donate Money',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: id is int
                                                  ? () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => CombinedEquipmentScreen(
                                                            institutionId: id,
                                                            institutionName: name,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                              ),
                                              child: const Text(
                                                'Donate Equipment',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Campaigns Section
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
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
              
              if (_loadingCampaigns)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_campaigns.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(
                    child: Text(
                      'No open equipment campaigns found.',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  ),
                )
              else
                Column(
                  children: _campaigns.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CampaignCard(
                        campaign: c,
                        onTap: () => _openCampaignDetails(c),
                      ),
                    ),
                  ).toList(),
                ),
              
              const SizedBox(height: 20), // مسافة إضافية في الأسفل
            ],
          ),
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
    final instObj = (campaign['institution'] is Map) ? Map<String, dynamic>.from(campaign['institution'] as Map) : null;
    final instName = (instObj?['name'] ?? '').toString();

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
                    if (instName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(instName, style: const TextStyle(color: AppColors.textGray)),
                    ],
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
