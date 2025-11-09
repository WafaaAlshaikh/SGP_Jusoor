import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/specialist_session_service.dart';
import '../theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../services/activity_service.dart';
class SpecialistSessionsScreen extends StatefulWidget {
  @override
  _SpecialistSessionsScreenState createState() => _SpecialistSessionsScreenState();
}

class _SpecialistSessionsScreenState extends State<SpecialistSessionsScreen> {
  List<Map<String, dynamic>> sessions = [];
  List<Map<String, dynamic>> filteredSessions = [];
  List<Map<String, dynamic>> pendingUpdateRequests = []; // 🔥 الجديد
  bool isLoading = true;
  bool isLoadingPendingRequests = false; // 🔥 الجديد

  String filterStatus = 'All';
  DateTime selectedDate = DateTime.now();
  String searchQuery = '';
  int _currentPage = 0;
  bool _showCompleted = true;
  String _dateFilterType = 'all'; // 'all', 'today', 'upcoming'

  // Statistics
  int totalSessions = 0;
  int completedSessions = 0;
  int todaySessions = 0;
  int upcomingSessions = 0;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<String> _searchSuggestions = [];
  Timer? _searchDebounce;

  // قائمة الحالات للفلتر
  final List<String> statusFilters = [
    'All',
    'Scheduled',
    'Completed',
    'Cancelled',
    'Absent',
    'Rescheduled'

  ];

  @override
  void initState() {
    super.initState();
    _fetchSessionsFromApi();
    _fetchPendingUpdateRequests(); // 🔥 الجديد
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _hideSearchSuggestions();
    super.dispose();
  }

  // 🔥 الجديد: دالة لجلب الطلبات المعلقة
  Future<void> _fetchPendingUpdateRequests() async {
    setState(() => isLoadingPendingRequests = true);
    try {
      final data = await SpecialistSessionService.getPendingUpdateRequests();
      setState(() {
        pendingUpdateRequests = data;
        isLoadingPendingRequests = false;
      });
    } catch (e) {
      setState(() => isLoadingPendingRequests = false);
      print('Failed to load pending update requests: $e');
    }
  }

