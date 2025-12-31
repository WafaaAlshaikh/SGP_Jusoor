import 'package:flutter/material.dart';
import 'package:frontend/screens/equipment_donation_screen.dart';
import 'package:frontend/screens/equipment_campaigns_screen.dart';
import '../theme/app_colors.dart';
import 'browse_centers_screen.dart';
import 'donation_screen.dart';
import 'reports_list_screen.dart';
import '../services/reports_service.dart';

class DonorDashboardScreen extends StatelessWidget {
  const DonorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Donor Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.12),
                  AppColors.accent1.withOpacity(0.55),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.accent2.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Support Families, Change Lives',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Browse institutions, explore their work, and donate to impactful programs.',
                  style: TextStyle(color: AppColors.textGray, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ActionCard(
            icon: Icons.apartment,
            title: 'Browse Institutions',
            subtitle: 'Explore institutions, media, team, and reviews',
            color: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrowseCentersScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.volunteer_activism,
            title: 'Donate',
            subtitle: 'Support an institution or a campaign',
            color: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DonationScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.flag_outlined,
            title: 'My Reports',
            subtitle: 'Submit a report and track responses',
            color: AppColors.warning,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportsListScreen(
                    scope: ReportsScope.user,
                    title: 'My Reports',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.campaign,
            title: 'Equipment Campaigns',
            subtitle: 'See what equipment is needed and donate directly',
            color: Colors.indigo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EquipmentCampaignsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.medical_services,
            title: 'Donate Equipment',
            subtitle: 'Donate medical equipment or devices',
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EquipmentDonationScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.textGray, height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}
