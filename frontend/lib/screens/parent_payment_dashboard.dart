import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_models.dart';
import '../services/payment_service.dart';
import '../utils/app_colors.dart';
import 'payment_screen.dart';

class ParentPaymentDashboard extends StatefulWidget {
  const ParentPaymentDashboard({Key? key}) : super(key: key);

  @override
  State<ParentPaymentDashboard> createState() => _ParentPaymentDashboardState();
}

class _ParentPaymentDashboardState extends State<ParentPaymentDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Invoice> _allInvoices = [];
  List<Invoice> _pendingInvoices = [];
  List<Invoice> _paidInvoices = [];
  List<Invoice> _filteredInvoices = [];
  
  // Stats
  double _totalPending = 0.0;
  double _totalPaid = 0.0;
  int _pendingCount = 0;
  
  // New Features
  final TextEditingController _searchController = TextEditingController();
  String _selectedTimeFilter = 'all'; // all, week, month, year
  bool _showFilters = false;
  bool _showAnalytics = true;
  
  // Analytics
  double _avgPayment = 0.0;
  int _paymentsThisMonth = 0;
  double _totalThisMonth = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_filterInvoices);
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _filterInvoices() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty && _selectedTimeFilter == 'all') {
        _filteredInvoices = _allInvoices;
      } else {
        _filteredInvoices = _allInvoices.where((invoice) {
          final matchesSearch = invoice.invoiceNumber.toLowerCase().contains(query);
          final matchesTime = _matchesTimeFilter(invoice);
          return matchesSearch && matchesTime;
        }).toList();
      }
      _updateFilteredLists();
    });
  }
  
  bool _matchesTimeFilter(Invoice invoice) {
    if (_selectedTimeFilter == 'all') return true;
    
    final now = DateTime.now();
    final invoiceDate = invoice.issuedDate;
    
    switch (_selectedTimeFilter) {
      case 'week':
        return now.difference(invoiceDate).inDays <= 7;
      case 'month':
        return now.difference(invoiceDate).inDays <= 30;
      case 'year':
        return now.difference(invoiceDate).inDays <= 365;
      default:
        return true;
    }
  }
  
  void _updateFilteredLists() {
    _pendingInvoices = _filteredInvoices.where((i) => 
      i.status == 'Pending' || i.status == 'Overdue' || i.status == 'Draft'
    ).toList();
    _paidInvoices = _filteredInvoices.where((i) => i.status == 'Paid').toList();
    _pendingCount = _pendingInvoices.length;
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final invoices = await PaymentService.getParentInvoices(token);

      _allInvoices = invoices;
      _filteredInvoices = invoices;
      _pendingInvoices = invoices.where((i) => 
        i.status == 'Pending' || i.status == 'Overdue' || i.status == 'Draft'
      ).toList();
      _paidInvoices = invoices.where((i) => i.status == 'Paid').toList();

      // Calculate stats
      _totalPending = _pendingInvoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
      _totalPaid = _paidInvoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
      _pendingCount = _pendingInvoices.length;
      
      // Calculate analytics
      _calculateAnalytics();

    } catch (e) {
      print('❌ Error loading invoices: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الفواتير: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _calculateAnalytics() {
    // Average payment
    if (_paidInvoices.isNotEmpty) {
      _avgPayment = _totalPaid / _paidInvoices.length;
    }
    
    // Payments this month
    final now = DateTime.now();
    final thisMonthInvoices = _paidInvoices.where((inv) {
      return inv.paidDate != null &&
             inv.paidDate!.year == now.year &&
             inv.paidDate!.month == now.month;
    }).toList();
    
    _paymentsThisMonth = thisMonthInvoices.length;
    _totalThisMonth = thisMonthInvoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ParentAppColors.primaryTeal, ParentAppColors.mintGreen],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المدفوعات',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'إدارة الفواتير والدفعات',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadInvoices,
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('جاري تحميل البيانات...'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: CustomScrollView(
        slivers: [
          // Search Bar and Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSearchAndFilters(),
            ),
          ),
          
          // Stats Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatsCards(),
            ),
          ),
          
          // Analytics Cards
          if (_showAnalytics)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildAnalyticsCards(),
              ),
            ),

          // Quick Actions
          if (_pendingCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildQuickActions(),
              ),
            ),

          // Tabs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade100, Colors.grey.shade50],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: ParentAppColors.textGrey,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ParentAppColors.primaryTeal, ParentAppColors.mintGreen],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: ParentAppColors.primaryTeal.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pending_actions, size: 20),
                          const SizedBox(width: 8),
                          Text('معلق ($_pendingCount)'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 20),
                          const SizedBox(width: 8),
                          Text('مدفوع (${_paidInvoices.length})'),
                        ],
                      ),
                    ),
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list, size: 20),
                          SizedBox(width: 8),
                          Text('الكل'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvoicesList(_pendingInvoices, isPending: true),
                _buildInvoicesList(_paidInvoices, isPending: false),
                _buildInvoicesList(_allInvoices, isPending: null),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: ParentAppColors.primaryTeal.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ابحث برقم الفاتورة...',
              hintStyle: TextStyle(color: ParentAppColors.textGrey),
              prefixIcon: Icon(Icons.search, color: ParentAppColors.primaryTeal),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Quick Filters
        Row(
          children: [
            Expanded(
              child: _buildFilterChip(
                'الكل',
                'all',
                Icons.all_inclusive,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFilterChip(
                'أسبوع',
                'week',
                Icons.calendar_view_week,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFilterChip(
                'شهر',
                'month',
                Icons.calendar_month,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFilterChip(
                'سنة',
                'year',
                Icons.calendar_today,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Toggle Analytics Button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAnalytics = !_showAnalytics;
                });
              },
              icon: Icon(
                _showAnalytics ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label: Text(
                _showAnalytics ? 'إخفاء التحليلات' : 'عرض التحليلات',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: ParentAppColors.primaryTeal,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedTimeFilter == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeFilter = value;
          _filterInvoices();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [ParentAppColors.primaryTeal, ParentAppColors.mintGreen],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : ParentAppColors.primaryTeal.withOpacity(0.3),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ParentAppColors.primaryTeal.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : ParentAppColors.primaryTeal,
              size: 18,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : ParentAppColors.textDark,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnalyticsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: ParentAppColors.primaryTeal, size: 20),
            const SizedBox(width: 8),
            const Text(
              'تحليلات الدفع',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ParentAppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                title: 'متوسط الدفعة',
                value: '\$${_avgPayment.toStringAsFixed(2)}',
                icon: Icons.show_chart,
                gradient: [ParentAppColors.primaryBlue, ParentAppColors.secondaryLavender],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                title: 'دفعات الشهر',
                value: '$_paymentsThisMonth',
                subtitle: '\$${_totalThisMonth.toStringAsFixed(2)}',
                icon: Icons.calendar_month,
                gradient: [ParentAppColors.secondaryLavender, ParentAppColors.skyBlue],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'الفواتير المعلقة',
                value: '$_pendingCount',
                subtitle: '\$${_totalPending.toStringAsFixed(2)}',
                icon: Icons.pending_actions,
                gradient: [ParentAppColors.warningOrange, ParentAppColors.accentOrange],
                iconColor: ParentAppColors.softYellow.withOpacity(0.3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'المدفوع',
                value: '${_paidInvoices.length}',
                subtitle: '\$${_totalPaid.toStringAsFixed(2)}',
                icon: Icons.check_circle,
                gradient: [ParentAppColors.successGreen, ParentAppColors.mintGreen],
                iconColor: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTotalCard(),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    final total = _totalPending + _totalPaid;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ParentAppColors.primaryTeal, ParentAppColors.primaryBlue],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ParentAppColors.primaryTeal.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إجمالي المدفوعات',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ParentAppColors.accentCoral.withOpacity(0.1), ParentAppColors.softYellow.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParentAppColors.accentCoral.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ParentAppColors.accentCoral.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ParentAppColors.accentCoral.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.notifications_active, color: ParentAppColors.accentCoral, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه!',
                  style: TextStyle(
                    color: ParentAppColors.accentCoral,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'لديك $_pendingCount فاتورة معلقة',
                  style: const TextStyle(
                    color: ParentAppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _tabController.animateTo(0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ParentAppColors.accentCoral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ادفع الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList(List<Invoice> invoices, {bool? isPending}) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending == true ? Icons.check_circle : Icons.receipt_long,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isPending == true ? 'لا توجد فواتير معلقة' : 'لا توجد فواتير',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return _buildInvoiceCard(invoice);
      },
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final isPending = invoice.status == 'Pending' || 
                      invoice.status == 'Overdue' || 
                      invoice.status == 'Draft';
    
    final statusColor = isPending ? ParentAppColors.warningOrange : ParentAppColors.successGreen;
    final bgColor = isPending ? ParentAppColors.warningOrange.withOpacity(0.08) : ParentAppColors.successGreen.withOpacity(0.08);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgColor, statusColor.withOpacity(0.15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Icon(
            isPending ? Icons.hourglass_empty : Icons.check_circle,
            color: statusColor,
            size: 28,
          ),
        ),
        title: Text(
          invoice.invoiceNumber,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatDate(invoice.issuedDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(invoice.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getStatusText(invoice.status),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(invoice.status),
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${invoice.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            if (isPending) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ParentAppColors.accentCoral, ParentAppColors.warningOrange],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: ParentAppColors.accentCoral.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => _navigateToPayment(invoice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0,
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payment, size: 14),
                      SizedBox(width: 4),
                      Text('ادفع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToPayment(Invoice invoice) {
    // TODO: Navigate to payment screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('سيتم فتح صفحة الدفع للفاتورة ${invoice.invoiceNumber}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'مدفوع';
      case 'pending':
        return 'معلق';
      case 'overdue':
        return 'متأخر';
      case 'draft':
        return 'مسودة';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
