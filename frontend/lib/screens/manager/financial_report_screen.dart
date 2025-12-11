import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';

class FinancialReportScreen extends StatefulWidget {
  @override
  _FinancialReportScreenState createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  // Filters
  String _selectedPeriod = 'This Month';
  String _selectedReportType = 'Revenue';
  String? _selectedSpecialist;
  String? _selectedSessionType;

  // Chart Data
  int _touchedIndex = -1;
  bool _showAvg = false;

  // Sample Data (You'll replace with real API data)
  final List<Map<String, dynamic>> _outstandingInvoices = [
    {
      'invoice_number': 'INV-2024-001',
      'amount': 150.00,
      'due_date': '2024-01-15',
      'status': 'Overdue',
      'days_overdue': 20,
      'parent_name': 'Ahmed Ali',
    },
    {
      'invoice_number': 'INV-2024-002',
      'amount': 200.00,
      'due_date': '2024-01-20',
      'status': 'Pending',
      'days_overdue': 15,
      'parent_name': 'Sara Mohammed',
    },
    {
      'invoice_number': 'INV-2024-003',
      'amount': 120.00,
      'due_date': '2024-01-25',
      'status': 'Pending',
      'days_overdue': 10,
      'parent_name': 'Omar Hassan',
    },
  ];

  final List<Map<String, dynamic>> _topDonors = [
    {
      'name': 'ABC Company',
      'donation_count': 5,
      'total_amount': 5000.00,
      'last_donation': '2024-01-15',
    },
    {
      'name': 'Mohammed Ali',
      'donation_count': 3,
      'total_amount': 3000.00,
      'last_donation': '2024-01-10',
    },
    {
      'name': 'Al-Noor Foundation',
      'donation_count': 2,
      'total_amount': 2500.00,
      'last_donation': '2024-01-05',
    },
  ];

  final List<Map<String, dynamic>> _specialistPerformance = [
    {
      'name': 'Dr. Sarah Ahmed',
      'specialization': 'Speech Therapy',
      'salary': 1200.00,
      'session_count': 25,
      'revenue': 3000.00,
      'rating': 4.8,
    },
    {
      'name': 'Dr. Omar Khalid',
      'specialization': 'Occupational Therapy',
      'salary': 1300.00,
      'session_count': 22,
      'revenue': 2800.00,
      'rating': 4.6,
    },
    {
      'name': 'Dr. Layla Hassan',
      'specialization': 'Behavioral Therapy',
      'salary': 1150.00,
      'session_count': 20,
      'revenue': 2500.00,
      'rating': 4.9,
    },
  ];

  final List<MonthlyData> _monthlyData = [
    MonthlyData('Jan', 15000, 8000, 120, 10),
    MonthlyData('Feb', 16500, 8500, 132, 12),
    MonthlyData('Mar', 14200, 8200, 115, 8),
    MonthlyData('Apr', 17800, 9000, 140, 15),
    MonthlyData('May', 19200, 9500, 150, 18),
    MonthlyData('Jun', 21000, 10000, 165, 20),
  ];

  // Calculate totals
  double get _totalRevenue {
    return _monthlyData.fold(0.0, (sum, month) => sum + month.revenue);
  }

  double get _totalExpenses {
    return _monthlyData.fold(0.0, (sum, month) => sum + month.expenses);
  }

  double get _netProfit => _totalRevenue - _totalExpenses;

  double get _profitMargin => (_netProfit / _totalRevenue) * 100;

  double get _avgRevenue => _totalRevenue / _monthlyData.length;

