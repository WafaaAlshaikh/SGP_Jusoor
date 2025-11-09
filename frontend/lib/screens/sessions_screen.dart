// lib/screens/sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/session.dart'; // ⬅️ استخدم هذا فقط
import '../models/payment_models.dart'; // ⬅️ أضف هذا الاستيراد
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
      final allSessions = await ApiService.getSessions(token);
      print('✅ Loaded ${allSessions.length} sessions');

      _categorizeSessions(allSessions);
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

  void _categorizeSessions(List<Session> sessions) {
    setState(() {
      _upcomingSessions = sessions.where((s) => s.displayStatus == 'upcoming').toList();
      _completedSessions = sessions.where((s) => s.displayStatus == 'completed').toList();
      _pendingSessions = sessions.where((s) => s.displayStatus == 'pending').toList();
      _cancelledSessions = sessions.where((s) => s.displayStatus == 'cancelled').toList();
    });
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
      const SnackBar(
        content: Text('Thank you for your rating! 🌟'),
        backgroundColor: Colors.green,
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

  // ============ NEW FEATURES ============

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
      const SnackBar(
        content: Text('Reminder scheduled for 1 hour before session'),
        backgroundColor: Colors.green,
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
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
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

  // ============ BUILD METHOD ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentAppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Sessions'),
        backgroundColor: Colors.white,
        foregroundColor: ParentAppColors.textDark,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: ParentAppColors.primaryTeal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: ParentAppColors.primaryTeal,
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
              child: CircularProgressIndicator(strokeWidth: 2),
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
        backgroundColor: ParentAppColors.primaryTeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final institutions = _getUniqueInstitutions();
    final sessionTypes = _getUniqueSessionTypes();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search by child, specialist, institution...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
                  decoration: const InputDecoration(
                    labelText: 'Institution',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
                  decoration: const InputDecoration(
                    labelText: 'Session Type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading Sessions...',
            style: TextStyle(
              color: Colors.grey[600],
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
          Icon(
            Icons.error_outline,
            color: Colors.red[300],
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllSessions,
            style: ElevatedButton.styleFrom(
              backgroundColor: ParentAppColors.primaryTeal,
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
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
            Icon(
              state['icon'] as IconData,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              state['title'] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state['message'] as String,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (type == 'upcoming' || type == 'pending')
              ElevatedButton(
                onPressed: _navigateToBookSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParentAppColors.primaryTeal,
                ),
                child: Text(
                  state['action'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Session session, String type) {
    return GestureDetector(
      onTap: () => _showSessionDetails(session),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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

                  // Quick Actions Row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // زر الدفع للجلسات التي تحتاج دفع
                      if (session.status == 'Pending Payment')
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: () => _navigateToPayment(session),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Pay Now'),
                          ),
                        ),

                      // زر المنبه للجميع
                      IconButton(
                        icon: const Icon(Icons.notifications_none, size: 20),
                        onPressed: () => _scheduleReminder(session),
                        color: Colors.blue,
                        tooltip: 'Set Reminder',
                      ),

                      // زر إعادة الجدولة للجلسات المعلقة فقط
                      if (session.displayStatus == 'pending' || session.status == 'Pending Approval')
                        IconButton(
                          icon: const Icon(Icons.schedule, size: 20),
                          onPressed: () => _rescheduleSession(session),
                          color: Colors.orange,
                          tooltip: 'Reschedule',
                        ),

                      // زر التقييم للجلسات المكتملة بدون تقييم
                      if (type == 'completed' && session.rating == null)
                        IconButton(
                          icon: const Icon(Icons.star_outline, size: 20),
                          onPressed: () => _rateSession(session),
                          color: Colors.amber,
                          tooltip: 'Rate Session',
                        ),

                      // زر التأكيد للجلسات القادمة والمعلقة
                      if (session.displayStatus == 'upcoming' || session.displayStatus == 'pending')
                        IconButton(
                          icon: const Icon(Icons.check, size: 20),
                          onPressed: () => _confirmSession(session),
                          color: Colors.green,
                          tooltip: 'Confirm Session',
                        ),

                      // زر الإلغاء للجلسات القادمة والمعلقة
                      if (session.displayStatus == 'upcoming' || session.displayStatus == 'pending')
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _cancelSession(session),
                          color: Colors.red,
                          tooltip: 'Cancel Session',
                        ),

                      // زر مشاركة للجميع
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        onPressed: () => _shareSession(session),
                        color: Colors.purple,
                        tooltip: 'Share Session',
                      ),

                      // زر الفاتورة إذا كان هناك سعر
                      if (session.sessionTypePrice > 0)
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          onPressed: () => _downloadInvoice(session),
                          color: Colors.red,
                          tooltip: 'Download Invoice',
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

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

              const SizedBox(height: 8),

              // Date, Time, and Duration
              Row(
                children: [
                  _buildDetailChip(Icons.calendar_today, session.date),
                  const SizedBox(width: 8),
                  _buildDetailChip(Icons.access_time, session.time),
                  const SizedBox(width: 8),
                  _buildDetailChip(Icons.timer, '${session.duration} min'),
                ],
              ),

              const SizedBox(height: 8),

              // Session type and location
              Row(
                children: [
                  _buildDetailChip(Icons.category, session.sessionType),
                  const SizedBox(width: 8),
                  _buildDetailChip(Icons.location_on, session.sessionLocation),
                ],
              ),

              // Price information
              if (session.sessionTypePrice > 0) ...[
                const SizedBox(height: 8),
                _buildSessionDetailRow(
                  icon: Icons.attach_money,
                  title: 'Price',
                  value: '\$${session.sessionTypePrice.toStringAsFixed(2)}',
                ),
              ],

              // Free session
              if (session.sessionTypePrice <= 0) ...[
                const SizedBox(height: 8),
                _buildSessionDetailRow(
                  icon: Icons.money_off,
                  title: 'Price',
                  value: 'Free',
                ),
              ],

              // Rating for completed sessions
              if (type == 'completed' && session.rating != null) ...[
                const SizedBox(height: 8),
                _buildRatingRow(session.rating!),
              ],

              // Cancellation reason for cancelled sessions
              if (type == 'cancelled' && session.cancellationReason != null) ...[
                const SizedBox(height: 8),
                _buildSessionDetailRow(
                  icon: Icons.info_outline,
                  title: 'Cancellation Reason',
                  value: session.cancellationReason!,
                ),
              ],

              // Session notes if available
              if (session.parentNotes != null && session.parentNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSessionDetailRow(
                  icon: Icons.note,
                  title: 'Notes',
                  value: session.parentNotes!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
// في sessions_screen.dart - أضف معالجة الأخطاء
  void _navigateToPayment(Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      print('🔍 Looking for invoice for session: ${session.sessionId}');

      final invoices = await PaymentService.getParentInvoices(token);
      print('📊 Found ${invoices.length} invoices');

      Invoice? sessionInvoice;
      try {
        // ⬇️⬇️⬇️ إصلاح المقارنة - تحويل sessionId إلى int
        sessionInvoice = invoices.firstWhere(
              (invoice) => invoice.sessionId == int.tryParse(session.sessionId),
        );
        print('✅ Found invoice: ${sessionInvoice.invoiceNumber}');
      } catch (e) {
        print('❌ No invoice found for session ${session.sessionId}');
        print('💡 Available sessions in invoices: ${invoices.map((i) => i.sessionId).toList()}');

        // ⬇️⬇️⬇️ حل بديل - البحث باستخدام toString()
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

      // التنقل لشاشة الدفع
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
  }  Widget _buildRatingRow(double rating) {
    return Row(
      children: [
        const Icon(Icons.star, size: 16, color: Colors.amber),
        const SizedBox(width: 8),
        const Text(
          'Rating: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        Text(
          '$rating/5',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
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
      'completed': {'color': Colors.green, 'icon': Icons.check_circle},
      'pending': {'color': Colors.orange, 'icon': Icons.pending},
      'cancelled': {'color': Colors.red, 'icon': Icons.cancel},
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
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
          const SnackBar(
            content: Text('Session confirmed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAllSessions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm session: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelSession(Session session) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Session'),
        content: const Text('Are you sure you want to cancel this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performCancelSession(session);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancelSession(Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final success = await ApiService.cancelSession(token, session.sessionId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAllSessions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel session: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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