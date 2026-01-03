import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'donation_invite_stats_screen.dart';

class DonationCampaignDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> institution;
  final Map<String, dynamic> campaign;
  final VoidCallback? onDonate;

  const DonationCampaignDetailsScreen({
    super.key,
    required this.institution,
    required this.campaign,
    this.onDonate,
  });

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final campaignId = campaign['campaign_id'] as int?;
    final title = (campaign['name'] ?? 'Campaign').toString();
    final description = (campaign['description'] ?? '').toString();

    final target = _toDouble(campaign['target_amount']);
    final raised = _toDouble(campaign['amount_raised'] ?? campaign['total_donations']);
    final progress = target > 0 ? (raised / target).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Campaign Details'),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (description.trim().isNotEmpty)
                    Text(description, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent3),
                    minHeight: 10,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${raised.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} JOD', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${(progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Institution: ${(institution['name'] ?? '').toString()}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (campaignId != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      final token = (prefs.getString('token') ?? '').trim();
                      if (token.isEmpty) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please login to create invite links'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final res = await ApiService.createDonationInvite(
                        token,
                        institutionId: institution['institution_id'] as int,
                        campaignId: campaignId,
                      );

                      final data = (res['data'] is Map)
                          ? Map<String, dynamic>.from(res['data'] as Map)
                          : <String, dynamic>{};
                      final code = (data['code'] ?? res['code'] ?? '').toString();
                      if (code.isEmpty) throw Exception('Missing invite code');

                      final shareText =
                          'Join me in supporting this campaign!\nInvite Code: $code\nUse it in the app when donating.';
                      await Share.share(shareText);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create invite: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Invite friends'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DonationInviteStatsScreen()),
                    );
                  },
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text('My invite impact'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            if (onDonate != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onDonate?.call();
                  },
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('Donate to this campaign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