  double get _avgExpenses => _totalExpenses / _monthlyData.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Financial Report',
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textWhite),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'Export Report',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters Section
            _buildFiltersSection(),
            SizedBox(height: 20),

            // Quick Overview Cards
            _buildOverviewCards(),
            SizedBox(height: 24),

            // Revenue Sources Pie Chart
            _buildRevenueSourcesChart(),
            SizedBox(height: 24),

            // Revenue & Expenses Line Chart
            _buildRevenueExpensesChart(),
            SizedBox(height: 24),

            // Outstanding Invoices Section
            _buildOutstandingInvoicesSection(),
            SizedBox(height: 24),

            // Specialist Performance Section
            _buildSpecialistPerformanceSection(),
            SizedBox(height: 24),

            // Top Donors Section
            _buildTopDonorsSection(),
            SizedBox(height: 24),

            // Summary Section
            _buildSummarySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Report Period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPeriodButton('Today', 'Today'),
              _buildPeriodButton('This Week', 'Week'),
              _buildPeriodButton('This Month', 'Month'),
              _buildPeriodButton('This Quarter', 'Quarter'),
              _buildPeriodButton('This Year', 'Year'),
              _buildPeriodButton('Custom', 'Custom'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = value;
        });
        _showSnackBar('Showing $label report');
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.accent2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.textWhite : AppColors.textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildKPICard(
          title: 'Total Revenue',
          value: '\$${_totalRevenue.toStringAsFixed(0)}',
          icon: Icons.trending_up,
          color: AppColors.success,
          change: '+12%',
          isPositive: true,
        ),
        _buildKPICard(
          title: 'Total Expenses',
          value: '\$${_totalExpenses.toStringAsFixed(0)}',
          icon: Icons.trending_down,
          color: AppColors.error,
          change: '+8%',
          isPositive: false,
        ),
        _buildKPICard(
          title: 'Net Profit',
          value: '\$${_netProfit.toStringAsFixed(0)}',
          icon: Icons.attach_money,
          color: AppColors.primary,
          change: '+15%',
          isPositive: true,
        ),
        _buildKPICard(
          title: 'Profit Margin',
          value: '${_profitMargin.toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: AppColors.info,
          change: '+3.5%',
          isPositive: true,
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String change,
    required bool isPositive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                    SizedBox(width: 2),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 10,
                        color: isPositive ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSourcesChart() {
    final sessionRevenue = _totalRevenue * 0.75; // 75% of total
    final donationRevenue = _totalRevenue * 0.25; // 25% of total

    final List<PieChartSectionData> pieChartSections = [
      PieChartSectionData(
        color: AppColors.primary,
        value: 75,
        radius: 60,
        title: '75%',
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
        ),
      ),
      PieChartSectionData(
        color: AppColors.info,
        value: 25,
        radius: 60,
        title: '25%',
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
        ),
      ),
    ];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Sources',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              IconButton(
                icon: Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                onPressed: () {
                  _showRevenueDetails(sessionRevenue, donationRevenue);
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: pieChartSections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRevenueSourceItem(
                      label: 'Session Payments',
                      amount: sessionRevenue,
                      percentage: 75,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 16),
                    _buildRevenueSourceItem(
                      label: 'Donations',
                      amount: donationRevenue,
                      percentage: 25,
                      color: AppColors.info,
                    ),
                    SizedBox(height: 16),
                    Divider(color: AppColors.accent2),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Revenue:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '\$${_totalRevenue.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSourceItem({
    required String label,
    required double amount,
    required int percentage,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    '\$${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.accent2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage / 100,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueExpensesChart() {
    // Find max value for Y axis
    double maxY = 0;
    for (var month in _monthlyData) {
      if (month.revenue > maxY) maxY = month.revenue;
      if (month.expenses > maxY) maxY = month.expenses;
    }
    maxY = (maxY * 1.2).ceilToDouble(); // Add 20% padding

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem('Revenue', AppColors.success),
                  SizedBox(width: 16),
                  _buildLegendItem('Expenses', AppColors.error),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: maxY / 5,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.accent2,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: AppColors.accent2,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _monthlyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _monthlyData[index].month,
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toInt()}',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: AppColors.accent2,
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: _monthlyData.length.toDouble() - 1,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Revenue Line
                  LineChartBarData(
                    spots: _monthlyData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.revenue);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.success,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.success.withOpacity(0.1),
                    ),
                  ),
                  // Expenses Line
                  LineChartBarData(
                    spots: _monthlyData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.expenses);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.error,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat(
                label: 'Avg Revenue',
                value: '\$${_avgRevenue.toStringAsFixed(0)}',
                color: AppColors.success,
              ),
              _buildMiniStat(
                label: 'Avg Expenses',
                value: '\$${_avgExpenses.toStringAsFixed(0)}',
                color: AppColors.error,
              ),
              _buildMiniStat(
                label: 'Growth Rate',
                value: '+${((_monthlyData.last.revenue - _monthlyData.first.revenue) / _monthlyData.first.revenue * 100).toStringAsFixed(1)}%',
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textGray,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textGray,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildOutstandingInvoicesSection() {
    final totalOutstanding = _outstandingInvoices.fold(0.0, (sum, invoice) => sum + invoice['amount']);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outstanding Invoices',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 14, color: AppColors.warning),
                    SizedBox(width: 6),
                    Text(
                      '\$${totalOutstanding.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ..._outstandingInvoices.map((invoice) {
            return _buildInvoiceItem(invoice);
          }).toList(),
          SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _viewAllInvoices,
              icon: Icon(Icons.arrow_forward, size: 16),
              label: Text('View All Invoices'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(Map<String, dynamic> invoice) {
    final statusColor = invoice['status'] == 'Overdue' ? AppColors.error : AppColors.warning;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              invoice['status'] == 'Overdue' ? Icons.warning : Icons.pending_actions,
              color: statusColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      invoice['invoice_number'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '\$${invoice['amount'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: AppColors.textGray),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        invoice['parent_name'],
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        invoice['status'],
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.calendar_today, size: 12, color: AppColors.textGray),
                    SizedBox(width: 4),
                    Text(
                      'Due: ${invoice['due_date']}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialistPerformanceSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Performing Specialists',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              IconButton(
                icon: Icon(Icons.sort, size: 20, color: AppColors.primary),
                onPressed: _sortSpecialists,
              ),
            ],
          ),
          SizedBox(height: 12),
          ..._specialistPerformance.map((specialist) {
            return _buildSpecialistItem(specialist);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSpecialistItem(Map<String, dynamic> specialist) {
    final revenue = specialist['revenue'] as double;
    final salary = specialist['salary'] as double;
    final netProfit = revenue - salary;
    final roi = (netProfit / salary) * 100;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            radius: 24,
            child: Text(
              specialist['name'].substring(0, 1),
              style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  specialist['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent1,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        specialist['specialization'],
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 12, color: AppColors.warning),
                        SizedBox(width: 2),
                        Text(
                          specialist['rating'].toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${revenue.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: roi > 100 ? AppColors.success.withOpacity(0.1) : AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${roi.toStringAsFixed(0)}% ROI',
                  style: TextStyle(
                    fontSize: 10,
                    color: roi > 100 ? AppColors.success : AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopDonorsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Donors This Month',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 12),
          ..._topDonors.asMap().entries.map((entry) {
            final index = entry.key;
            final donor = entry.value;
            return _buildDonorItem(index, donor);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDonorItem(int index, Map<String, dynamic> donor) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getDonorColor(index),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donor['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.history, size: 12, color: AppColors.textGray),
                    SizedBox(width: 4),
                    Text(
                      'Last: ${donor['last_donation']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textGray,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.receipt, size: 12, color: AppColors.textGray),
                    SizedBox(width: 4),
                    Text(
                      '${donor['donation_count']} donations',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${donor['total_amount'].toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getDonorColor(index),
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.favorite, size: 12, color: AppColors.error),
                  SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getDonorColor(int index) {
    switch (index) {
      case 0: return AppColors.success; // Gold for #1
      case 1: return AppColors.info;    // Silver for #2
      case 2: return AppColors.primary; // Bronze for #3
      default: return AppColors.textGray;
    }
  }

  Widget _buildSummarySection() {
    final lastMonth = _monthlyData.last;
    final totalSessions = _monthlyData.fold(0, (sum, month) => sum + month.sessionCount);
    final totalDonations = _monthlyData.fold(0, (sum, month) => sum + month.donationCount);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryMetric(
                label: 'Sessions Completed',
                value: '$totalSessions',
                icon: Icons.event_available,
                color: AppColors.success,
              ),
              SizedBox(width: 16),
              _buildSummaryMetric(
                label: 'Active Donors',
                value: '${_topDonors.length}',
                icon: Icons.group,
                color: AppColors.info,
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryMetric(
                label: 'Avg Session Price',
                value: '\$${(_totalRevenue / totalSessions).toStringAsFixed(0)}',
                icon: Icons.attach_money,
                color: AppColors.primary,
              ),
              SizedBox(width: 16),
              _buildSummaryMetric(
                label: 'Total Donations',
                value: '\$${(totalDonations * 100).toStringAsFixed(0)}',
                icon: Icons.favorite,
                color: AppColors.error,
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.insights, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Health',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Strong revenue growth with healthy profit margins',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'EXCELLENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Action Methods
  void _exportReport() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export Report',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.picture_as_pdf, color: AppColors.error),
                ),
                title: Text('PDF Document'),
                subtitle: Text('High quality report with charts'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('PDF report generated');
                },
              ),
              Divider(),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.grid_on, color: AppColors.success),
                ),
                title: Text('Excel Spreadsheet'),
                subtitle: Text('Raw data for analysis'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('Excel file exported');
                },
              ),
              Divider(),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image, color: AppColors.info),
                ),
                title: Text('Charts as Images'),
                subtitle: Text('PNG format for presentations'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('Charts saved as images');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _refreshData() {
    setState(() {
      _showSnackBar('Data refreshed successfully');
    });
  }

  void _viewAllInvoices() {
    _showSnackBar('Opening invoices dashboard...');
  }

  void _sortSpecialists() {
    setState(() {
      _specialistPerformance.sort((a, b) => b['revenue'].compareTo(a['revenue']));
    });
    _showSnackBar('Sorted by revenue (highest first)');
  }

  void _showRevenueDetails(double sessionRevenue, double donationRevenue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revenue Breakdown'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Revenue: \$${_totalRevenue.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow('Session Payments', '\$${sessionRevenue.toStringAsFixed(0)}', AppColors.primary),
            _buildDetailRow('Donations', '\$${donationRevenue.toStringAsFixed(0)}', AppColors.info),
            SizedBox(height: 16),
            Text(
              'Note: Revenue includes completed sessions and confirmed donations only.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGray,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(label),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class MonthlyData {
  final String month;
  final double revenue;
  final double expenses;
  final int sessionCount;
  final int donationCount;

  MonthlyData(this.month, this.revenue, this.expenses, this.sessionCount, this.donationCount);
}