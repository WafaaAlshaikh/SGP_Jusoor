import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../services/financial_reports_service.dart';

class ManagerAdvancedFinancialReportsScreen extends StatefulWidget {
  const ManagerAdvancedFinancialReportsScreen({Key? key}) : super(key: key);

  @override
  State<ManagerAdvancedFinancialReportsScreen> createState() =>
      _ManagerAdvancedFinancialReportsScreenState();
}

class _ManagerAdvancedFinancialReportsScreenState
    extends State<ManagerAdvancedFinancialReportsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _advancedV2;

  // Legacy fields (kept to avoid breaking existing helper methods in this file)
  Map<String, dynamic>? _monthlyReport;
  Map<String, dynamic>? _incomeExpense;
  Map<String, dynamic>? _advancedReport;
  Map<String, dynamic>? _familyAssistance;
  Map<String, dynamic>? _invoicesPayments;
  Map<String, dynamic>? _detailedReport;

  int _selectedYear = DateTime.now().year;
  bool _isLoadingDetailed = false;

  // V2 UI filters (Invoices)
  String _invoiceSearch = '';
  String _invoiceStatusFilter = 'All';
  int? _invoiceSpecialistIdFilter;
  double? _invoiceMinAmount;
  double? _invoiceMaxAmount;
  String _invoiceSort = 'Newest';

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  late TabController _tabController;
  final List<TabInfo> _tabs = [];
  bool _showCardView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedYear = DateTime.now().year;

    // تعريف التبويبات
    _tabs.addAll([
      TabInfo(title: 'Overview', icon: Icons.dashboard, color: AppColors.primary),
      TabInfo(title: 'Performance', icon: Icons.show_chart, color: AppColors.green),
      TabInfo(title: 'Invoices', icon: Icons.receipt_long, color: AppColors.darkGreen),
    ]);

    _loadData();
  }

  void _showDetailsSheet({required String title, required List<Widget> children}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(children: children),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // تصميم الكارت الرئيسي لكل تبويب
  Widget _buildTabCard(TabInfo tabInfo, Widget contentWidget) {
    return _showCardView
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: tabInfo.color.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  // رأس الكارت
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: tabInfo.color.withOpacity(0.08),
                      border: Border(
                        bottom: BorderSide(
                          color: tabInfo.color.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tabInfo.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(tabInfo.icon,
                              color: tabInfo.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tabInfo.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tabInfo.color,
                            ),
                          ),
                        ),
                        if (tabInfo.title == 'Detailed Report')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.accent1,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _selectedYear.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // محتوى الكارت
                  Expanded(
                    child: contentWidget,
                  ),
                ],
              ),
            ),
          )
        : contentWidget;
  }

  Widget _buildInvoicesPaymentsTab() {
    final data = _invoicesPayments;
    if (data == null) {
      return _buildNoDataView('Invoices & Payments');
    }

    final invoices = Map<String, dynamic>.from(data['invoices'] ?? {});
    final summary = Map<String, dynamic>.from(invoices['summary'] ?? {});
    final byStatus = Map<String, dynamic>.from(invoices['by_status'] ?? {});
    final payments = Map<String, dynamic>.from(data['payments'] ?? {});
    final paymentsSummary =
        Map<String, dynamic>.from(payments['summary'] ?? {});

    double _toDouble(dynamic v) => (v ?? 0).toDouble();

    final totalAmount = _toDouble(summary['total_amount']);
    final paidAmount = _toDouble(summary['paid_amount']);
    final pendingAmount = _toDouble(summary['pending_amount']);
    final overdueAmount = _toDouble(summary['overdue_amount']);
    final totalInvoices = _toDouble(summary['total_invoices']);

    final double collectionRate =
        totalAmount > 0 ? (paidAmount / totalAmount) * 100 : 0.0;
    final double overdueRatio =
        totalAmount > 0 ? (overdueAmount / totalAmount) * 100 : 0.0;

    Color _getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'paid':
          return AppColors.success;
        case 'pending':
          return AppColors.warning;
        case 'overdue':
          return AppColors.error;
        case 'draft':
          return AppColors.textLight;
        case 'cancelled':
          return Colors.grey;
        default:
          return AppColors.info;
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // KPIs الأساسية - بدون ارتفاع ثابت
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2, // زيادة نسبة العرض للارتفاع
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    switch (index) {
                      case 0:
                        return _buildDetailedMetricCard(
                          'Total Invoice Amount',
                          '${totalAmount.toStringAsFixed(0)} JOD',
                          Icons.receipt,
                          AppColors.primary,
                        );
                      case 1:
                        return _buildDetailedMetricCard(
                          'Paid Amount',
                          '${paidAmount.toStringAsFixed(0)} JOD',
                          Icons.check_circle,
                          AppColors.success,
                        );
                      case 2:
                        return _buildDetailedMetricCard(
                          'Collection Rate',
                          '${collectionRate.toStringAsFixed(1)}%',
                          Icons.trending_up,
                          collectionRate > 80
                              ? AppColors.success
                              : AppColors.warning,
                        );
                      case 3:
                        return _buildDetailedMetricCard(
                          'Overdue Ratio',
                          '${overdueRatio.toStringAsFixed(1)}%',
                          Icons.warning,
                          overdueRatio > 20
                              ? AppColors.error
                              : AppColors.warning,
                        );
                      default:
                        return Container();
                    }
                  },
                ),
                const SizedBox(height: 20),

                // نظرة كمية سريعة
                _buildSectionCard(
                  title: 'Invoices Overview',
                  icon: Icons.abc,
                  children: [
                    _buildInfoRow('Total invoices count',
                        totalInvoices.toStringAsFixed(0)),
                    const SizedBox(height: 8),
                    _buildInfoRow('Pending amount',
                        '${pendingAmount.toStringAsFixed(0)} JOD'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Overdue amount',
                        '${overdueAmount.toStringAsFixed(0)} JOD'),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // توزيع حسب الحالة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSectionCard(
              title: 'Invoices by Status',
              icon: Icons.stacked_bar_chart,
              children: [
                ...['Draft', 'Pending', 'Paid', 'Overdue', 'Cancelled']
                    .map((status) {
                  final statusData =
                      Map<String, dynamic>.from(byStatus[status] ?? {});
                  final amount = _toDouble(statusData['amount']);
                  final count = _toDouble(statusData['count']);
                  final percentage =
                      totalAmount > 0 ? (amount / totalAmount) * 100 : 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  status,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${amount.toStringAsFixed(0)} JOD',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 6,
                                backgroundColor: AppColors.accent1,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    _getStatusColor(status)),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${count.toStringAsFixed(0)} invoices',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ملخص الدفعات
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSectionCard(
              title: 'Payments Summary',
              icon: Icons.payments,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total payments',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _toDouble(paymentsSummary['total_payments'])
                              .toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total amount',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_toDouble(paymentsSummary['total_amount']).toStringAsFixed(0)} JOD',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDetailedReportTab() {
  final data = _detailedReport;

  if (_isLoadingDetailed) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading detailed report...',
            style: TextStyle(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  if (data == null) {
    return _buildNoDataView('Detailed Report');
  }

  final incomeExpense = Map<String, dynamic>.from(data['income_expense'] ?? {});
  final monthlyProfit = List<Map<String, dynamic>>.from(
    incomeExpense['monthly_profit'] ?? const [],
  );
  final kpis = Map<String, dynamic>.from(data['kpis'] ?? {});
  final projections = Map<String, dynamic>.from(data['projections'] ?? {});
  final recommendations = List<Map<String, dynamic>>.from(
    data['recommendations'] ?? const [],
  );

  double _toDouble(dynamic v) => (v ?? 0).toDouble();

  // فلترة السنوات
  final currentYear = DateTime.now().year;
  final years = List<int>.generate(5, (i) => currentYear - i);

  // حساب القيم
  final maxProfit = monthlyProfit.isNotEmpty
      ? monthlyProfit
          .map((m) => _toDouble(m['net_profit']))
          .fold<double>(0, (prev, v) => v > prev ? v : prev)
      : 0.0;

  final annualRevenue = _toDouble(kpis['annual_revenue']);
  final annualProfit = _toDouble(kpis['annual_profit']);
  final overallMargin = annualRevenue > 0 ? (annualProfit / annualRevenue) * 100 : 0.0;

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade700;
      case 'medium':
        return Colors.amber.shade700;
      case 'low':
      default:
        return AppColors.blue;
    }
  }

  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // اختيار السنة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent1, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report Year',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<int>(
                    isExpanded: true, // مهم جداً
                    value: years.contains(_selectedYear) ? _selectedYear : currentYear,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    items: years
                        .map(
                          (y) => DropdownMenuItem<int>(
                            value: y,
                            child: Text(
                              'Year $y',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) async {
                      if (val == null || val == _selectedYear) return;
                      setState(() {
                        _isLoadingDetailed = true;
                        _selectedYear = val;
                      });
                      try {
                        final detailed = await FinancialReportsService
                            .getDetailedFinancialReport(
                          year: val,
                        );
                        setState(() {
                          _detailedReport = detailed;
                          _isLoadingDetailed = false;
                        });
                      } catch (e) {
                        setState(() {
                          _error = e.toString();
                          _isLoadingDetailed = false;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
            const SizedBox(height: 20),

            // مؤشر هامش الربح
            _buildSectionCard(
              title: 'Overall Profit Margin',
              icon: Icons.pie_chart,
              children: [
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: overallMargin.abs() / 100,
                        strokeWidth: 12,
                        backgroundColor: AppColors.accent1,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overallMargin >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${overallMargin.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          overallMargin >= 0 ? 'Profit' : 'Loss',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: overallMargin >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${annualRevenue.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Revenue',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.accent1,
                    ),
                    Column(
                      children: [
                        Text(
                          '${annualProfit.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          'Profit',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // مؤشرات أداء أساسية - بدون ارتفاع ثابت
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2, // زيادة نسبة العرض للارتفاع
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildDetailedMetricCard(
                      'Annual Revenue',
                      '${annualRevenue.toStringAsFixed(0)} JOD',
                      Icons.monetization_on,
                      AppColors.primary,
                    );
                  case 1:
                    return _buildDetailedMetricCard(
                      'Annual Profit',
                      '${annualProfit.toStringAsFixed(0)} JOD',
                      Icons.trending_up,
                      annualProfit >= 0 ? AppColors.success : AppColors.error,
                    );
                  case 2:
                    return _buildDetailedMetricCard(
                      'Avg Monthly Margin',
                      '${_toDouble(kpis['average_monthly_profit_margin']).toStringAsFixed(1)}%',
                      Icons.show_chart,
                      AppColors.ment,
                    );
                  case 3:
                    return _buildDetailedMetricCard(
                      'Projected Profit',
                      '${_toDouble(projections['projected_annual_profit']).toStringAsFixed(0)} JOD',
                      Icons.auto_graph,
                      AppColors.blue,
                    );
                  default:
                    return Container();
                }
              },
            ),
            const SizedBox(height: 20),

            // مخطط الربح الشهري
            if (monthlyProfit.isNotEmpty)
              Column(
                children: [
                  _buildSectionCard(
                    title: 'Monthly Profit Chart',
                    icon: Icons.bar_chart,
                    children: [
                      const SizedBox(height: 16),
                      ...monthlyProfit.map((m) {
                        final month = m['month'] ?? '';
                        final profit = _toDouble(m['net_profit']);
                        final ratio = maxProfit > 0
                            ? (profit / maxProfit).clamp(0.0, 1.0)
                            : 0.0;
                        final isNegative = profit < 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Month $month',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    '${profit.toStringAsFixed(0)} JOD',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isNegative
                                          ? AppColors.error
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 30,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.accent1,
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: ratio,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: isNegative
                                          ? AppColors.error
                                          : AppColors.success,
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          (isNegative
                                                  ? AppColors.error
                                                  : AppColors.success)
                                              .withOpacity(0.8),
                                          (isNegative
                                              ? AppColors.error
                                              : AppColors.success),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),

            // التوصيات
            if (recommendations.isNotEmpty)
              _buildSectionCard(
                title: 'Recommendations',
                icon: Icons.lightbulb,
                children: [
                  const SizedBox(height: 16),
                  ...recommendations.map((r) {
                    final priority = (r['priority'] ?? '').toString();
                    final description = (r['description'] ?? '').toString();
                    final category = (r['category'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent1.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _priorityColor(priority).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _priorityColor(priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    _priorityColor(priority).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _priorityColor(priority),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (category.isNotEmpty)
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                if (category.isNotEmpty)
                                  const SizedBox(height: 4),
                                Text(
                                  description,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

    Widget _buildNoDataView(String tabName) {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.data_usage,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No $tabName data available',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try loading the data again',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reload Data'),
          ),
        ],
      ),
    ));
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final v2 = await FinancialReportsService.getAdvancedFinancialReportV2(
        startDate: _startDate.toIso8601String().split('T')[0],
        endDate: _endDate.toIso8601String().split('T')[0],
        limitInvoices: 50,
        limitSpecialists: 10,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _advancedV2 = v2;
        _isLoading = false;
      });
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: const Text('Financial Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: AppColors.textWhite),
            onPressed: _pickDateRange,
            tooltip: 'Report period',
          ),
          // IconButton(
          //   icon: Icon(
          //     _showCardView ? Icons.view_list : Icons.dashboard,
          //     color: AppColors.textWhite,
          //   ),
          //   onPressed: () {
          //     setState(() {
          //       _showCardView = !_showCardView;
          //     });
          //   },
          //   tooltip:
          //       _showCardView ? 'Switch to list view' : 'Switch to card view',
          // ),
        ],
        bottom:TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.textWhite,
                unselectedLabelColor: AppColors.textWhite.withOpacity(0.7),
                indicatorColor: AppColors.textWhite,
                indicatorWeight: 3,
                tabs: _tabs.map((tab) => Tab(text: tab.title)).toList(),
              )
              ) ,
      backgroundColor: AppColors.background,
      body: _isLoading
          ? _buildLoadingView()
          : _error != null
              ? _buildError()
                  : _buildTabView(),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 5, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadData();
    }
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading financial reports...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textLight.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView() {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.background,
        onRefresh: _loadData,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1, // تغيير من 1.2 إلى 1.1
          ),
          itemCount: _tabs.length,
          itemBuilder: (context, index) {
            final tab = _tabs[index];
            return _buildCardViewTabItem(tab);
          },
        ),
      ),
    );
  }

  Widget _buildCardViewTabItem(TabInfo tab) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCardView = false;
          _tabController.animateTo(indexOfTab(tab.title));
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16), // تصغير radius
          boxShadow: [
            BoxShadow(
              color: tab.color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12), // تقليل padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // تقليل padding
                  decoration: BoxDecoration(
                    color: tab.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tab.icon,
                      color: tab.color, size: 20), // تصغير الأيقونة
                ),
                const SizedBox(height: 12),
                Text(
                  tab.title,
                  style: const TextStyle(
                    fontSize: 14, // تصغير الخط
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'View details',
                  style: TextStyle(
                    fontSize: 10, // تصغير الخط
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabView() {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.background,
        onRefresh: _loadData,
        child: TabBarView(
          controller: _tabController,
          children: _tabs.map((tab) {
            return _buildTabContent(tab);
          }).toList(),
        ),
      ),
    );
  }

  int indexOfTab(String title) {
    return _tabs.indexWhere((tab) => tab.title == title);
  }

  Widget _buildTabContent(TabInfo tab) {
    switch (tab.title) {
      case 'Overview':
        return _buildOverviewV2Tab();
      case 'Performance':
        return _buildPerformanceV2Tab();
      case 'Invoices':
        return _buildInvoicesV2Tab();
      default:
        return Container();
    }
  }

  Map<String, dynamic> _v2Data() {
    return Map<String, dynamic>.from(_advancedV2 ?? {});
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Widget _buildOverviewV2Tab() {
    final data = _v2Data();
    if (data.isEmpty) return _buildNoDataView('Overview');

    final kpis = Map<String, dynamic>.from(data['kpis'] ?? {});
    final summary = Map<String, dynamic>.from(data['financial_summary'] ?? {});
    final health = Map<String, dynamic>.from(data['financial_health'] ?? {});

    final revenueSources = Map<String, dynamic>.from(data['revenue_sources'] ?? {});
    final sessionPayments = Map<String, dynamic>.from(revenueSources['session_payments'] ?? {});
    final donations = Map<String, dynamic>.from(revenueSources['donations'] ?? {});

    final expenses = Map<String, dynamic>.from(data['expenses'] ?? {});

    final totalRevenue = _toDouble(kpis['total_revenue']);
    final totalExpenses = _toDouble(kpis['total_expenses']);
    final netProfit = _toDouble(kpis['net_profit']);
    final profitMargin = _toDouble(kpis['profit_margin']);
    final healthScore = _toDouble(health['score']);

    final receivables = Map<String, dynamic>.from(health['receivables'] ?? {});
    final pending = Map<String, dynamic>.from(receivables['pending'] ?? {});
    final overdue = Map<String, dynamic>.from(receivables['overdue'] ?? {});
    final pendingAmount = _toDouble(pending['amount']);
    final overdueAmount = _toDouble(overdue['amount']);
    final receivablesTotal = pendingAmount + overdueAmount;

    final List<Map<String, dynamic>> insights = [];
    if (profitMargin < 5) {
      insights.add({
        'title': 'Low profit margin',
        'desc': 'Profit margin is low. Consider reviewing costs or pricing.',
        'color': AppColors.warning,
      });
    }
    if (receivablesTotal > 0) {
      insights.add({
        'title': 'Receivables detected',
        'desc': 'There are pending/overdue invoices. Follow up to improve cash flow.',
        'color': AppColors.error,
      });
    }
    if (healthScore >= 80) {
      insights.add({
        'title': 'Healthy finances',
        'desc': 'Financial health score is strong. Keep monitoring trends.',
        'color': AppColors.success,
      });
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                InkWell(
                  onTap: () {
                    _showDetailsSheet(
                      title: 'Total Revenue',
                      children: [
                        _buildInfoRow('Session payments', '${_toDouble(sessionPayments['amount']).toStringAsFixed(0)} JOD'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Donations', '${_toDouble(donations['amount']).toStringAsFixed(0)} JOD'),
                      ],
                    );
                  },
                  child: _buildDetailedMetricCard(
                    'Total Revenue',
                    '${totalRevenue.toStringAsFixed(0)} JOD',
                    Icons.monetization_on,
                    AppColors.primary,
                  ),
                ),
                InkWell(
                  onTap: () {
                    _showDetailsSheet(
                      title: 'Total Expenses',
                      children: [
                        _buildInfoRow('Staff salaries', '${_toDouble(expenses['staff_salaries']).toStringAsFixed(0)} JOD'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Donation allocations', '${_toDouble(expenses['donation_allocations']).toStringAsFixed(0)} JOD'),
                      ],
                    );
                  },
                  child: _buildDetailedMetricCard(
                    'Total Expenses',
                    '${totalExpenses.toStringAsFixed(0)} JOD',
                    Icons.money_off,
                    AppColors.red,
                  ),
                ),
                InkWell(
                  onTap: () {
                    _showDetailsSheet(
                      title: 'Net Profit',
                      children: [
                        _buildInfoRow('Total revenue', '${totalRevenue.toStringAsFixed(0)} JOD'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Total expenses', '${totalExpenses.toStringAsFixed(0)} JOD'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Profit margin', '${profitMargin.toStringAsFixed(1)}%'),
                      ],
                    );
                  },
                  child: _buildDetailedMetricCard(
                    'Net Profit',
                    '${netProfit.toStringAsFixed(0)} JOD',
                    Icons.trending_up,
                    netProfit >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
                InkWell(
                  onTap: () {
                    _showDetailsSheet(
                      title: 'Profit Margin',
                      children: [
                        _buildInfoRow('Net profit', '${netProfit.toStringAsFixed(0)} JOD'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Total revenue', '${totalRevenue.toStringAsFixed(0)} JOD'),
                      ],
                    );
                  },
                  child: _buildDetailedMetricCard(
                    'Profit Margin',
                    '${profitMargin.toStringAsFixed(1)}%',
                    Icons.percent,
                    AppColors.ment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionCard(
              title: 'Receivables',
              icon: Icons.account_balance_wallet,
              children: [
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: pendingAmount,
                          title: receivablesTotal > 0 ? '${((pendingAmount / receivablesTotal) * 100).toStringAsFixed(0)}%' : '0%',
                          color: AppColors.warning,
                          radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        PieChartSectionData(
                          value: overdueAmount,
                          title: receivablesTotal > 0 ? '${((overdueAmount / receivablesTotal) * 100).toStringAsFixed(0)}%' : '0%',
                          color: AppColors.error,
                          radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Pending', '${pendingAmount.toStringAsFixed(0)} JOD'),
                const SizedBox(height: 6),
                _buildInfoRow('Overdue', '${overdueAmount.toStringAsFixed(0)} JOD'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _invoiceStatusFilter = 'Overdue';
                            _tabController.animateTo(2);
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.textWhite,
                        ),
                        child: const Text('View overdue invoices'),
                      ),
                    )
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionCard(
              title: 'Financial Summary',
              icon: Icons.summarize,
              children: [
                _buildInfoRow('Sessions completed', (_toDouble(summary['sessions_completed']).toStringAsFixed(0))),
                const SizedBox(height: 8),
                _buildInfoRow('Active donors', (_toDouble(summary['active_donors']).toStringAsFixed(0))),
                const SizedBox(height: 8),
                _buildInfoRow('Avg session price', '${_toDouble(summary['avg_session_price']).toStringAsFixed(0)} JOD'),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Financial Health',
              icon: Icons.health_and_safety,
              children: [
                _buildInfoRow('Health score', '${healthScore.toStringAsFixed(0)}/100'),
                const SizedBox(height: 8),
                _buildInfoRow('Donation utilization', '${_toDouble(health['donation_utilization']).toStringAsFixed(1)}%'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _showDetailsSheet(
                        title: 'Financial Health Details',
                        children: [
                          _buildInfoRow('Score', '${healthScore.toStringAsFixed(0)}/100'),
                          const SizedBox(height: 8),
                          _buildInfoRow('Profit margin', '${profitMargin.toStringAsFixed(1)}%'),
                          const SizedBox(height: 8),
                          _buildInfoRow('Total receivables', '${receivablesTotal.toStringAsFixed(0)} JOD'),
                        ],
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textWhite,
                    ),
                    child: const Text('Show health insights'),
                  ),
                ),
              ],
            ),
            if (insights.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Insights & Recommendations',
                icon: Icons.lightbulb,
                children: insights.map((i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (i['color'] as Color).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (i['color'] as Color).withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info, color: i['color'] as Color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (i['title'] ?? '').toString(),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (i['desc'] ?? '').toString(),
                                style: TextStyle(color: AppColors.textLight, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceV2Tab() {
    final data = _v2Data();
    if (data.isEmpty) return _buildNoDataView('Performance');

    final revenueSources = Map<String, dynamic>.from(data['revenue_sources'] ?? {});
    final sessionPayments = Map<String, dynamic>.from(revenueSources['session_payments'] ?? {});
    final donations = Map<String, dynamic>.from(revenueSources['donations'] ?? {});

    final sessionAmount = _toDouble(sessionPayments['amount']);
    final donationAmount = _toDouble(donations['amount']);
    final total = sessionAmount + donationAmount;

    final monthly = (data['monthly_performance'] as List?) ?? [];
    final topSpecialists = (data['top_specialists'] as List?) ?? [];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSectionCard(
              title: 'Revenue Sources',
              icon: Icons.pie_chart,
              children: [
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: sessionAmount,
                          title: total > 0 ? '${((sessionAmount / total) * 100).toStringAsFixed(0)}%' : '0%',
                          color: AppColors.primary,
                          radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        PieChartSectionData(
                          value: donationAmount,
                          title: total > 0 ? '${((donationAmount / total) * 100).toStringAsFixed(0)}%' : '0%',
                          color: AppColors.green,
                          radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Session payments', '${sessionAmount.toStringAsFixed(0)} JOD'),
                const SizedBox(height: 6),
                _buildInfoRow('Donations', '${donationAmount.toStringAsFixed(0)} JOD'),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Monthly Performance',
              icon: Icons.show_chart,
              children: [
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          spots: monthly.asMap().entries.map((e) {
                            final idx = e.key;
                            final row = Map<String, dynamic>.from(e.value as Map);
                            return FlSpot(idx.toDouble(), _toDouble(row['total_revenue']));
                          }).toList(),
                        ),
                        LineChartBarData(
                          isCurved: true,
                          color: AppColors.red,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          spots: monthly.asMap().entries.map((e) {
                            final idx = e.key;
                            final row = Map<String, dynamic>.from(e.value as Map);
                            return FlSpot(idx.toDouble(), _toDouble(row['total_expenses']));
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text('Revenue', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                    const SizedBox(width: 14),
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text('Expenses', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionCard(
              title: 'Top Specialists (Revenue)',
              icon: Icons.bar_chart,
              children: [
                SizedBox(
                  height: 240,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: topSpecialists.take(8).toList().asMap().entries.map((e) {
                        final idx = e.key;
                        final row = Map<String, dynamic>.from(e.value as Map);
                        final y = _toDouble(row['paid_revenue']);
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: y,
                              width: 14,
                              borderRadius: BorderRadius.circular(6),
                              color: AppColors.primary,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Top Performing Specialists',
              icon: Icons.star,
              children: [
                if (topSpecialists.isEmpty)
                  Text('No data', style: TextStyle(color: AppColors.textLight))
                else
                  ...topSpecialists.take(10).map((s) {
                    final row = Map<String, dynamic>.from(s as Map);
                    final name = (row['specialist_name'] ?? 'Unknown').toString();
                    final revenue = _toDouble(row['paid_revenue']);
                    final count = _toDouble(row['paid_invoices_count']).toStringAsFixed(0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('$count invoices', style: TextStyle(color: AppColors.textLight)),
                          const SizedBox(width: 10),
                          Text('${revenue.toStringAsFixed(0)} JOD', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildInvoicesV2Tab() {
  final data = _v2Data();
  if (data.isEmpty) return _buildNoDataView('Invoices');

  final invoices = Map<String, dynamic>.from(data['invoices'] ?? {});
  final list = (invoices['list'] as List?) ?? [];
  final topSpecialists = (data['top_specialists'] as List?) ?? [];

  final uniqueSpecialists = <int, String>{};
  for (final s in topSpecialists) {
    final row = Map<String, dynamic>.from(s as Map);
    final id = int.tryParse((row['specialist_id'] ?? '').toString());
    if (id == null) continue;
    uniqueSpecialists.putIfAbsent(id, () => (row['specialist_name'] ?? 'Unknown').toString());
  }

  final specialistItems = <DropdownMenuItem<int?>>[
    const DropdownMenuItem<int?>(value: null, child: Text('All specialists')),
    ...uniqueSpecialists.entries.map((e) {
      return DropdownMenuItem<int?>(
        value: e.key,
        child: Text(
          e.value,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }).toList(),
  ];

  final selectedSpecialistValue = (_invoiceSpecialistIdFilter != null && uniqueSpecialists.containsKey(_invoiceSpecialistIdFilter))
      ? _invoiceSpecialistIdFilter
      : null;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'overdue':
        return AppColors.error;
      case 'draft':
        return AppColors.textLight;
      case 'cancelled':
        return Colors.grey;
      default:
        return AppColors.info;
    }
  }

  List<Map<String, dynamic>> filtered = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  bool matchesSearch(Map<String, dynamic> inv) {
    if (_invoiceSearch.trim().isEmpty) return true;
    final q = _invoiceSearch.trim().toLowerCase();
    final invoiceNumber = (inv['invoice_number'] ?? '').toString().toLowerCase();
    final status = (inv['status'] ?? '').toString().toLowerCase();

    final parent = inv['parent'] is Map ? Map<String, dynamic>.from(inv['parent'] as Map) : <String, dynamic>{};
    final parentName = (parent['full_name'] ?? '').toString().toLowerCase();

    final session = inv['Session'] is Map ? Map<String, dynamic>.from(inv['Session'] as Map) : <String, dynamic>{};
    final specialist = session['specialist'] is Map ? Map<String, dynamic>.from(session['specialist'] as Map) : <String, dynamic>{};
    final specialistName = (specialist['full_name'] ?? '').toString().toLowerCase();

    return invoiceNumber.contains(q) || status.contains(q) || parentName.contains(q) || specialistName.contains(q);
  }

  bool matchesFilters(Map<String, dynamic> inv) {
    if (_invoiceStatusFilter != 'All') {
      if ((inv['status'] ?? '').toString().toLowerCase() != _invoiceStatusFilter.toLowerCase()) return false;
    }

    if (_invoiceSpecialistIdFilter != null) {
      final session = inv['Session'] is Map ? Map<String, dynamic>.from(inv['Session'] as Map) : <String, dynamic>{};
      final specialist = session['specialist'] is Map ? Map<String, dynamic>.from(session['specialist'] as Map) : <String, dynamic>{};
      final sid = int.tryParse((specialist['user_id'] ?? '').toString());
      if (sid == null || sid != _invoiceSpecialistIdFilter) return false;
    }

    final amount = _toDouble(inv['total_amount']);
    if (_invoiceMinAmount != null && amount < _invoiceMinAmount!) return false;
    if (_invoiceMaxAmount != null && amount > _invoiceMaxAmount!) return false;
    return true;
  }

  filtered = filtered.where((inv) => matchesSearch(inv) && matchesFilters(inv)).toList();

  filtered.sort((a, b) {
    final aDate = DateTime.tryParse((a['issued_date'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = DateTime.tryParse((b['issued_date'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final aAmount = _toDouble(a['total_amount']);
    final bAmount = _toDouble(b['total_amount']);

    switch (_invoiceSort) {
      case 'Oldest':
        return aDate.compareTo(bDate);
      case 'AmountDesc':
        return bAmount.compareTo(aAmount);
      case 'AmountAsc':
        return aAmount.compareTo(bAmount);
      case 'Newest':
      default:
        return bDate.compareTo(aDate);
    }
  });

  // استبدل Column بـ SingleChildScrollView مع Padding
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search invoices...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.accent1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (v) => setState(() => _invoiceSearch = v),
          ),
          const SizedBox(height: 10),
          
          // Status filter
          DropdownButtonFormField<String>(
            value: _invoiceStatusFilter,
            decoration: InputDecoration(
              labelText: 'Status',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.accent1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Paid', child: Text('Paid')),
              DropdownMenuItem(value: 'Pending', child: Text('Pending')),
              DropdownMenuItem(value: 'Overdue', child: Text('Overdue')),
              DropdownMenuItem(value: 'Draft', child: Text('Draft')),
              DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
            ],
            onChanged: (v) => setState(() => _invoiceStatusFilter = v ?? 'All'),
            style: TextStyle(
  fontSize: 14,
  color: AppColors.textDark, // ← هذا هو اللون الجديد
  overflow: TextOverflow.ellipsis,
),
            isExpanded: true,
          ),
          const SizedBox(height: 10),
          
//           // Specialist filter
//           DropdownButtonFormField<int?>(
//             value: selectedSpecialistValue,
//             decoration: InputDecoration(
//               labelText: 'Specialist',
//               filled: true,
//               fillColor: AppColors.surface,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(14),
//                 borderSide: BorderSide(color: AppColors.accent1),
//               ),
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//             ),
//             items: specialistItems,
//             onChanged: (v) => setState(() => _invoiceSpecialistIdFilter = v),
// style: TextStyle(
//   fontSize: 14,
//   color: AppColors.textDark, // ← هذا هو اللون الجديد
//   overflow: TextOverflow.ellipsis,
// ),            isExpanded: true,
//           ),
//           const SizedBox(height: 10),
          
          // Sort and Reset in Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _invoiceSort,
                  decoration: InputDecoration(
                    labelText: 'Sort by',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.accent1),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Newest', child: Text('Newest')),
                    DropdownMenuItem(value: 'Oldest', child: Text('Oldest')),
                    DropdownMenuItem(value: 'AmountDesc', child: Text('Amount (high-low)')),
                    DropdownMenuItem(value: 'AmountAsc', child: Text('Amount (low-high)')),
                  ],
                  onChanged: (v) => setState(() => _invoiceSort = v ?? 'Newest'),
                  style: TextStyle(
  fontSize: 14,
  color: AppColors.textDark, // ← هذا هو اللون الجديد
  overflow: TextOverflow.ellipsis,
),
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _invoiceSearch = '';
                    _invoiceStatusFilter = 'All';
                    _invoiceSpecialistIdFilter = null;
                    _invoiceMinAmount = null;
                    _invoiceMaxAmount = null;
                    _invoiceSort = 'Newest';
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  side: BorderSide(color: AppColors.accent1),
                ),
                child: const Text('Reset', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Results and Amount Filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Results: ${filtered.length}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              TextButton(
                onPressed: _showAmountFilterDialog,
                child: const Text('Amount filter'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Invoices List - بدون Expanded
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 64, color: AppColors.textLight),
                  const SizedBox(height: 16),
                  Text(
                    'No invoices found',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((inv) {
              final invoiceNumber = (inv['invoice_number'] ?? '').toString();
              final status = (inv['status'] ?? '').toString();
              final totalAmount = _toDouble(inv['total_amount']);
              final issued = (inv['issued_date'] ?? '').toString();
              final due = (inv['due_date'] ?? '').toString();

              final parent = inv['parent'] is Map ? Map<String, dynamic>.from(inv['parent'] as Map) : <String, dynamic>{};
              final parentName = (parent['full_name'] ?? 'Unknown').toString();

              final session = inv['Session'] is Map ? Map<String, dynamic>.from(inv['Session'] as Map) : <String, dynamic>{};
              final specialist = session['specialist'] is Map ? Map<String, dynamic>.from(session['specialist'] as Map) : <String, dynamic>{};
              final specialistName = (specialist['full_name'] ?? 'Unknown').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accent1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            invoiceNumber.isEmpty ? 'Invoice' : 'Invoice #$invoiceNumber',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
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
                    const SizedBox(height: 10),
                    _buildInfoRow('Parent', parentName),
                    const SizedBox(height: 6),
                    _buildInfoRow('Specialist', specialistName),
                    const SizedBox(height: 6),
                    _buildInfoRow('Total', '${totalAmount.toStringAsFixed(0)} JOD'),
                    const SizedBox(height: 6),
                    _buildInfoRow('Issued', issued.split('T').first),
                    const SizedBox(height: 6),
                    _buildInfoRow('Due', due.split('T').first),
                  ],
                ),
              );
            }).toList(),
          
          const SizedBox(height: 32), // مساحة إضافية في الأسفل
        ],
      ),
    ),
  );
}

void _showAmountFilterDialog() {
  TextEditingController minController = TextEditingController();
  TextEditingController maxController = TextEditingController();
  
  if (_invoiceMinAmount != null) {
    minController.text = _invoiceMinAmount!.toStringAsFixed(0);
  }
  if (_invoiceMaxAmount != null) {
    maxController.text = _invoiceMaxAmount!.toStringAsFixed(0);
  }

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Amount Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Min amount (JOD)',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: maxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max amount (JOD)',
                hintText: '1000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _invoiceMinAmount = null;
                _invoiceMaxAmount = null;
              });
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _invoiceMinAmount = double.tryParse(minController.text);
                _invoiceMaxAmount = double.tryParse(maxController.text);
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      );
    },
  );
}

  Widget _buildError() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error, color: AppColors.error),
                      const SizedBox(width: 8),
                      const Text(
                        'Failed to load financial reports',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error ?? 'Unknown error occurred',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loadData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textWhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent1, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent1, width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent1, width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueDonationsTab() {
    final report = _monthlyReport;
    if (report == null) {
      return _buildNoDataView('Revenue & Donations');
    }

    final revenue = Map<String, dynamic>.from(report['revenue'] ?? {});
    final donations = Map<String, dynamic>.from(report['donations'] ?? {});

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // GridView بدون ارتفاع ثابت
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3, // زيادة النسبة
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildDetailedMetricCard(
                      'Total Invoices Revenue',
                      '${(revenue['total'] ?? 0).toDouble().toStringAsFixed(0)} JOD',
                      Icons.receipt,
                      AppColors.primary,
                    );
                  case 1:
                    return _buildDetailedMetricCard(
                      'Paid Invoices',
                      (revenue['count'] ?? 0).toString(),
                      Icons.check_circle,
                      AppColors.success,
                    );
                  case 2:
                    return _buildDetailedMetricCard(
                      'Total Donations',
                      '${(donations['total'] ?? 0).toDouble().toStringAsFixed(0)} JOD',
                      Icons.volunteer_activism,
                      AppColors.green,
                    );
                  case 3:
                    return _buildDetailedMetricCard(
                      'Average Donation',
                      '${(donations['average'] ?? 0).toDouble().toStringAsFixed(0)} JOD',
                      Icons.attach_money,
                      AppColors.blue,
                    );
                  default:
                    return Container();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseTab() {
    final data = _incomeExpense;
    if (data == null) {
      return _buildNoDataView('Income vs Expenses');
    }

    final kpis = Map<String, dynamic>.from(data['kpis'] ?? {});

    double _toDouble(dynamic v) => (v ?? 0).toDouble();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // GridView بدون ارتفاع ثابت
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildDetailedMetricCard(
                      'Annual Revenue',
                      '${_toDouble(kpis['annual_revenue']).toStringAsFixed(0)} JOD',
                      Icons.monetization_on,
                      AppColors.primary,
                    );
                  case 1:
                    return _buildDetailedMetricCard(
                      'Annual Expenses',
                      '${_toDouble(kpis['annual_expenses']).toStringAsFixed(0)} JOD',
                      Icons.money_off,
                      AppColors.red,
                    );
                  case 2:
                    return _buildDetailedMetricCard(
                      'Annual Profit',
                      '${_toDouble(kpis['annual_profit']).toStringAsFixed(0)} JOD',
                      Icons.trending_up,
                      _toDouble(kpis['annual_profit']) >= 0
                          ? AppColors.success
                          : AppColors.error,
                    );
                  case 3:
                    return _buildDetailedMetricCard(
                      'Avg Monthly Margin',
                      '${_toDouble(kpis['average_monthly_profit_margin']).toStringAsFixed(1)}%',
                      Icons.show_chart,
                      AppColors.ment,
                    );
                  default:
                    return Container();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedBreakdownTab() {
    final data = _advancedReport;
    if (data == null) {
      return _buildNoDataView('Advanced Breakdown');
    }

    final revenue = Map<String, dynamic>.from(data['revenue'] ?? {});
    final sessions = Map<String, dynamic>.from(revenue['sessions'] ?? {});
    final expenses = Map<String, dynamic>.from(data['expenses'] ?? {});
    final staff = Map<String, dynamic>.from(expenses['staff_salaries'] ?? {});
    final donations = Map<String, dynamic>.from(data['donations'] ?? {});
    final donationSummary =
        Map<String, dynamic>.from(donations['summary'] ?? {});

    double _toDouble(dynamic v) => (v ?? 0).toDouble();

    final paid = Map<String, dynamic>.from(sessions['paid'] ?? {});
    final totalStaffSalaries = _toDouble(staff['total']);
    final donationBalance = _toDouble(donationSummary['current_balance']);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // GridView بدون ارتفاع ثابت
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildDetailedMetricCard(
                      'Paid Session Revenue',
                      '${_toDouble(paid['amount']).toStringAsFixed(0)} JOD',
                      Icons.video_call,
                      AppColors.primary,
                    );
                  case 1:
                    return _buildDetailedMetricCard(
                      'Staff Salaries',
                      '${totalStaffSalaries.toStringAsFixed(0)} JOD',
                      Icons.people,
                      AppColors.red,
                    );
                  case 2:
                    return _buildDetailedMetricCard(
                      'Net Surplus',
                      '${(_toDouble(paid['amount']) - totalStaffSalaries).toStringAsFixed(0)} JOD',
                      Icons.balance,
                      (_toDouble(paid['amount']) - totalStaffSalaries) >= 0
                          ? AppColors.success
                          : AppColors.error,
                    );
                  case 3:
                    return _buildDetailedMetricCard(
                      'Donation Balance',
                      '${donationBalance.toStringAsFixed(0)} JOD',
                      Icons.account_balance,
                      AppColors.green,
                    );
                  default:
                    return Container();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyAssistanceTab() {
    final data = _familyAssistance;
    if (data == null) {
      return _buildNoDataView('Family Assistance');
    }

    final overview =
        Map<String, dynamic>.from(data['assistance_overview'] ?? {});
    final discounts =
        Map<String, dynamic>.from(overview['applied_discounts'] ?? {});

    double _toDouble(dynamic v) => (v ?? 0).toDouble();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // GridView بدون ارتفاع ثابت
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildDetailedMetricCard(
                      'Total Requests',
                      _toDouble(overview['total_requests']).toStringAsFixed(0),
                      Icons.family_restroom,
                      AppColors.red,
                    );
                  case 1:
                    return _buildDetailedMetricCard(
                      'Avg Requested Discount',
                      '${_toDouble(discounts['average_requested_discount']).toStringAsFixed(1)}%',
                      Icons.discount,
                      AppColors.warning,
                    );
                  case 2:
                    return _buildDetailedMetricCard(
                      'Avg Approved Discount',
                      '${_toDouble(discounts['average_approved_discount']).toStringAsFixed(1)}%',
                      Icons.verified,
                      AppColors.success,
                    );
                  case 3:
                    return _buildDetailedMetricCard(
                      'Total Approved Amount',
                      '${_toDouble(discounts['total_approved_amount']).toStringAsFixed(0)} JOD',
                      Icons.monetization_on,
                      AppColors.primary,
                    );
                  default:
                    return Container();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final report = _monthlyReport;
    if (report == null) {
      return _buildNoDataView('Overview');
    }

    final institution = Map<String, dynamic>.from(report['institution'] ?? {});
    final period = Map<String, dynamic>.from(report['period'] ?? {});
    final performance = Map<String, dynamic>.from(report['performance'] ?? {});

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // بطاقة المؤسسة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.ment.withOpacity(0.05),
                  ],
                ),
                border: Border.all(color: AppColors.accent1, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          institution['name']?.toString() ?? 'Institution',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Period: ${period['start'] ?? ''} - ${period['end'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // مؤشرات الأداء - بدون ارتفاع ثابت
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildDetailedMetricCard(
                      'Total Revenue',
                      '${(performance['total_revenue'] ?? 0).toDouble().toStringAsFixed(0)} JOD',
                      Icons.monetization_on,
                      AppColors.success,
                    );
                  case 1:
                    return _buildDetailedMetricCard(
                      'Net Revenue',
                      '${(performance['net_revenue'] ?? 0).toDouble().toStringAsFixed(0)} JOD',
                      Icons.show_chart,
                      AppColors.ment,
                    );
                  case 2:
                    return _buildDetailedMetricCard(
                      'Collection Rate',
                      '${(performance['collection_rate'] ?? 0).toDouble().toStringAsFixed(1)}%',
                      Icons.trending_up,
                      (performance['collection_rate'] ?? 0).toDouble() > 80
                          ? AppColors.success
                          : AppColors.warning,
                    );
                  case 3:
                    return _buildDetailedMetricCard(
                      'Session Utilization',
                      '${(performance['session_utilization'] ?? 0).toDouble().toStringAsFixed(1)}%',
                      Icons.calendar_today,
                      AppColors.primary,
                    );
                  default:
                    return Container();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

// نسخة بطاقة مفصلة (أكبر)
  Widget _buildDetailedMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent1, width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textLight,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class TabInfo {
  final String title;
  final IconData icon;
  final Color color;

  TabInfo({
    required this.title,
    required this.icon,
    required this.color,
  });
}