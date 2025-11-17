// lib/screens/sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/session.dart';
import '../models/payment_models.dart';
import '../utils/app_colors.dart';
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
import 'parent_approve_sessions_screen.dart';

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

  // للبحث والتصفية
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

  // نظام الألوان المتناسق مع التطبيق
  final Color _primaryColor = const Color(0xFF7815A0);
  final Color _secondaryColor = const Color(0xFF976EF4);
  final Color _accentColor = const Color(0xFFCAA9F8);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;
  final Color _textPrimary = const Color(0xFF212529);
  final Color _textSecondary = const Color(0xFF6C757D);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _warningColor = const Color(0xFFFF9800);
  final Color _errorColor = const Color(0xFFF44336);

  final List<Tab> _tabs = [
    const Tab(text: 'Upcoming', icon: Icon(Icons.schedule)),
    const Tab(text: 'Completed', icon: Icon(Icons.check_circle)),
    const Tab(text: 'Pending', icon: Icon(Icons.pending)),
    const Tab(text: 'Cancelled', icon: Icon(Icons.cancel)),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadAllSessions();
  }

  Future<void> _loadAllSessions() async {
    try {
      setState(() => _isRefreshing = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('Token not found');
      }

      print('🔐 Loading sessions...');

      // جلب كل نوع من الجلسات من endpoint منفصل
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

      print('✅ Loaded sessions - Upcoming: ${_upcomingSessions.length}, Completed: ${_completedSessions.length}, Pending: ${_pendingSessions.length}, Cancelled: ${_cancelledSessions.length}');

      _applyFilters();

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

    } catch (e) {
      print('❌ Error loading sessions: $e');
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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onSessionRated() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Thank you for your rating! 🌟'),
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        onRateSession: () {
          _rateSession(session);
        },
        onReschedule: () => _rescheduleSession(session),
        onSetReminder: () => _scheduleReminder(session),
        onShareSession: () => _shareSession(session),
      ),
    );
  }

  void _rateSession(Session session) {
    showDialog(
      context: context,
      builder: (context) => RateSessionDialog(
        session: session,
        onRated: () {
          _loadAllSessions();
          _onSessionRated();
        },
      ),
    );
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
      SnackBar(
        content: const Text('Reminder scheduled for 1 hour before session'),
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareSession(Session session) {
    final shareText = '''
🎯 **جلسة علاجية - ${session.childName}**

👦 **الطفل:** ${session.childName}
👨‍⚕️ **الأخصائي:** ${session.specialistName}  
🏥 **المؤسسة:** ${session.institutionName}
📅 **التاريخ:** ${session.date}
⏰ **الوقت:** ${session.time}
⏳ **المدة:** ${session.duration} دقيقة
🎯 **نوع الجلسة:** ${session.sessionType}
📍 **المكان:** ${session.sessionLocation}

${session.displayStatus == 'completed' ? '✅ تم الانتهاء من الجلسة' :
    session.displayStatus == 'upcoming' ? '⏳ جلسة قادمة' :
    '📋 جلسة قيد الانتظار'}
''';

    Share.share(shareText, subject: 'معلومات الجلسة - ${session.childName}');
  }

  void _downloadInvoice(Session session) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📄 جاري إنشاء الفاتورة...'),
          backgroundColor: Colors.blue,
        ),
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        'فاتورة جلسة علاجية',
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
                            'معلومات الجلسة',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _buildInvoiceRow('الطفل:', session.childName),
                          _buildInvoiceRow('الأخصائي:', session.specialistName),
                          _buildInvoiceRow('المؤسسة:', session.institutionName),
                          _buildInvoiceRow('نوع الجلسة:', session.sessionType),
                          _buildInvoiceRow('التاريخ:', session.date),
                          _buildInvoiceRow('الوقت:', session.time),
                          _buildInvoiceRow('المدة:', '${session.duration} دقيقة'),
                          _buildInvoiceRow('المكان:', session.sessionLocation),
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
                              'معلومات الدفع',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 10),
                            _buildInvoiceRow('سعر الجلسة:', '\$${session.sessionTypePrice.toStringAsFixed(2)}'),
                            _buildInvoiceRow('الخصم:', '\$0.00'),
                            _buildInvoiceRow('الضريبة:', '\$${(session.sessionTypePrice * 0.16).toStringAsFixed(2)}'),
                            pw.Divider(),
                            _buildInvoiceRow(
                              'المبلغ الإجمالي:',
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
                        'شكراً لثقتكم بنا 🌟',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ),
                  ],
                ),
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
            content: const Text('✅ تم حفظ الفاتورة بنجاح'),
            backgroundColor: _successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'فتح الملف',
              onPressed: () async {
                await Share.shareXFiles([XFile(file.path)]);
              },
            ),
          ),
        );
      }

    } catch (e) {
      print('❌ Error creating invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل في إنشاء الفاتورة: ${e.toString()}'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

      print('🔍 Looking for invoice for session: ${session.sessionId}');

      final invoices = await PaymentService.getParentInvoices(token);
      print('📊 Found ${invoices.length} invoices');

      Invoice? sessionInvoice;
      try {
        sessionInvoice = invoices.firstWhere(
              (invoice) => invoice.sessionId == int.tryParse(session.sessionId),
        );
        print('✅ Found invoice: ${sessionInvoice.invoiceNumber}');
      } catch (e) {
        print('❌ No invoice found for session ${session.sessionId}');
        print('💡 Available sessions in invoices: ${invoices.map((i) => i.sessionId).toList()}');

        try {
          sessionInvoice = invoices.firstWhere(
                (invoice) => invoice.sessionId.toString() == session.sessionId,
          );
          print('✅ Found invoice using string comparison: ${sessionInvoice!.invoiceNumber}');
        } catch (e2) {
          print('❌ Also failed with string comparison');
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
      print('❌ Payment navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToParentApproveSessions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ParentApproveSessionsScreen(),
      ),
    ).then((_) {
      // بعد الرجوع من شاشة الموافقة، نعيد تحميل الجلسات
      _loadAllSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Sessions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
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
              width: 20,
              height: 20,
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
              color: _primaryColor,
              backgroundColor: _surfaceColor,
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
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final institutions = _getUniqueInstitutions();
    final sessionTypes = _getUniqueSessionTypes();

    return Container(
      color: _surfaceColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by child, specialist, institution...',
              hintStyle: TextStyle(color: _textSecondary),
              prefixIcon: Icon(Icons.search, color: _textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _textSecondary.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              filled: true,
              fillColor: _backgroundColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedInstitution,
                  items: ['All', ...institutions].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: _onInstitutionFilterChanged,
                  decoration: InputDecoration(
                    labelText: 'Institution',
                    labelStyle: TextStyle(color: _textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _textSecondary.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: _backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: ['All', ...sessionTypes].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: _onTypeFilterChanged,
                  decoration: InputDecoration(
                    labelText: 'Session Type',
                    labelStyle: TextStyle(color: _textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _textSecondary.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: _backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    return allSessions.map((s) => s.institutionName).toSet().toList().cast<String>();
  }

  List<String> _getUniqueSessionTypes() {
    final allSessions = [
      ..._upcomingSessions,
      ..._completedSessions,
      ..._pendingSessions,
      ..._cancelledSessions,
    ];
    return allSessions.map((s) => s.sessionType).toSet().toList().cast<String>();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(color: _primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Sessions...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 48, color: _errorColor),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllSessions,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(List<Session> sessions, String type) {
    if (sessions.isEmpty) {
      return _buildEmptyState(type);
    }

    if (type == 'pending') {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _navigateToParentApproveSessions,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Review specialist sessions waiting approval'),
              ),
            );
          }
          final session = sessions[index - 1];
          return _buildSessionCard(session, type);
        },
      );
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

  Widget _buildEmptyState(String type) {
    final Map<String, dynamic> emptyStates = {
      'upcoming': {
        'icon': Icons.schedule,
        'title': 'No Upcoming Sessions',
        'message': 'You don\'t have any scheduled sessions yet.',
        'action': 'Book a Session'
      },
      'completed': {
        'icon': Icons.check_circle,
        'title': 'No Completed Sessions',
        'message': 'Your completed sessions will appear here.',
        'action': 'View Upcoming'
      },
      'pending': {
        'icon': Icons.pending,
        'title': 'No Pending Sessions',
        'message': 'You don\'t have any pending session requests.',
        'action': 'Book a Session'
      },
      'cancelled': {
        'icon': Icons.cancel,
        'title': 'No Cancelled Sessions',
        'message': 'No sessions have been cancelled.',
        'action': 'View Upcoming'
      },
    };

    final state = emptyStates[type]!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                state['icon'] as IconData,
                size: 48,
                color: _textSecondary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state['title'] as String,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state['message'] as String,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (type == 'upcoming')
              ElevatedButton(
                onPressed: _navigateToBookSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(state['action'] as String),
              )
            else if (type == 'pending') ...[
              ElevatedButton(
                onPressed: _navigateToBookSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(state['action'] as String),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _navigateToParentApproveSessions,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Review specialist sessions waiting approval'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Session session, String type) {
    final bool isPaid = session.isPaid ?? false;
    final bool canCancel = type == 'upcoming' && session.status == 'Scheduled';
    final bool showPayButton = type == 'upcoming' && !isPaid && session.status == 'Scheduled';

    return GestureDetector(
      onTap: () => _showSessionDetails(session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status and actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusChip(session.displayStatus),
                    if (isPaid)
                      _buildPaymentChip('Paid', Colors.green)
                    else
                      _buildPaymentChip('Pending Payment', Colors.orange),
                  ],
                ),

                const SizedBox(height: 16),

                // Session details
                _buildSessionDetailRow(
                  icon: Icons.child_care,
                  title: 'Child',
                  value: session.childName,
                ),
                _buildSessionDetailRow(
                  icon: Icons.person,
                  title: 'Specialist',
                  value: session.specialistName,
                ),
                _buildSessionDetailRow(
                  icon: Icons.local_hospital,
                  title: 'Institution',
                  value: session.institutionName,
                ),

                const SizedBox(height: 12),

                // Date, Time, and Duration
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDetailChip(Icons.calendar_today, session.date),
                    _buildDetailChip(Icons.access_time, session.time),
                    _buildDetailChip(Icons.timer, '${session.duration} min'),
                    _buildDetailChip(Icons.category, session.sessionType),
                    _buildDetailChip(Icons.location_on, session.sessionLocation),
                  ],
                ),

                // Price information
                if (session.sessionTypePrice > 0) ...[
                  const SizedBox(height: 12),
                  _buildSessionDetailRow(
                    icon: Icons.attach_money,
                    title: 'Price',
                    value: '\$${session.sessionTypePrice.toStringAsFixed(2)}',
                  ),
                ],

                // Free session
                if (session.sessionTypePrice <= 0) ...[
                  const SizedBox(height: 12),
                  _buildSessionDetailRow(
                    icon: Icons.money_off,
                    title: 'Price',
                    value: 'Free',
                  ),
                ],

                // Rating for completed sessions
                if (type == 'completed' && session.rating != null) ...[
                  const SizedBox(height: 12),
                  _buildRatingRow(session.rating!),
                ],

                // Cancellation reason for cancelled sessions
                if (canCancel || showPayButton) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (showPayButton)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _navigateToPayment(session),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Pay Now'),
                          ),
                        ),
                      if (showPayButton) const SizedBox(width: 8),
                      if (canCancel)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _cancelSession(session),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Cancel Session'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(Session session, String type) {
    final buttons = <Widget>[];

    // زر الدفع للجلسات التي تحتاج دفع
    if (session.status == 'Pending Payment') {
      buttons.add(
        Container(
          margin: const EdgeInsets.only(right: 4),
          child: ElevatedButton(
            onPressed: () => _navigateToPayment(session),
            style: ElevatedButton.styleFrom(
              backgroundColor: _warningColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Pay Now'),
          ),
        ),
      );
    }

    // زر المنبه للجميع
    buttons.add(
      IconButton(
        icon: const Icon(Icons.notifications_none, size: 20),
        onPressed: () => _scheduleReminder(session),
        color: _primaryColor,
        tooltip: 'Set Reminder',
      ),
    );

    // زر الموافقة للجلسات Pending Approval
    if (type == 'pending' && session.status == 'Pending Approval') {
      buttons.add(
        IconButton(
          icon: const Icon(Icons.check_circle, size: 20),
          onPressed: () => _approvePendingSession(session, true),
          color: _successColor,
          tooltip: 'Approve Session',
        ),
      );
    }

    // زر الرفض للجلسات Pending Approval
    if (type == 'pending' && session.status == 'Pending Approval') {
      buttons.add(
        IconButton(
          icon: const Icon(Icons.cancel, size: 20),
          onPressed: () => _approvePendingSession(session, false),
          color: _errorColor,
          tooltip: 'Reject Session',
        ),
      );
    }

    // زر إعادة الجدولة للجلسات المعلقة فقط
    if (session.displayStatus == 'pending' || session.status == 'Pending Approval') {
      buttons.add(
        IconButton(
          icon: const Icon(Icons.schedule, size: 20),
          onPressed: () => _rescheduleSession(session),
          color: _warningColor,
          tooltip: 'Reschedule',
        ),
      );
    }

    // زر التقييم للجلسات المكتملة بدون تقييم
    if (type == 'completed' && session.rating == null) {
      buttons.add(
        IconButton(
          icon: const Icon(Icons.star_outline, size: 20),
          onPressed: () => _rateSession(session),
          color: Colors.amber,
          tooltip: 'Rate Session',
        ),
      );
    }

    // زر التأكيد للجلسات القادمة فقط
    if (type == 'upcoming' && session.status == 'Scheduled') {
      buttons.add(
        IconButton(
          icon: const Icon(Icons.check, size: 20),
          onPressed: () => _confirmSession(session),
          color: _successColor,
          tooltip: 'Confirm Session',
        ),
      );
    }

    // زر الإلغاء للجلسات القادمة فقط
    if (type == 'upcoming' && session.status == 'Scheduled') {
      buttons.add(
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => _cancelSession(session),
          color: _errorColor,
          tooltip: 'Cancel Session',
        ),
      );
    }

    // زر مشاركة للجميع
    buttons.add(
      IconButton(
        icon: const Icon(Icons.share, size: 20),
        onPressed: () => _shareSession(session),
        color: _secondaryColor,
        tooltip: 'Share Session',
      ),
    );

    // زر الفاتورة إذا كان هناك سعر
    if (session.sessionTypePrice > 0) {
      buttons.add(
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, size: 20),
          onPressed: () => _downloadInvoice(session),
          color: _errorColor,
          tooltip: 'Download Invoice',
        ),
      );
    }

    return buttons;
  }

  Widget _buildRatingRow(double rating) {
    return Row(
      children: [
        const Icon(Icons.star, size: 16, color: Colors.amber),
        const SizedBox(width: 8),
        Text(
          '$rating/5',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        ...List.generate(5, (index) {
          return Icon(
            Icons.star,
            size: 16,
            color: index < rating.floor() ? Colors.amber : Colors.grey[300],
          );
        }),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final statusConfig = {
      'upcoming': {'color': Colors.blue, 'icon': Icons.schedule},
      'completed': {'color': _successColor, 'icon': Icons.check_circle},
      'pending': {'color': _warningColor, 'icon': Icons.pending},
      'cancelled': {'color': _errorColor, 'icon': Icons.cancel},
    };

    final config = statusConfig[status] ?? statusConfig['pending']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config['color'] as Color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _textSecondary),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: _textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _textSecondary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSession(Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final success = await ApiService.confirmSession(token, session.sessionId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Session confirmed successfully'),
            backgroundColor: _successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadAllSessions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm session: ${e.toString()}'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _cancelSession(Session session) async {
    String? cancellationReason;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this session?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason (Optional)',
                hintText: 'Enter reason for cancellation...',
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await ApiService.cancelSession(token, session.sessionId, reason: reason);

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        String message = result['message'] ?? 'Session cancelled successfully';

        if (result['refundProcessed'] == true) {
          final refundAmount = result['refundAmount'] ?? 0;
          message += '\nRefund of ${refundAmount} JOD has been processed.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _successColor,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadAllSessions();
      } else {
        throw Exception(result['message'] ?? 'Failed to cancel session');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel session: ${e.toString()}'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _approvePendingSession(Session session, bool approve) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await ParentService.approveNewSession(
        int.parse(session.sessionId),
        approve,
      );

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? 'Session approved successfully. Status changed to Scheduled.'
                : 'Session rejected successfully.'),
            backgroundColor: _successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadAllSessions();
      } else {
        throw Exception(result['message'] ?? 'Failed to process approval');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process approval: ${e.toString()}'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _navigateToBookSession() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BookSessionScreen()),
    ).then((_) {
      _loadAllSessions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}