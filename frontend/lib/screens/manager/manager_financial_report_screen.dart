// lib/screens/manager/manager_financial_report_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_dashboard_service.dart';
import 'manager_advanced_financial_reports_screen.dart';

class ManagerFinancialReportScreen extends StatefulWidget {
  const ManagerFinancialReportScreen({Key? key}) : super(key: key);

  @override
  State<ManagerFinancialReportScreen> createState() => _ManagerFinancialReportScreenState();
}

class _ManagerFinancialReportScreenState extends State<ManagerFinancialReportScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ManagerDashboardService.getFinancialReport();
      setState(() {
        _data = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: const Text('Financial Report'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManagerAdvancedFinancialReportsScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.bar_chart_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: const Text(
              'Advanced',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildRevenueCards(),
                  const SizedBox(height: 16),
                  _buildDonationImpactCard(),
                  const SizedBox(height: 16),
                  _buildBreakdownChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final institution = _data['institution'] as Map<String, dynamic>? ?? {};
    final period = _data['period'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            institution['name']?.toString() ?? 'Institution',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Period: ${period['start'] ?? ''} to ${period['end'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCards() {
    final revenue = _data['revenue'] as Map<String, dynamic>? ?? {};

    final double paid = (revenue['paid'] ?? 0).toDouble();
    final double pending = (revenue['pending'] ?? 0).toDouble();
    final double overdue = (revenue['overdue'] ?? 0).toDouble();

    final int paidCount = (revenue['paidCount'] ?? 0) as int;
    final int pendingCount = (revenue['pendingCount'] ?? 0) as int;
    final int overdueCount = (revenue['overdueCount'] ?? 0) as int;

    return Row(
      children: [
        Expanded(
          child: _buildRevenueCard(
            title: 'Paid',
            amount: paid,
            count: paidCount,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildRevenueCard(
            title: 'Pending',
            amount: pending,
            count: pendingCount,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildRevenueCard(
            title: 'Overdue',
            amount: overdue,
            count: overdueCount,
            color: Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueCard({
    required String title,
    required double amount,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
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
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                ),
                child: Icon(
                  title == 'Paid'
                      ? Icons.check_circle_rounded
                      : title == 'Pending'
                          ? Icons.schedule_rounded
                          : Icons.warning_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(0)} JOD',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count invoices',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationImpactCard() {
    final donations = _data['donations'] as Map<String, dynamic>? ?? {};
    final impact = _data['impact'] as Map<String, dynamic>? ?? {};

    final double totalDonations = (donations['totalDonations'] ?? 0).toDouble();
    final double totalAllocated = (donations['totalAllocated'] ?? 0).toDouble();
    final double donationBalance = (donations['donationBalance'] ?? 0).toDouble();

    final double totalEconomicValue = (impact['totalEconomicValue'] ?? 0).toDouble();
    final double donationCoveragePercentage =
        (impact['donationCoveragePercentage'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Donations Impact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.volunteer_activism_rounded),
            ],
          ),
          const SizedBox(height: 12),
          _buildImpactRow('Total Donations', totalDonations),
          const SizedBox(height: 6),
          _buildImpactRow('Allocated to support', totalAllocated),
          const SizedBox(height: 6),
          _buildImpactRow('Current donation balance', donationBalance),
          const SizedBox(height: 12),
          if (totalEconomicValue > 0)
            Text(
              'Donations covered ${donationCoveragePercentage.toStringAsFixed(1)}% of this period\'s economic value.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildImpactRow(String title, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Text(
          '${value.toStringAsFixed(0)} JOD',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownChart() {
    final revenue = _data['revenue'] as Map<String, dynamic>? ?? {};
    final donations = _data['donations'] as Map<String, dynamic>? ?? {};

    final double paid = (revenue['paid'] ?? 0).toDouble();
    final double pending = (revenue['pending'] ?? 0).toDouble();
    final double overdue = (revenue['overdue'] ?? 0).toDouble();
    final double allocated = (donations['totalAllocated'] ?? 0).toDouble();

    final double total = paid + pending + overdue + allocated;
    if (total <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No enough data to display breakdown chart.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    double ratio(double v) => v <= 0 ? 0 : (v / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Breakdown (This Month)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final paidW = width * ratio(paid);
              final pendingW = width * ratio(pending);
              final overdueW = width * ratio(overdue);
              final donationW = width * ratio(allocated);

              return Stack(
                children: [
                  Container(
                    height: 16,
                    width: width,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    height: 16,
                    width: paidW,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Positioned(
                    left: paidW,
                    child: Container(
                      height: 16,
                      width: pendingW,
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Positioned(
                    left: paidW + pendingW,
                    child: Container(
                      height: 16,
                      width: overdueW,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Positioned(
                    left: paidW + pendingW + overdueW,
                    child: Container(
                      height: 16,
                      width: donationW,
                      decoration: BoxDecoration(
                        color: AppColors.accent3,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildLegendItem('Paid', Colors.green),
              _buildLegendItem('Pending', AppColors.warning),
              _buildLegendItem('Overdue', Colors.redAccent),
              _buildLegendItem('Supported by donations', AppColors.accent3),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        )
      ],
    );
  }
}
