import 'package:flutter/material.dart';
import 'package:frontend/services/manager_financial_service.dart';
import '../../theme/app_colors.dart';

class ManagerFinancialRequestsScreen extends StatefulWidget {
  const ManagerFinancialRequestsScreen({super.key});

  @override
  State<ManagerFinancialRequestsScreen> createState() => _ManagerFinancialRequestsScreenState();
}

class _ManagerFinancialRequestsScreenState extends State<ManagerFinancialRequestsScreen> {
  int _activeTabIndex = 0;

  // General financial assistance requests (existing)
  bool _isLoading = true;
  String _statusFilter = 'submitted';
  List<dynamic> _requests = [];
  Map<String, dynamic>? _statistics;

  // Session-level aid requests (new)
  bool _isSessionAidLoading = true;
  String _sessionAidStatusFilter = 'under_review';
  List<dynamic> _sessionAidRequests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _loadSessionAidRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ManagerFinancialService.getFinancialRequests(status: _statusFilter);
      setState(() {
        _requests = data['data'] ?? [];
        _statistics = data['statistics'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadSessionAidRequests() async {
    setState(() {
      _isSessionAidLoading = true;
    });

    try {
      final data = await ManagerFinancialService.getSessionAidRequests(
        status: _sessionAidStatusFilter,
      );
      setState(() {
        _sessionAidRequests = data['data'] ?? [];
        _isSessionAidLoading = false;
      });
    } catch (e) {
      setState(() {
        _isSessionAidLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleSessionAidAction(
    Map<String, dynamic> request,
    String action,
  ) async {
    final dynamic id = request['request_id'];
    final int? requestId = id is int ? id : int.tryParse(id?.toString() ?? '');
    if (requestId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid request id'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    double? approvedPercentage;
    double? approvedAmount;
    String? decisionNotes;

    if (action != 'reject') {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          final percentController = TextEditingController();
          final amountController = TextEditingController();
          final notesController = TextEditingController();

          return AlertDialog(
            title: const Text('Review Session Aid Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: percentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Approved percentage (optional)',
                    hintText: 'e.g. 50',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Approved amount (optional)',
                    hintText: 'e.g. 20',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Decision notes (optional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  approvedPercentage =
                      double.tryParse(percentController.text.trim());
                  approvedAmount = double.tryParse(amountController.text.trim());
                  decisionNotes = notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim();
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );

      if (result != true) return;
    }

    try {
      await ManagerFinancialService.reviewSessionAidRequest(
        requestId: requestId,
        action: action,
        approvedPercentage: approvedPercentage,
        approvedAmount: approvedAmount,
        decisionNotes: decisionNotes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request $action successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      setState(() {
        if (action == 'reject') {
          _sessionAidStatusFilter = 'rejected';
        } else {
          _sessionAidStatusFilter = 'approved';
        }
      });

      await _loadSessionAidRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleAction(Map<String, dynamic> request, String action) async {
    final requestId = request['request_id'] as int;

    try {
      await ManagerFinancialService.reviewFinancialRequest(
        requestId: requestId,
        action: action,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request $action successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      // بعد تغيير حالة الطلب، نغيّر الفلتر تلقائياً ليطابق الحالة الجديدة
      // حتى يبقى الطلب ظاهراً في القائمة ولا يختفي من تبويب "submitted"
      setState(() {
        if (action == 'approve') {
          _statusFilter = 'approved';
        } else if (action == 'reject') {
          _statusFilter = 'rejected';
        }
        // في حالة request_documents نترك الفلتر كما هو
      });

      await _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Financial Assistance Requests'),
          backgroundColor: AppColors.primary,
          bottom: TabBar(
            onTap: (i) {
              setState(() {
                _activeTabIndex = i;
              });
            },
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Financial Requests'),
              Tab(text: 'Session Aid Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRequests,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 12),
                        ..._requests.map(_buildRequestCard).toList(),
                        if (_requests.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Text(
                                'No financial assistance requests found',
                                style: TextStyle(color: AppColors.textLight),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
            _isSessionAidLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _loadSessionAidRequests,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSessionAidHeader(),
                        const SizedBox(height: 12),
                        ..._sessionAidRequests
                            .map(_buildSessionAidRequestCard)
                            .toList(),
                        if (_sessionAidRequests.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Text(
                                'No session aid requests found',
                                style: TextStyle(color: AppColors.textLight),
                              ),
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

  Widget _buildSessionAidHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Requests (${_sessionAidRequests.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        DropdownButton<String>(
          value: _sessionAidStatusFilter,
          items: const [
            DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
            DropdownMenuItem(value: 'approved', child: Text('Approved')),
            DropdownMenuItem(value: 'partial_approved', child: Text('Partial Approved')),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            DropdownMenuItem(value: 'all', child: Text('All')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _sessionAidStatusFilter = value;
            });
            _loadSessionAidRequests();
          },
        ),
      ],
    );
  }

  Widget _buildSessionAidRequestCard(dynamic request) {
    final status = request['status']?.toString() ?? 'under_review';
    final approvedAmount = request['approved_amount'];
    final approvedPercentage = request['approved_percentage'];
    final notes = request['notes']?.toString();

    final child = request['child'];
    final parent = request['parent'];
    final session = request['session'];

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = AppColors.success;
        break;
      case 'partial_approved':
        statusColor = AppColors.warning;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.primary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (child is Map && child['full_name'] != null)
                            ? child['full_name'].toString()
                            : 'Unknown Child',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (parent is Map && parent['full_name'] != null)
                            ? parent['full_name'].toString()
                            : 'Unknown Parent',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (session is Map) ...[
              Text(
                'Session ID: ${session['session_id'] ?? '-'}',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              if (session['status'] != null)
                Text(
                  'Session status: ${session['status']}',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
            ],
            if (approvedAmount != null || approvedPercentage != null) ...[
              const SizedBox(height: 4),
              Text(
                'Approved: ${approvedPercentage != null ? '${approvedPercentage.toString()}%' : '-'} | Amount: ${approvedAmount ?? '-'}',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Notes: $notes',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: (status == 'approved' ||
                          status == 'partial_approved' ||
                          status == 'rejected')
                      ? null
                      : () => _handleSessionAidAction(
                            Map<String, dynamic>.from(request),
                            'reject',
                          ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (status == 'approved' ||
                          status == 'partial_approved' ||
                          status == 'rejected')
                      ? null
                      : () => _handleSessionAidAction(
                            Map<String, dynamic>.from(request),
                            'approve',
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: (status == 'approved' ||
                          status == 'partial_approved' ||
                          status == 'rejected')
                      ? null
                      : () => _handleSessionAidAction(
                            Map<String, dynamic>.from(request),
                            'partial_approve',
                          ),
                  child: const Text('Partial'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final stats = _statistics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Requests (${_requests.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            DropdownButton<String>(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem(value: 'all', child: Text('All')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _statusFilter = value;
                });
                _loadRequests();
              },
            ),
          ],
        ),
        if (stats != null) ...[
          const SizedBox(height: 8),
          Text(
            'Pending review: ${stats['pending_review'] ?? 0}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRequestCard(dynamic request) {
    final parent = request['parent'] ?? {};
    final child = request['child'] ?? {};
    final financial = request['financial_assessment'] ?? {};
    final details = request['request_details'] ?? {};
    final urgency = request['urgency'] ?? {};

    final status = details['status']?.toString() ?? 'submitted';
    final autoGenerated = details['auto_generated'] == true;

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = AppColors.success;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        break;
      case 'pending_documents':
        statusColor = AppColors.warning;
        break;
      default:
        statusColor = AppColors.primary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child['name']?.toString() ?? 'Unknown Child',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parent['name']?.toString() ?? 'Unknown Parent',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.stacked_line_chart, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Score: ${financial['score'] ?? '-'} | Tier: ${financial['tier_label'] ?? financial['tier'] ?? '-'}',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.percent, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Requested: ${details['requested_discount'] ?? '-'} | Sessions: ${details['requested_sessions'] ?? '-'}',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (urgency['level'] != null)
              Row(
                children: [
                  Icon(Icons.priority_high, size: 16, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Urgency: ${urgency['level']}',
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ],
              ),
            if (autoGenerated) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text(
                    'Auto-generated from child registration',
                    style: TextStyle(fontSize: 11, color: AppColors.info),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: status == 'approved' || status == 'rejected'
                      ? null
                      : () => _handleAction(request, 'request_documents'),
                  child: const Text('Request Docs'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: status == 'approved'
                      ? null
                      : () => _handleAction(request, 'reject'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: status == 'approved'
                      ? null
                      : () => _handleAction(request, 'approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