  // 🔥 الجديد: دالة لعرض الطلبات المعلقة
  void _showPendingUpdateRequests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pending_actions, color: Colors.orange, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Pending Update Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: _fetchPendingUpdateRequests,
                ),
              ],
            ),
            SizedBox(height: 16),

            // Content
            if (isLoadingPendingRequests)
              Center(child: CircularProgressIndicator(color: AppColors.primary))
            else if (pendingUpdateRequests.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'No Pending Requests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textGray,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'All update requests have been processed',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: pendingUpdateRequests.length,
                  itemBuilder: (context, index) {
                    final request = pendingUpdateRequests[index];
                    return _buildPendingRequestCard(request);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🔥 الجديد: كارد لعرض الطلب المعلق
  Widget _buildPendingRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.withOpacity(0.05), Colors.orange.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, size: 16, color: Colors.orange),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request['childName'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Original Session Info
              _buildPendingInfoItem(
                Icons.calendar_today,
                'Original Session',
                '${DateFormat('MMM dd, yyyy').format(request['originalDate'])} at ${request['originalTime']}',
              ),

              // New Session Info
              _buildPendingInfoItem(
                Icons.edit_calendar,
                'Requested Change',
                '${DateFormat('MMM dd, yyyy').format(request['date'])} at ${request['time']}',
              ),

              // Institution
              _buildPendingInfoItem(
                Icons.school,
                'Institution',
                request['institution'],
              ),

              // Reason
              if (request['updateReason'] != null)
                _buildPendingInfoItem(
                  Icons.note,
                  'Reason',
                  request['updateReason'],
                ),

              SizedBox(height: 12),
              Divider(color: Colors.orange.withOpacity(0.2)),
              SizedBox(height: 8),

              // Status Message
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Waiting for parent approval',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 الجديد: عنصر معلومات في الطلب المعلق
  Widget _buildPendingInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: Colors.orange),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  void _performSearch(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
      _hideSearchSuggestions();
    });
  }

  bool _fuzzyMatch(String text, String query) {
    if (query.isEmpty) return true;

    int queryIndex = 0;
    for (int i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] == query[queryIndex]) {
        queryIndex++;
      }
    }
    return queryIndex == query.length;
  }

  void _showSearchSuggestions(String query) {
    if (query.isEmpty) {
      _hideSearchSuggestions();
      return;
    }

    _searchSuggestions = sessions
        .map((session) => session['childName'].toString())
        .where((name) => name.toLowerCase().contains(query.toLowerCase()))
        .toSet()
        .toList()
        .take(5)
        .toList();

    _hideSearchSuggestions();

    if (_searchSuggestions.isNotEmpty) {
      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: _getSearchFieldHeight(context),
          left: 16,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: _searchSuggestions.map((suggestion) => ListTile(
                  leading: Icon(Icons.person, color: AppColors.primary, size: 20),
                  title: Text(
                    suggestion,
                    style: TextStyle(fontSize: 14, color: AppColors.textDark),
                  ),
                  onTap: () {
                    _searchController.text = suggestion;
                    _performSearch(suggestion);
                    _hideSearchSuggestions();
                    _searchFocusNode.unfocus();
                  },
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                )).toList(),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  double _getSearchFieldHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final paddingTop = mediaQuery.padding.top;
    return kToolbarHeight + paddingTop + 200;
  }

  void _hideSearchSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _fetchSessionsFromApi() async {
    setState(() => isLoading = true);
    try {
      final data = await SpecialistSessionService.getSessions();
      setState(() {
        sessions = data;
        filteredSessions = data;
        _calculateStatistics();
        isLoading = false;
      });
      // 🔥 تحديث الطلبات المعلقة أيضاً
      _fetchPendingUpdateRequests();
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to load sessions: $e');
    }
  }

  void _calculateStatistics() {
    totalSessions = sessions.length;
    completedSessions = sessions.where((s) => s['status'] == 'Completed').length;

    final now = DateTime.now();
    todaySessions = sessions.where((s) => _isSameDay(s['date'], now)).length;
    upcomingSessions = sessions.where((s) => s['date'].isAfter(now) && s['status'] == 'Scheduled').length;
  }

  void _applyFilters() {
    setState(() {
      filteredSessions = sessions.where((session) {
        // فلتر البحث
        bool matchesSearch = searchQuery.isEmpty ||
            session['childName'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            session['childName'].toString().toLowerCase().startsWith(searchQuery.toLowerCase()) ||
            session['institution'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            session['type'].toString().toLowerCase().contains(searchQuery.toLowerCase());

        // فلتر الحالة
        bool matchesStatus = filterStatus == 'All' || session['status'] == filterStatus;

        // فلتر إظهار المكتملة
        bool showCompleted = _showCompleted || session['status'] != 'Completed';

        // فلتر التاريخ
        bool matchesDate = true;
        final now = DateTime.now();

        if (_dateFilterType == 'today') {
          matchesDate = _isSameDay(session['date'], now);
        } else if (_dateFilterType == 'upcoming') {
          final sevenDaysFromNow = now.add(Duration(days: 7));
          matchesDate = session['date'].isAfter(now) && session['date'].isBefore(sevenDaysFromNow);
        }
        // إذا كان 'all' فلا نطبق أي فلتر تاريخ

        return matchesSearch && matchesStatus && showCompleted && matchesDate;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      selectedDate = DateTime.now();
      searchQuery = '';
      filterStatus = 'All';
      _dateFilterType = 'all';
      _searchController.clear();
      _showCompleted = true;
      _hideSearchSuggestions();
      filteredSessions = List.from(sessions);
    });
  }

  // ✅ التصحيح: استبدال دالة التحديث القديمة بالجديدة
  // ✅ التصحيح: استبدال دالة التحديث القديمة بالجديدة مع السبب
  void _requestSessionUpdate(int id, String status, DateTime date, String time, String mode, {String reason = ''}) async {
    try {
      await SpecialistSessionService.requestSessionUpdate(
        sessionId: id,
        date: date,
        time: time,
        status: status,
        sessionType: mode,
        reason: reason.isNotEmpty ? reason : null, // ⭐ إرسال السبب
      );
      await _fetchSessionsFromApi();
      _showSuccessSnackBar('Update request sent to parent for approval${reason.isNotEmpty ? ' with reason' : ''}');
    } catch (e) {
      _showErrorSnackBar('Failed to request session update: $e');
    }
  }
  // ⭐ جديد: طلب حذف الجلسة مع السبب
  void _requestDeleteSession(int id) async {
    String reason = '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_outline, color: Colors.red, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Request Session Deletion',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Are you sure you want to request deletion of this session?',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),

              // ⭐ حقل السبب
              Text('Reason (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14)),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter reason for deletion...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    hintStyle: TextStyle(color: AppColors.textGray),
                  ),
                  onChanged: (value) {
                    reason = value;
                  },
                ),
              ),
              SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textGray,
                          side: BorderSide(color: AppColors.textGray),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            await SpecialistSessionService.requestDeleteSession(id, reason: reason.isNotEmpty ? reason : null);
                            await _fetchSessionsFromApi();
                            await ActivityService.addActivity(
                                'New post shared in community',
                                'post'
                            );
                            _showSuccessSnackBar('Deleted Session sent to Parent${reason.isNotEmpty ? ' with reason' : ''}');
                          } catch (e) {
                            _showErrorSnackBar('Failed to send request: $e');
                          }
                        },
                        child: Text('Request Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  // Utility Methods
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(color: AppColors.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Enhanced Session Dialog
  void _showSessionDetailsDialog(Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(session),
              _buildSessionDetails(session),
              _buildDialogActions(session),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(Map<String, dynamic> session) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.child_care, color: Colors.white, size: 36),
          ),
          SizedBox(height: 16),
          Text(
            session['childName'],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          _buildStatusBadge(session['status'], large: true),
        ],
      ),
    );
  }

  Widget _buildSessionDetails(Map<String, dynamic> session) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          _buildEnhancedDetailItem(Icons.school, 'Institution', session['institution']),
          _buildEnhancedDetailItem(Icons.category, 'Session Type', session['type']),
          _buildEnhancedDetailItem(Icons.calendar_today, 'Date', DateFormat('EEEE, MMMM d, yyyy').format(session['date'])),
          _buildEnhancedDetailItem(Icons.access_time, 'Time', session['time']),
          _buildEnhancedDetailItem(Icons.timer, 'Duration', '${session['duration'] ?? 60} minutes'),
          _buildEnhancedDetailItem(Icons.video_call, 'Mode', session['mode']),
          if (session['category'] != null)
            _buildEnhancedDetailItem(Icons.label, 'Category', session['category']),
        ],
      ),
    );
  }

  Widget _buildEnhancedDetailItem(IconData icon, String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogActions(Map<String, dynamic> session) {
    bool isCompleted = session['status'] == 'Completed';
    bool isOnline = session['mode'] == 'Online';

    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          if (isOnline && !isCompleted)
            Expanded(
              child: Container(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _joinZoomSession(session);
                  },
                  icon: Icon(Icons.video_call, size: 20),
                  label: Text('Join Zoom'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          if (isOnline && !isCompleted) SizedBox(width: 12),
          if (!isCompleted)
            Expanded(
              child: Container(
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditSessionDialog(session);
                  },
                  child: Text('Edit Session'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Enhanced Edit Session Dialog
// Enhanced Edit Session Dialog مع إضافة السبب
  void _showEditSessionDialog(Map<String, dynamic> session) {
    if (session['status'] == 'Completed') {
      _showErrorSnackBar('Cannot edit completed sessions');
      return;
    }

    String newStatus = session['status'];
    DateTime newDate = session['date'];
    String newTime = session['time'];
    String newMode = session['mode'] ?? 'Onsite';
    String reason = ''; // ⭐ جديد: حقل السبب

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Edit Session',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Update session details',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Status Selection
                  Text('Status', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 16)),
                  SizedBox(height: 8),
                  _buildEnhancedStatusSelection(newStatus, (value) {
                    setState(() => newStatus = value);
                  }),

                  SizedBox(height: 20),

                  // Mode Dropdown
                  Text('Session Mode', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 16)),
                  SizedBox(height: 8),
                  _buildEnhancedModeDropdown(newMode, (value) {
                    setState(() => newMode = value!);
                  }),

                  SizedBox(height: 20),

                  // Date Field
                  Text('Date', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 16)),
                  SizedBox(height: 8),
                  _buildEnhancedDateField(newDate, (pickedDate) {
                    if (pickedDate != null) {
                      setState(() => newDate = pickedDate);
                    }
                  }),

                  SizedBox(height: 20),

                  // Time Field
                  Text('Time', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 16)),
                  SizedBox(height: 8),
                  _buildEnhancedTimeField(newTime, (pickedTime) {
                    if (pickedTime != null) {
                      setState(() => newTime = pickedTime);
                    }
                  }),

                  SizedBox(height: 20),

                  // ⭐ جديد: حقل السبب
                  Text('Reason (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 16)),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for update...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        hintStyle: TextStyle(color: AppColors.textGray),
                      ),
                      onChanged: (value) {
                        setState(() => reason = value);
                      },
                    ),
                  ),

                  SizedBox(height: 30),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textGray,
                              side: BorderSide(color: AppColors.textGray),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              // ✅ التحديث: إرسال السبب مع التعديل
                              _requestSessionUpdate(session['id'], newStatus, newDate, newTime, newMode, reason: reason);
                              Navigator.pop(context);
                            },
                            child: Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedStatusSelection(String currentStatus, ValueChanged<String> onStatusChanged) {
    return Column(
      children: [
        _buildEnhancedStatusOption(
          'Completed',
          Icons.check_circle,
          Colors.green,
          currentStatus == 'Completed',
              () => onStatusChanged('Completed'),
        ),
        SizedBox(height: 10),
        _buildEnhancedStatusOption(
          'Absent',
          Icons.cancel,
          Colors.red,
          currentStatus == 'Absent',
              () => onStatusChanged('Absent'),
        ),

      ],
    );
  }

  Widget _buildEnhancedStatusOption(String status, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.primary.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                status,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedModeDropdown(String value, ValueChanged<String?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 28),
          items: ['Onsite', 'Online'].map((m) => DropdownMenuItem(
            value: m,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      m == 'Online' ? Icons.video_call : Icons.location_on,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    m,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEnhancedDateField(DateTime date, ValueChanged<DateTime?> onDatePicked) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2023),
          lastDate: DateTime(2027),
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        onDatePicked(picked);
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('MMMM dd, yyyy').format(date),
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTimeField(String time, ValueChanged<String> onTimePicked) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.parse(time.split(":")[0]),
            minute: int.parse(time.split(":")[1]),
          ),
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          final newTime = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
          onTimePicked(newTime);
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.access_time, color: AppColors.primary, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                time,
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // Enhanced Session Card
  Widget _buildSessionCard(Map<String, dynamic> session) {
    bool isCompleted = session['status'] == 'Completed';
    bool isOnline = session['mode'] == 'Online';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: AppColors.primary.withOpacity(0.2),
        child: InkWell(
          onTap: () => _showSessionDetailsDialog(session),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: isCompleted
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey.shade50, Colors.grey.shade100],
              )
                  : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, AppColors.background.withOpacity(0.5)],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildSessionLeading(session),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildSessionContent(session),
                  ),
                  _buildSessionTrailing(session),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionLeading(Map<String, dynamic> session) {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.child_care, color: Colors.white, size: 24),
        ),
        if (session['mode'] == 'Online')
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(Icons.videocam, color: Colors.white, size: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildSessionContent(Map<String, dynamic> session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                session['childName'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            _buildStatusBadge(session['status']),
          ],
        ),
        SizedBox(height: 6),
        Text(
          session['institution'],
          style: TextStyle(
            color: AppColors.textGray,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd').format(session['date']),
                  style: TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 14, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  session['time'],
                  style: TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        if (session['duration'] != null) ...[
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.timer, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                '${session['duration']} min',
                style: TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSessionTrailing(Map<String, dynamic> session) {
    bool isCompleted = session['status'] == 'Completed';
    bool isOnline = session['mode'] == 'Online';

    if (isCompleted) {
      return Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.lock, color: Colors.green, size: 18),
      );
    }

    return PopupMenuButton<String>(
      icon: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_vert, color: AppColors.primary, size: 18),
      ),
      onSelected: (value) {
        switch (value) {
          case 'details':
            _showSessionDetailsDialog(session);
            break;
          case 'join':
            _joinZoomSession(session);
            break;
          case 'edit':
            _showEditSessionDialog(session);
            break;
          case 'delete':
            _requestDeleteSession(session['id']);

            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'details', child: _buildPopupItem(Icons.info_outline, 'Details')),
        if (isOnline) PopupMenuItem(value: 'join', child: _buildPopupItem(Icons.video_call, 'Join Zoom')),
        PopupMenuItem(value: 'edit', child: _buildPopupItem(Icons.edit, 'Edit Session')),
        PopupMenuItem(value: 'delete', child: _buildPopupItem(Icons.delete_outline, 'Request Delete', isDestructive: true)),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildPopupItem(IconData icon, String text, {bool isDestructive = false}) {
    return Row(
      children: [
        Icon(icon, color: isDestructive ? Colors.red : AppColors.primary, size: 20),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isDestructive ? Colors.red : AppColors.textDark,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, {bool large = false}) {
    Color color;
    IconData icon;
    String text;

    switch(status) {
      case 'Present':
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Present';
        break;
      case 'Absent':
        color = Colors.red;
        icon = Icons.cancel;
        text = 'Absent';
        break;
      case 'Completed':
        color = AppColors.primary;
        icon = Icons.done_all;
        text = 'Completed';
        break;
      case 'Confirmed':
        color = Colors.green;
        icon = Icons.verified;
        text = 'Confirmed';
        break;
      case 'Cancelled':
        color = Colors.red;
        icon = Icons.block;
        text = 'Cancelled';
        break;
      case 'Rescheduled':
        color = Colors.orange;
        icon = Icons.schedule;
        text = 'Rescheduled';
        break;
      case 'Pending Approval':
        color = Colors.orange;
        icon = Icons.pending;
        text = 'Pending';
        break;
      case 'Scheduled':
        color = Colors.blue;
        icon = Icons.calendar_today;
        text = 'Scheduled';
        break;
      case 'Cancelled':
        color = Colors.red;
        icon = Icons.delete;
        text = 'Cancelled';
        break;
      default:
        color = AppColors.textGray;
        icon = Icons.calendar_today;
        text = 'Scheduled';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 16 : 8, vertical: large ? 6 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 16 : 12, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: large ? 12 : 10,
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Statistics Card
  Widget _buildStatisticsCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.analytics, color: Colors.white, size: 18),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEnhancedStatItem(Icons.calendar_today, 'Total', totalSessions.toString(), Colors.white),
              _buildEnhancedStatItem(Icons.check_circle, 'Completed', completedSessions.toString(), Colors.green.shade100),
              _buildEnhancedStatItem(Icons.today, 'Today', todaySessions.toString(), Colors.orange.shade100),
              _buildEnhancedStatItem(Icons.upcoming, 'Upcoming', upcomingSessions.toString(), Colors.blue.shade100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Enhanced Filters مع إضافة فلتر الحالة
  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: searchQuery.isNotEmpty ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textGray),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                          _hideSearchSuggestions();
                        },
                      ) : null,
                      hintText: 'Search by name, institution, or type...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      hintStyle: TextStyle(color: AppColors.textGray),
                    ),
                    style: TextStyle(color: AppColors.textDark),
                    onChanged: (value) {
                      _performSearch(value);
                    },
                    onTap: () {
                      if (_searchController.text.isNotEmpty) {
                        _showSearchSuggestions(_searchController.text);
                      }
                    },
                  ),
                ),
              ),
              SizedBox(width: 8),
              _buildFilterButton(Icons.filter_alt, 'Filters', _showAdvancedFilters),
              SizedBox(width: 6),
              _buildFilterButton(Icons.calendar_today, 'Today', _showTodaySessions),
              SizedBox(width: 6),
              _buildFilterButton(Icons.upcoming, 'Upcoming', _showUpcomingSessions),
              SizedBox(width: 6),
              _buildFilterButton(Icons.refresh, 'Reset', _resetFilters),
            ],
          ),
          SizedBox(height: 12),

          // Status Filter
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.filter_list, color: AppColors.primary, size: 18),
              ),
              title: Text(
                'Status: $filterStatus',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark),
              ),
              trailing: Container(
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 16),
              ),
              onTap: _showStatusFilterDialog,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
              minLeadingWidth: 0,
            ),
          ),
          SizedBox(height: 8),

          // Date Filter Type
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.date_range, color: AppColors.primary, size: 18),
              ),
              title: Text(
                'Date Filter: ${_getDateFilterText()}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark),
              ),
              trailing: Container(
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 16),
              ),
              onTap: _showDateFilterDialog,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
              minLeadingWidth: 0,
            ),
          ),
        ],
      ),
    );
  }

  String _getDateFilterText() {
    switch(_dateFilterType) {
      case 'today': return 'Today';
      case 'upcoming': return 'Next 7 Days';
      default: return 'All Sessions';
    }
  }

  void _showDateFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text('Filter by Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            SizedBox(height: 16),
            _buildDateFilterOption('All Sessions', Icons.all_inclusive, 'all'),
            _buildDateFilterOption('Today', Icons.today, 'today'),
            _buildDateFilterOption('Next 7 Days', Icons.upcoming, 'upcoming'),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                  side: BorderSide(color: AppColors.textGray),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterOption(String title, IconData icon, String value) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _dateFilterType == value ? AppColors.primary.withOpacity(0.2) : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: _dateFilterType == value ? AppColors.primary : AppColors.textGray,
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: _dateFilterType == value ? FontWeight.bold : FontWeight.normal,
            color: _dateFilterType == value ? AppColors.primary : AppColors.textDark,
          ),
        ),
        trailing: _dateFilterType == value ? Icon(Icons.check, color: AppColors.primary) : null,
        onTap: () {
          setState(() {
            _dateFilterType = value;
            _applyFilters();
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showStatusFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text('Filter by Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            SizedBox(height: 16),
            ...statusFilters.map((status) => Card(
              margin: EdgeInsets.only(bottom: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: filterStatus == status ? AppColors.primary.withOpacity(0.2) : AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: filterStatus == status ? AppColors.primary : AppColors.textGray,
                    size: 18,
                  ),
                ),
                title: Text(
                  status,
                  style: TextStyle(
                    fontWeight: filterStatus == status ? FontWeight.bold : FontWeight.normal,
                    color: filterStatus == status ? AppColors.primary : AppColors.textDark,
                  ),
                ),
                trailing: filterStatus == status ? Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() {
                    filterStatus = status;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
            )).toList(),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                  side: BorderSide(color: AppColors.textGray),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch(status) {
      case 'All': return Icons.all_inclusive;
      case 'Scheduled': return Icons.calendar_today;
      case 'Completed': return Icons.check_circle;
      case 'Cancelled': return Icons.cancel;
      case 'Absent': return Icons.person_off;
      case 'Rescheduled': return Icons.schedule;
      case 'Cancelled': return Icons.delete;
      default: return Icons.circle;
    }
  }

  Widget _buildFilterButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text('Advanced Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: Text('Show Completed Sessions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                subtitle: Text('Include completed sessions in the list', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                value: _showCompleted,
                onChanged: (value) => setState(() {
                  _showCompleted = value;
                  _applyFilters();
                  Navigator.pop(context);
                }),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  _resetFilters();
                  Navigator.pop(context);
                },
                child: Text('Reset All Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                  side: BorderSide(color: AppColors.textGray),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Quick Actions
  Widget _buildQuickActions() {
    return FloatingActionButton(
      onPressed: _showQuickActions,
      backgroundColor: AppColors.primary,
      child: Icon(Icons.add, color: Colors.white, size: 24),
      tooltip: 'Quick Actions',
      elevation: 2,
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            SizedBox(height: 16),

            // 🔥 التحديث: إضافة خيار طلبات الحذف
            _buildQuickActionItem(
                Icons.pending_actions,
                'Pending Updates',
                'View session update requests waiting for parent approval',
                _showPendingUpdateRequests
            ),
            _buildQuickActionItem(
                Icons.delete_outline, // ⭐ جديد
                'Cancelled Session',
                'View sessions Cancelled',
                _showDeleteRequests
            ),
            _buildQuickActionItem(Icons.done_all, 'Complete Today', 'Mark all today sessions as completed', _completeTodaySessions),
            _buildQuickActionItem(Icons.bar_chart, 'Monthly Report', 'View monthly session statistics', _showMonthlyReport),
            _buildQuickActionItem(Icons.notifications, 'Set Reminders', 'Set reminders for upcoming sessions', _setReminders),
          ],
        ),
      ),
    );
  }

  // ⭐ جديد: عرض طلبات الحذف
  void _showDeleteRequests() async {
    Navigator.pop(context); // إغلاق الـ Quick Actions

    try {
      final deleteRequests = await SpecialistSessionService.getDeleteRequestedSessions();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_outline, color: Colors.red, size: 24),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Cancelled session',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, color: AppColors.primary),
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteRequests();
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Content
              if (deleteRequests.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'No Cancelled session',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textGray,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'All delete  session have been processed',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: deleteRequests.length,
                    itemBuilder: (context, index) {
                      final request = deleteRequests[index];
                      return _buildDeleteRequestCard(request);
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to load delete session: $e');
    }
  }

// ⭐ جديد: كارد لعرض طلب الحذف
  Widget _buildDeleteRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.red.withOpacity(0.05), Colors.red.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, size: 16, color: Colors.red),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request['childName'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Cancelled session',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Session Info
              _buildDeleteRequestInfoItem(
                Icons.calendar_today,
                'Session Date',
                '${DateFormat('MMM dd, yyyy').format(request['date'])} at ${request['time']}',
              ),

              // Institution
              _buildDeleteRequestInfoItem(
                Icons.school,
                'Institution',
                request['institution'],
              ),

              // Type
              _buildDeleteRequestInfoItem(
                Icons.category,
                'Session Type',
                request['type'],
              ),

              // Reason
              if (request['reason'] != null && request['reason'].isNotEmpty)
                _buildDeleteRequestInfoItem(
                  Icons.note,
                  'Reason',
                  request['reason'],
                ),

              SizedBox(height: 12),
              Divider(color: Colors.red.withOpacity(0.2)),
              SizedBox(height: 8),

              // Status Message
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.red),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'The session is cancelled.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// ⭐ جديد: عنصر معلومات في طلب الحذف
  Widget _buildDeleteRequestInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: Colors.red),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textGray)),
        trailing: Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 14),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
      ),
    );
  }

  void _completeTodaySessions() async {
    Navigator.pop(context);
    try {
      final result = await SpecialistSessionService.completeTodaySessions();
      await _fetchSessionsFromApi();
      _showSuccessSnackBar('Completed ${result['updatedCount']} sessions for today');
    } catch (e) {
      _showErrorSnackBar('Failed to complete today sessions: $e');
    }
  }

  void _showTodaySessions() {
    setState(() {
      _dateFilterType = 'today';
      _applyFilters();
    });
  }

  void _showUpcomingSessions() {
    setState(() {
      _dateFilterType = 'upcoming';
      _applyFilters();
    });
  }

  void _showMonthlyReport() async {
    Navigator.pop(context);
    try {
      final report = await SpecialistSessionService.getMonthlyReport();
      _showReportDialog(report);
    } catch (e) {
      _showErrorSnackBar('Failed to load monthly report: $e');
    }
  }

  void _showReportDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Monthly Report',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text('Month: ${report['month']}/${report['year']}', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
              SizedBox(height: 12),
              _buildEnhancedReportItem('Total Sessions', report['totalSessions'].toString()),
              _buildEnhancedReportItem('Completed', report['completedSessions'].toString()),
              _buildEnhancedReportItem('Cancelled', report['cancelledSessions'].toString()),
              _buildEnhancedReportItem('Online', report['onlineSessions'].toString()),
              _buildEnhancedReportItem('Onsite', report['onsiteSessions'].toString()),
              _buildEnhancedReportItem('Completion Rate', '${report['completionRate']}%'),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedReportItem(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w500, fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 14)),
        ],
      ),
    );
  }

  void _setReminders() {
    Navigator.pop(context);
    _showSuccessSnackBar('Reminders set for upcoming sessions');
  }
  void _joinZoomSession(Map<String, dynamic> session) async {
    try {
      // إظهار رسالة تحميل أثناء جلب بيانات الزوم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.video_call, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Loading Zoom meeting details...'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      // جلب بيانات الزوم الحقيقية من الباكيند
      final response = await SpecialistSessionService.getZoomMeetingDetails(session['id']);
      final meeting = response['meeting'];

      final meetingId = meeting['meetingId'] ?? '';
      final password = meeting['password'] ?? '';
      final joinUrl = meeting['joinUrl'] ?? '';

      // عرض الحوار مع البيانات الحقيقية
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.video_call, color: Colors.blue, size: 28),
                ),
                SizedBox(height: 12),
                Text(
                  'Join Zoom Session',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                SizedBox(height: 6),
                Text(
                  'Ready to join ${session['childName']}\'s session?',
                  style: TextStyle(color: AppColors.textGray, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildZoomDetailItem(Icons.video_call, 'Meeting ID', meetingId.isNotEmpty ? meetingId : 'Loading...'),
                      _buildZoomDetailItem(Icons.lock, 'joinUrl', joinUrl.isNotEmpty ? joinUrl : 'Loading...'),
                      _buildZoomDetailItem(Icons.access_time, 'Time', session['time']),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textGray,
                            side: BorderSide(color: AppColors.textGray),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // إغلاق الحوار أولاً

                            if (joinUrl.isNotEmpty) {
                              try {
                                print('Attempting to open: $joinUrl');

                                // محاولة فتح الرابط مباشرة في المتصفح
                                bool launched = await launch(
                                  joinUrl,
                                  forceSafariVC: false,
                                  forceWebView: false,
                                  universalLinksOnly: false,
                                );

                                if (launched) {
                                  _showSuccessSnackBar('Opening Zoom meeting...');
                                } else {
                                  // إذا فشل فتح الرابط، اعرض خيار نسخ الرابط
                                  _showCopyLinkDialog(joinUrl, meetingId, password);
                                }
                              } catch (e) {
                                print('Error: $e');
                                // إذا حدث خطأ، اعرض خيار نسخ الرابط
                                _showCopyLinkDialog(joinUrl, meetingId, password);
                              }
                            } else {
                              _showErrorSnackBar('No Zoom meeting link available');
                            }
                          },
                          child: Text('Join Meeting', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to load Zoom details: $e');
    }
  }
  // دالة جديدة لعرض خيار نسخ الرابط
  void _showCopyLinkDialog(String joinUrl, String meetingId, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Zoom Meeting'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please use this information to join the meeting:'),
            SizedBox(height: 15),
            Row(
              children: [
                Icon(Icons.link, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Link:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(
                        joinUrl,
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.video_call, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('Meeting ID: $meetingId', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.lock, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('Password: $password', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'You can copy the link and paste it in your browser',
              style: TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: joinUrl));
              _showSuccessSnackBar('Link copied to clipboard!');
              Navigator.pop(context);
            },
            child: Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Calendar View
  Map<DateTime, List<Map<String, dynamic>>> _groupSessionsByDate() {
    Map<DateTime, List<Map<String, dynamic>>> grouped = {};
    for (var session in sessions) {
      DateTime date = DateTime(session['date'].year, session['date'].month, session['date'].day);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(session);
    }
    return grouped;
  }

  Widget _buildCalendarView() {
    final groupedSessions = _groupSessionsByDate();
    final now = DateTime.now();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCalendarHeader(),
          SizedBox(height: 12),
          _buildMonthView(DateTime(now.year, now.month), groupedSessions),
          SizedBox(height: 16),
          _buildMonthView(DateTime(now.year, now.month + 1), groupedSessions),
          SizedBox(height: 16),
          _buildMonthView(DateTime(now.year, now.month + 2), groupedSessions),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Cancelled session',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          Wrap(
            spacing: 12,
            children: [
              _buildCalendarLegend('Scheduled', AppColors.primary),
              _buildCalendarLegend('Completed', Colors.green),
              _buildCalendarLegend('Today', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarLegend(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: AppColors.textGray, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMonthView(DateTime month, Map<DateTime, List<Map<String, dynamic>>> groupedSessions) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) => Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGray,
                  ),
                ),
              ),
            )).toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: daysInMonth + firstWeekday - 1,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) return SizedBox();

              final day = index - firstWeekday + 2;
              final currentDate = DateTime(month.year, month.month, day);
              final daySessions = groupedSessions[currentDate] ?? [];
              final isToday = _isSameDay(currentDate, DateTime.now());
              final isSelected = _isSameDay(currentDate, selectedDate);
              final hasSessions = daySessions.isNotEmpty;
              final completedCount = daySessions.where((s) => s['status'] == 'Completed').length;
              final totalCount = daySessions.length;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDate = currentDate;
                    _dateFilterType = 'today';
                    _applyFilters();
                    _currentPage = 0;
                  });
                },
                child: Container(
                  margin: EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.orange.withOpacity(0.1)
                        : isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday
                          ? Colors.orange
                          : isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.toString(),
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : isToday
                              ? Colors.orange
                              : AppColors.textDark,
                          fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                          fontSize: (isSelected || isToday) ? 14 : 12,
                        ),
                      ),
                      if (hasSessions) ...[
                        SizedBox(height: 2),
                        Container(
                          height: 3,
                          width: 16,
                          decoration: BoxDecoration(
                            color: completedCount == totalCount ? Colors.green : AppColors.primary,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          '$totalCount',
                          style: TextStyle(
                            fontSize: 8,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // View Toggle
  Widget _buildViewToggle() {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('List View', Icons.list, 0),
          _buildToggleButton('Calendar', Icons.calendar_today, 1),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, IconData icon, int page) {
    final isSelected = _currentPage == page;
    return Expanded(
      child: Material(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _currentPage = page),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.textGray,
                ),
                SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppColors.textGray,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Loading and Empty States
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading sessions...',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today, size: 40, color: AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'No sessions found',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try changing your filters or date',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Container(
            width: 120,
            height: 40,
            child: ElevatedButton(
              onPressed: _fetchSessionsFromApi,
              child: Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Sessions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
            onPressed: _fetchSessionsFromApi,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : CustomScrollView(
        controller: _scrollController,
        slivers: [
          // View Toggle
          SliverToBoxAdapter(
            child: _buildViewToggle(),
          ),

          // Statistics Card
          SliverToBoxAdapter(
            child: _buildStatisticsCard(),
          ),

          // Filters (للصفحة الأولى فقط)
          if (_currentPage == 0)
            SliverToBoxAdapter(
              child: _buildFilters(),
            ),

          // Session List أو Calendar
          if (_currentPage == 0)
            filteredSessions.isEmpty
                ? SliverFillRemaining(
              child: _buildEmptyState(),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildSessionCard(filteredSessions[index]),
                childCount: filteredSessions.length,
              ),
            )
          else
            SliverToBoxAdapter(
              child: _buildCalendarView(),
            ),
        ],
      ),
      floatingActionButton: _currentPage == 0 ? _buildQuickActions() : null,
    );
  }
}