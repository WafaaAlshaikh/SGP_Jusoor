import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/session.dart';
import '../models/payment_models.dart';
import '../theme/app_colors.dart';
import 'book_session_screen.dart';
import '../widgets/session_details_sheet.dart';
import '../widgets/rate_session_dialog.dart';
import '../widgets/reschedule_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/payment_service.dart';
import 'payment_screen.dart';
import '../services/parent_api.dart';
import '../services/rating_service.dart'; // ← إضافة الاستيراد


class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Session> _upcomingSessions = [];
  List<Session> _completedSessions = [];
  List<Session> _pendingSessions = [];
  List<Session> _cancelledSessions = [];

  // Filtered lists
  List<Session> _filteredUpcoming = [];
  List<Session> _filteredCompleted = [];
  List<Session> _filteredPending = [];
  List<Session> _filteredCancelled = [];

  String _searchQuery = '';
  String _selectedInstitution = 'All';
  String _selectedType = 'All';

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  final List<Tab> _tabs = [
    const Tab(text: 'Upcoming'),
    const Tab(text: 'Completed'),
    const Tab(text: 'Pending'),
    const Tab(text: 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadAllSessions();
  }

  Future<void> _handleParentSessionDecision({
    required String sessionId,
    required String decision,
    double? requestedPercentage,
    double? requestedAmount,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('No token');

      final resp = await ApiService.submitSessionDecision(
        token,
        sessionId,
        decision: decision,
        requestedPercentage: requestedPercentage,
        requestedAmount: requestedAmount,
        notes: notes,
      );

      if (resp['success'] == true) {
        final msg = resp['message']?.toString() ?? 'Done';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.success),
        );
        _loadAllSessions();
      } else {
        throw Exception(resp['message'] ?? 'Failed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadAllSessions() async {
  try {
    setState(() => _isRefreshing = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      throw Exception('Token not found');
    }

    // جلب الجلسات
    final results = await Future.wait([
      ApiService.getUpcomingSessions(token),
      ApiService.getCompletedSessions(token),
      ApiService.getPendingSessions(token),
      ApiService.getCancelledSessions(token),
    ]);

    setState(() {
      _upcomingSessions = results[0];
      _completedSessions = results[1];
      _pendingSessions = results[2];
      _cancelledSessions = results[3];
    });

    // 🔄 NEW: للجلسات Pending Approval، التحقق من المساعدة المالية
    for (final session in _pendingSessions) {
      if (session.status == 'Pending Approval') {
        try {
          final financialCheck = await ApiService.checkAutoFinancialAssistance(
            token, 
            session.sessionId
          );
          
          if (financialCheck['success'] == true && 
              financialCheck['discount_analysis'] != null) {
            final analysis = financialCheck['discount_analysis'];
            session.isEligibleForAutoDiscount = analysis['eligible_for_auto_discount'] ?? false;
            session.autoDiscountPercentage = analysis['discount_percentage']?.toDouble() ?? 0;
            session.autoDiscountAmount = analysis['discount_amount']?.toDouble() ?? 0;
            session.financialAssessment = financialCheck['financial_assessment'];
          }
        } catch (e) {
          print('Failed to check financial assistance for session ${session.sessionId}: $e');
        }
      }
    }

    _applyFilters();

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });

  } catch (e) {
    setState(() {
      _errorMessage = 'Failed to load sessions: ${e.toString()}';
      _isLoading = false;
      _isRefreshing = false;
    });
  }
}

  void _applyFilters() {
    setState(() {
      _filteredUpcoming = _filterSessions(_upcomingSessions);
      _filteredCompleted = _filterSessions(_completedSessions);
      _filteredPending = _filterSessions(_pendingSessions);
      _filteredCancelled = _filterSessions(_cancelledSessions);
    });
  }

  List<Session> _filterSessions(List<Session> sessions) {
    return sessions.where((session) {
      final matchesSearch = _searchQuery.isEmpty ||
          session.childName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          session.specialistName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          session.institutionName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          session.sessionType.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesInstitution = _selectedInstitution == 'All' ||
          session.institutionName == _selectedInstitution;

      final matchesType = _selectedType == 'All' ||
          session.sessionType == _selectedType;

      return matchesSearch && matchesInstitution && matchesType;
    }).toList();
  }


  void _rateSession(Session session) {
  if (!session.canRate) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('This session cannot be rated'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (context) => RateSessionDialog(
      session: session,
      onRated: () {
        _loadAllSessions(); // ← تحديث القائمة
        _onSessionRated();
      },
    ),
  );
}

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onSessionRated() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your rating!'),
        backgroundColor: AppColors.success,
      ),
    );
    _loadAllSessions();
  }

  void _onInstitutionFilterChanged(String? institution) {
    setState(() {
      _selectedInstitution = institution ?? 'All';
      _applyFilters();
    });
  }

  void _onTypeFilterChanged(String? type) {
    setState(() {
      _selectedType = type ?? 'All';
      _applyFilters();
    });
  }

  void _showSessionDetails(Session session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SessionDetailsBottomSheet(
        session: session,
        onRateSession: () => _rateSession(session),
        onReschedule: () => _rescheduleSession(session),
        onSetReminder: () => _scheduleReminder(session),
        onShareSession: () => _shareSession(session),
      ),
    );
  }

  void _navigateToBookSession() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BookSessionScreen()),
    ).then((_) => _loadAllSessions());
  }


  void _rescheduleSession(Session session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => RescheduleBottomSheet(
        session: session,
        onRescheduled: _loadAllSessions,
      ),
    );
  }

  Future<void> _scheduleReminder(Session session) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminder scheduled for 1 hour before session'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _shareSession(Session session) {
    final shareText = '''
Therapy Session - ${session.childName}

Child: ${session.childName}
Specialist: ${session.specialistName}  
Institution: ${session.institutionName}
Date: ${session.date}
Time: ${session.time}
Duration: ${session.duration} minutes
Session Type: ${session.sessionType}
Location: ${session.sessionLocation}
''';

    Share.share(shareText);
  }

  void _downloadInvoice(Session session) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating invoice...'),
          backgroundColor: Colors.blue,
        ),
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'Therapy Session Invoice',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Session Information',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        _buildInvoiceRow('Child:', session.childName),
                        _buildInvoiceRow('Specialist:', session.specialistName),
                        _buildInvoiceRow('Institution:', session.institutionName),
                        _buildInvoiceRow('Session Type:', session.sessionType),
                        _buildInvoiceRow('Date:', session.date),
                        _buildInvoiceRow('Time:', session.time),
                        _buildInvoiceRow('Duration:', '${session.duration} minutes'),
                        _buildInvoiceRow('Location:', session.sessionLocation),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 20),

                  if (session.sessionTypePrice > 0) ...[
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Payment Information',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _buildInvoiceRow('Session Price:', '\$${session.sessionTypePrice.toStringAsFixed(2)}'),
                          _buildInvoiceRow('Discount:', '\$0.00'),
                          _buildInvoiceRow('Tax:', '\$${(session.sessionTypePrice * 0.16).toStringAsFixed(2)}'),
                          pw.Divider(),
                          _buildInvoiceRow(
                            'Total Amount:',
                            '\$${(session.sessionTypePrice * 1.16).toStringAsFixed(2)}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ],

                  pw.SizedBox(height: 20),

                  pw.Center(
                    child: pw.Text(
                      'Thank you for your trust',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoice_${session.sessionId}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invoice saved successfully'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Open File',
              onPressed: () async {
                await Share.shareXFiles([XFile(file.path)]);
              },
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create invoice: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  pw.Widget _buildInvoiceRow(String label, String value, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPayment(Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final invoices = await PaymentService.getParentInvoices(token);

      Invoice? sessionInvoice;
      try {
        sessionInvoice = invoices.firstWhere(
              (invoice) => invoice.sessionId == int.tryParse(session.sessionId),
        );
      } catch (e) {
        try {
          sessionInvoice = invoices.firstWhere(
                (invoice) => invoice.sessionId.toString() == session.sessionId,
          );
        } catch (e2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No invoice found for this session'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            invoice: sessionInvoice!,
            session: session,
          ),
        ),
      ).then((_) {
        _loadAllSessions();
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Sessions',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: _tabs,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToBookSession,
            tooltip: 'Book New Session',
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _loadAllSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllSessions,
              color: AppColors.primary,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSessionsList(_filteredUpcoming, 'upcoming'),
                  _buildSessionsList(_filteredCompleted, 'completed'),
                  _buildSessionsList(_filteredPending, 'pending'),
                  _buildSessionsList(_filteredCancelled, 'cancelled'),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToBookSession,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final institutions = _getUniqueInstitutions();
    final sessionTypes = _getUniqueSessionTypes();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search sessions...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedInstitution,
                  isExpanded: true, // 
                  items: ['All', ...institutions].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        overflow: TextOverflow.ellipsis, // 
                      ),
                    );
                  }).toList(),
                  onChanged: _onInstitutionFilterChanged,
                  decoration: InputDecoration(
                    labelText: 'Institution',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  isExpanded: true, // 
                  items: ['All', ...sessionTypes].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        overflow: TextOverflow.ellipsis, // 
                      ),
                    );
                  }).toList(),
                  onChanged: _onTypeFilterChanged,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _getUniqueInstitutions() {
    final allSessions = [
      ..._upcomingSessions,
      ..._completedSessions,
      ..._pendingSessions,
      ..._cancelledSessions,
    ];
    return allSessions.map((s) => s.institutionName).toSet().toList();
  }

  List<String> _getUniqueSessionTypes() {
    final allSessions = [
      ..._upcomingSessions,
      ..._completedSessions,
      ..._pendingSessions,
      ..._cancelledSessions,
    ];
    return allSessions.map((s) => s.sessionType).toSet().toList();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading Sessions...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    final Map<String, Map<String, dynamic>> emptyStates = {
      'upcoming': {
        'icon': Icons.schedule,
        'title': 'No Upcoming Sessions',
        'message': 'You don\'t have any scheduled sessions yet.',
      },
      'completed': {
        'icon': Icons.check_circle,
        'title': 'No Completed Sessions',
        'message': 'Your completed sessions will appear here.',
      },
      'pending': {
        'icon': Icons.pending,
        'title': 'No Pending Sessions',
        'message': 'You don\'t have any pending session requests.',
      },
      'cancelled': {
        'icon': Icons.cancel,
        'title': 'No Cancelled Sessions',
        'message': 'No sessions have been cancelled.',
      },
    };

    final state = emptyStates[type] ?? emptyStates['upcoming']!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(state['icon'] as IconData, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              state['title'] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state['message'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllSessions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList(List<Session> sessions, String type) {
    if (sessions.isEmpty) {
      return _buildEmptyState(type);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _buildSessionCard(session, type);
      },
    );
  }

  Widget _buildSessionCard(Session session, String type) {
    final bool showRateButton = type == 'completed' && session.canRate;
    final bool isPaid = session.isPaid ?? false;
    final bool canCancel = type == 'upcoming' && session.status == 'Scheduled';
    final bool showPayButton =
        type == 'upcoming' && !isPaid && session.status == 'Scheduled';

    return GestureDetector(
      onTap: () => _showSessionDetails(session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status and quick actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient:
                          LinearGradient(colors: _getStatusGradient(session.displayStatus)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      session.displayStatus.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // Quick action buttons
                  Row(
                    children: [
                      if (showRateButton)
                        IconButton(
                          onPressed: () => _rateSession(session),
                          icon: Icon(Icons.star_outline_rounded,
                              color: AppColors.primary),
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Rate Session',
                        ),
                      IconButton(
                        onPressed: () => _showSessionDetails(session),
                        icon: Icon(Icons.more_horiz_rounded,
                            color: AppColors.textLight),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Main session info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Child avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.child_care_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Session details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.childName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'with ${session.specialistName}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        Text(
                          session.institutionName,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Session metadata in a clean grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetadataItem(
                      Icons.calendar_today_rounded,
                      session.date,
                      'Date',
                    ),
                    _buildMetadataItem(
                      Icons.access_time_rounded,
                      session.time,
                      'Time',
                    ),
                    _buildMetadataItem(
                      Icons.timer_rounded,
                      '${session.duration} min',
                      'Duration',
                    ),
                    _buildMetadataItem(
                      Icons.category_rounded,
                      session.sessionType,
                      'Type',
                    ),
                  ],
                ),
              ),

              // Rating for completed sessions
              if (type == 'completed' && session.rating != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your session rating',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                return Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: index < session.rating!.floor()
                                      ? Colors.amber
                                      : Colors.grey[300],
                                );
                              }),
                              const SizedBox(width: 8),
                              Text(
                                session.rating!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (session.ratingComment != null &&
                          session.ratingComment!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            session.ratingComment!,
                            style: TextStyle(
                              color: AppColors.textGray,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Action buttons - only show critical actions
              if (showPayButton || canCancel ||
                  session.status == 'Pending Approval' ||
                  session.status == 'Pending Parent Confirmation') ...[
                const SizedBox(height: 16),
                _buildActionButtons(
                  showPayButton: showPayButton,
                  canCancel: canCancel,
                  session: session,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
  required bool showPayButton,
  required bool canCancel,
  required Session session,
}) {
    final bool needsParentApproval = session.status == 'Pending Approval';
    final bool needsAutoConfirmation = session.status == 'Pending Parent Confirmation';
    final bool isAutoDiscountEligible = session.isEligibleForAutoDiscount == true;

    // 🔄 حالة: الجلسة تحتاج موافقة الأهل وعليها خصم تلقائي متاح
    if (needsParentApproval && isAutoDiscountEligible) {
      return _buildAutoDiscountActionCard(session);
    }

    // حالة: الجلسة تحتاج موافقة الأهل (بدون خصم تلقائي)
    if (needsParentApproval) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Action required',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'This session needs your approval',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleParentSessionDecision(
                      sessionId: session.sessionId,
                      decision: 'reject',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleParentSessionDecision(
                      sessionId: session.sessionId,
                      decision: 'approve',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // حالة: الجلسة تحتاج تأكيد تلقائي (Initial Assessment)
    if (needsAutoConfirmation) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Confirm initial assessment',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'This session was scheduled automatically. Please confirm before payment.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('token') ?? '';

                        if (token.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Session error: missing token'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        final response = await ApiService.confirmAutoSession(
                          token,
                          session.sessionId.toString(),
                        );

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                response['message'] ?? 'Session confirmed successfully'),
                            backgroundColor: AppColors.success,
                          ),
                        );

                        // إذا كان الدعم المالي قد انتهى، اعرض خيار طلب دعم إضافي
                        final fa = response['financial_assistance'];
                        if (fa is Map<String, dynamic> &&
                            fa['support_exhausted'] == true) {
                          final bool? shouldRequest = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Financial support exhausted'),
                                content: const Text(
                                    'You have used all supported sessions for this institution. Would you like to submit a new financial assistance request?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Later'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Request additional support'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (shouldRequest == true) {
                            final childId = fa['child_id'];
                            final institutionId = fa['institution_id'];

                            if (childId is int && institutionId is int) {
                              try {
                                final result = await ApiService.requestFinancialAssistance(
                                  token,
                                  childId: childId,
                                  institutionId: institutionId,
                                );

                                if (!mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result['message'] ??
                                          'Financial assistance request submitted successfully',
                                    ),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to submit financial assistance request: ${e.toString()}',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            } else {
                              // في حال لم تتوفر المعرفات لأي سبب
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Unable to determine child or institution for the financial request'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        }

                        _loadAllSessions();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to confirm session: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  // حالة افتراضية: أزرار الدفع والإلغاء
  return Row(
    children: [
      if (showPayButton)
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _navigateToPayment(session),
                child: Center(
                  child: FittedBox( // ⬅️ ADDED FittedBox
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Pay now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

      if (showPayButton && canCancel) const SizedBox(width: 12),

      if (canCancel)
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _cancelSession(session),
                child: Center(
                  child: FittedBox( // ⬅️ ADDED FittedBox
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cancel_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

// 🔄 الوظيفة الجديدة: بناء بطاقة الخصم التلقائي
Widget _buildAutoDiscountActionCard(Session session) {
  final originalPrice = session.price;
  final discountAmount = session.autoDiscountAmount ?? 0;
  final finalPrice = originalPrice - discountAmount;
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.green.withOpacity(0.1),
          Colors.teal.withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.green.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Expanded( // ⬅️ ADDED Expanded here
              child: Text(
                'Automatic Discount Available',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Based on your financial situation, you qualify for a ${session.autoDiscountPercentage}% discount on this session.',
          style: const TextStyle(fontSize: 14),
        ),
        if (session.autoDiscountReason != null) ...[
          const SizedBox(height: 4),
          Text(
            session.autoDiscountReason!,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // 🔄 MODIFIED: استخدم Column بدلاً من Row للأسعار
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original Price
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original Price',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${originalPrice.toStringAsFixed(2)} JOD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Final Price
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'After Discount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '${finalPrice.toStringAsFixed(2)} JOD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 🔄 MODIFIED: أزرار متجاوبة
        Column(
          children: [
            // الصف الأول من الأزرار
            Row(
              children: [
                Expanded(
                  child: SizedBox( // ⬅️ استخدام SizedBox لتحديد حجم ثابت
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => _handleParentSessionDecision(
                        sessionId: session.sessionId,
                        decision: 'reject',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const FittedBox( // ⬅️ استخدام FittedBox
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel_outlined, size: 18),
                            SizedBox(width: 4),
                            Text('Reject'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _handleParentSessionDecision(
                        sessionId: session.sessionId,
                        decision: 'approve',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Approve'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // الصف الثالث: الروابط
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _showFinancialAssessmentDetails(session),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'View Financial Assessment',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
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

// عرض تفاصيل التقييم المالي
void _showFinancialAssessmentDetails(Session session) {
  if (session.financialAssessment == null) return;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Financial Assessment'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (session.financialAssessment!['has_assessment'] == true) ...[
              _buildAssessmentRow('Financial Score', 
                  '${session.financialAssessment!['financial_score']}'),
              _buildAssessmentRow('Financial Tier', 
                  session.financialAssessment!['tier_label'] ?? ''),
              _buildAssessmentRow('Suggested Discount', 
                  '${session.autoDiscountPercentage}%'),
              const Divider(),
              _buildAssessmentRow('Last Assessment', 
                  _formatDate(session.financialAssessment!['last_assessment'])),
              _buildAssessmentRow('Assessment Valid', 
                  (session.financialAssessment!['assessment_valid'] == true) 
                      ? 'Yes' : 'No'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Your financial situation qualifies you for automatic discount on therapy sessions.',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontSize: 13,
                  ),
                ),
              ),
            ] else
              const Text('No financial assessment available'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // يمكن إضافة ربط لصفحة التقييم المالي هنا
            // Navigator.push(context, MaterialPageRoute(builder: (context) => FinancialAssessmentScreen()));
          },
          child: const Text('Update Assessment'),
        ),
      ],
    ),
  );
}

Widget _buildAssessmentRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}

String _formatDate(dynamic date) {
  if (date == null) return 'N/A';
  try {
    return DateTime.parse(date.toString()).toLocal().toString().split(' ')[0];
  } catch (e) {
    return date.toString();
  }
}

  List<Color> _getStatusGradient(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
      case 'scheduled':
        return [AppColors.primary, AppColors.primaryLight];
      case 'completed':
        return [AppColors.success, Color(0xFF27AE60)];
      case 'pending':
      case 'pending approval':
        return [AppColors.warning, Color(0xFFF39C12)];
      case 'cancelled':
        return [AppColors.error, Color(0xFFE74C3C)];
      default:
        return [Colors.grey, Colors.grey];
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSessionDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(double rating) {
    return Row(
      children: [
        const Text('Rating: '),
        ...List.generate(5, (index) {
          return Icon(
            Icons.star,
            size: 16,
            color: index < rating.floor() ? Colors.amber : Colors.grey,
          );
        }),
        Text(' ($rating)'),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  void _confirmSession(Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final success = await ApiService.confirmSession(token, session.sessionId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session confirmed successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadAllSessions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm session: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _cancelSession(Session session) async {
    String? cancellationReason;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this session?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) {
                cancellationReason = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performCancelSession(session, cancellationReason);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancelSession(Session session, String? reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final result = await ApiService.cancelSession(token, session.sessionId, reason: reason);

      if (result['success'] == true) {
        String message = result['message'] ?? 'Session cancelled successfully';

        if (result['refundProcessed'] == true) {
          final refundAmount = result['refundAmount'] ?? 0;
          message += '\nRefund of ${refundAmount} JOD has been processed.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
        _loadAllSessions();
      } else {
        throw Exception(result['message'] ?? 'Failed to cancel session');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel session: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleParentApproval(int sessionId, bool approve) async {
    try {
      final response = await ParentService.approveNewSession(sessionId, approve);
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? 'Session approved successfully'
                : 'Session rejected successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadAllSessions();
      } else {
        throw Exception(response['message'] ?? 'Failed to process approval');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process request: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}