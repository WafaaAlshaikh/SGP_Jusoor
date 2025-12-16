// screens/financial_assistance_dashboard.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/FinancialAssistanceRequestModel.dart';
import '../models/ParentFinancialModel.dart';
import '../models/financial_assessment_models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'general_assessment_screen.dart'; // شاشة التقييم العام الجديدة

class FinancialAssistanceDashboard extends StatefulWidget {
  const FinancialAssistanceDashboard({super.key});

  @override
  State<FinancialAssistanceDashboard> createState() =>
      _FinancialAssistanceDashboardState();
}

class _FinancialAssistanceDashboardState
    extends State<FinancialAssistanceDashboard> {
  ParentFinancialModel? _parentFinancial;
  List<FinancialAssistanceRequest> _activeRequests = [];
  List<FinancialAssistanceRequest> _completedRequests = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // NEW: حالة التقييم العام
  GeneralAssessmentResult? _generalAssessment;
  bool _hasValidAssessment = false;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Load parent financial profile
      final profileResponse = await ApiService.getParentFinancialProfile(token);
      if (profileResponse['success'] == true) {
        final parentFinancial = ParentFinancialModel.fromJson(profileResponse['data']);
        
        setState(() {
          _parentFinancial = parentFinancial;
          _hasValidAssessment = parentFinancial.hasValidFinancialAssessment;
        });
      }

      // في _loadFinancialData()، أضف بعد تحميل الـ profile:
if (_parentFinancial != null && _parentFinancial!.hasValidFinancialAssessment) {
  // تحميل المؤسسات الموصى بها
  try {
    final institutionsResponse = await ApiService.getRecommendedInstitutionsByTier(
      token,
      _parentFinancial!.financialTier,
      _parentFinancial!.financialScore.toDouble(),
    );
    
    if (institutionsResponse['success'] == true) {
      // يمكن حفظ المؤسسات في state إذا أردت عرضها
      print('✅ Loaded ${institutionsResponse['data']?.length ?? 0} recommended institutions');
    }
  } catch (e) {
    print('⚠️ Could not load recommended institutions: $e');
  }
}

      // Load active requests
      final requestsResponse = await ApiService.getFinancialAssistanceRequests(token);
      if (requestsResponse['success'] == true) {
        final List<dynamic> data = requestsResponse['data'] ?? [];
        final requests = data.map((r) => FinancialAssistanceRequest.fromJson(r)).toList();

        setState(() {
          _activeRequests = requests.where((r) => r.isPending).toList();
          _completedRequests = requests.where((r) => !r.isPending).toList();
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load financial data: $e';
      });
    }
  }

  // NEW: بطاقة التقييم المالي العام
  Widget _buildGeneralAssessmentCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.assessment,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Financial Assessment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Check your eligibility in 3-5 minutes',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Get an instant estimate of what financial assistance you might qualify for before choosing a child or institution.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GeneralFinancialAssessmentScreen(),
                        ),
                      );
                      if (result == true) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: Text('Start Assessment'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GeneralFinancialAssessmentScreen(),
                        ),
                      );
                      if (result == true) {
                        Navigator.pop(context, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text('Learn More'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialScoreCard() {
    if (_parentFinancial == null) return SizedBox();

    final hasAssessment = _parentFinancial!.hasValidFinancialAssessment;
    final daysRemaining = _parentFinancial!.daysRemainingForAssessment;
    final assessmentStatus = hasAssessment 
        ? (daysRemaining > 0 ? 'Valid for $daysRemaining days' : 'Expired')
        : 'Not completed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasAssessment
              ? [
                  Color(0xFF10B981), // Green for valid
                  Color(0xFF059669),
                ]
              : [
                  Color(0xFF667eea), // Blue for no assessment
                  Color(0xFF764ba2),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasAssessment ? Icons.verified : Icons.assessment,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      assessmentStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasAssessment && daysRemaining > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _parentFinancial!.tierLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20),
          
          if (hasAssessment)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Financial Score',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_parentFinancial!.financialScore}/100',
                          style: TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Discount Range',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _parentFinancial!.discountRange,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _parentFinancial!.financialScore / 100,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  color: Colors.white,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 20, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _parentFinancial!.tierRecommendation,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.assessment_outlined,
                        size: 48,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No Financial Assessment Yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Complete a financial assessment to see your eligibility and discount range.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GeneralFinancialAssessmentScreen(),
                      ),
                    );
                    if (result == true) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Start Assessment',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestsSection() {
    if (_activeRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: AppColors.success),
            SizedBox(height: 12),
            Text(
              'No Active Requests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You don\'t have any pending financial assistance requests.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 16),
            if (_hasValidAssessment)
              ElevatedButton(
                onPressed: _showRequestOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: Text('Start New Request'),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Requests (${_activeRequests.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            if (_hasValidAssessment)
              TextButton(
                onPressed: _showRequestOptions,
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 4),
                    Text('New Request'),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: 12),
        ..._activeRequests
            .map((request) => _buildRequestCard(request))
            .toList(),
      ],
    );
  }

  Widget _buildRequestCard(FinancialAssistanceRequest request) {
    final statusColor = Color(int.parse(request.statusColor.substring(1, 7), radix: 16) + 0xFF000000);
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(request.status),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.referenceNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Submitted: ${_formatDate(request.submittedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
                ],
              ),
              SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey[200]),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discount',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${request.requestedDiscountPercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessions',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${request.requestedSessionsCount}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '\$${request.requestedTotalAmount.toStringAsFixed(0)}',
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
              SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      request.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (request.requiresDocuments && request.documentsSubmitted == null)
                    Container(
                      margin: EdgeInsets.only(left: 8),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.description, size: 12, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text(
                            'Docs Required',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: [
              _buildQuickActionButton(
                icon: Icons.assessment,
                label: 'Quick Assessment',
                color: AppColors.primary,
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GeneralFinancialAssessmentScreen(),
                    ),
                  );
                  if (result == true) {
                    Navigator.pop(context, true);
                  }
                },
              ),
              _buildQuickActionButton(
                icon: Icons.request_quote,
                label: 'Request Assistance',
                color: AppColors.info,
                onTap: _showRequestOptions,
                enabled: _hasValidAssessment,
              ),
              _buildQuickActionButton(
                icon: Icons.history,
                label: 'Request History',
                color: AppColors.success,
                onTap: _viewRequestHistory,
              ),
              _buildQuickActionButton(
                icon: Icons.help,
                label: 'Help & FAQ',
                color: AppColors.warning,
                onTap: _showHelpDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!enabled)
                  Icon(Icons.lock_outline, size: 14, color: AppColors.textGray),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentStatus() {
    if (_parentFinancial == null || !_hasValidAssessment) return SizedBox();
    
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent3),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user,
            color: AppColors.success,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Assessment Valid',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your assessment is valid for ${_parentFinancial!.daysRemainingForAssessment} more days',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              // View assessment details
              _showAssessmentDetails();
            },
            child: Text('View Details'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'pending_documents':
        return Icons.description;
      case 'under_review':
        return Icons.hourglass_empty;
      case 'rejected':
        return Icons.cancel;
      case 'partially_approved':
        return Icons.done_all;
      default:
        return Icons.pending;
    }
  }

  void _viewRequestDetails(FinancialAssistanceRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              request.referenceNumber,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(int.parse(request.statusColor.substring(1, 7), radix: 16) + 0xFF000000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                request.statusLabel,
                style: TextStyle(
                  color: Color(int.parse(request.statusColor.substring(1, 7), radix: 16) + 0xFF000000),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 20),
            
            // Assessment Type
            if (request.assessmentType != null)
              _buildDetailItem('Assessment Type', request.assessmentType!, '#6B7280'),
            
            // Financial Details
            _buildDetailItem('Requested Discount', '${request.requestedDiscountPercentage}%', '#3B82F6'),
            
            if (request.approvedDiscountPercentage != null)
              _buildDetailItem('Approved Discount', '${request.approvedDiscountPercentage}%', '#10B981'),
            
            _buildDetailItem('Requested Sessions', '${request.requestedSessionsCount} sessions', '#6B7280'),
            
            if (request.approvedSessionsCount != null)
              _buildDetailItem('Approved Sessions', '${request.approvedSessionsCount} sessions', '#10B981'),
            
            _buildDetailItem(
              'Total Amount',
              '\$${request.requestedTotalAmount.toStringAsFixed(2)}',
              '#6B7280'
            ),
            
            if (request.approvedTotalAmount != null)
              _buildDetailItem(
                'Approved Amount',
                '\$${request.approvedTotalAmount!.toStringAsFixed(2)}',
                '#10B981'
              ),
            
            if (request.estimatedSavings > 0)
              _buildDetailItem(
                'Estimated Savings',
                '\$${request.estimatedSavings.toStringAsFixed(2)}',
                '#F59E0B'
              ),
            
            // Timeline
            _buildDetailItem('Submitted', _formatDateTime(request.submittedAt), '#6B7280'),
            
            if (request.decisionDate != null)
              _buildDetailItem('Decision Date', _formatDateTime(request.decisionDate!), '#6B7280'),
            
            // Notes
            if (request.decisionNotes != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Text(
                    'Decision Notes:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    request.decisionNotes!,
                    style: TextStyle(color: AppColors.textGray),
                  ),
                ],
              ),
            
            SizedBox(height: 20),
            
            // Actions based on status
            if (request.requiresDocuments && request.documentsSubmitted == null)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Navigate to document upload
                },
                child: Text('Upload Documents'),
              ),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, String colorHex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showRequestOptions() {
    if (!_hasValidAssessment) {
      _showAssessmentRequiredDialog();
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Request Financial Assistance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 20),
              
              ListTile(
                leading: Icon(Icons.child_care, color: AppColors.primary),
                title: Text('Apply to Existing Child'),
                subtitle: Text('Use your current assessment for a specific child'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to child selection for applying assessment
                },
              ),
              
              ListTile(
                leading: Icon(Icons.assessment, color: AppColors.info),
                title: Text('New Child Assessment'),
                subtitle: Text('Complete assessment for a new child'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to new child assessment
                },
              ),
              
              ListTile(
                leading: Icon(Icons.compare_arrows, color: AppColors.success),
                title: Text('Compare Institutions'),
                subtitle: Text('See which institutions offer the best rates'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to institution comparison
                },
              ),
              
              SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewRequestHistory() {
    if (_completedRequests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No completed requests found'),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Request History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _completedRequests.length,
                itemBuilder: (context, index) {
                  final request = _completedRequests[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        _getStatusIcon(request.status),
                        color: Color(int.parse(request.statusColor.substring(1, 7), radix: 16) + 0xFF000000),
                      ),
                      title: Text(request.referenceNumber),
                      subtitle: Text(
                        '${request.statusLabel} - ${_formatDate(request.submittedAt)}',
                      ),
                      trailing: Text(
                        '${request.requestedDiscountPercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _viewRequestDetails(request);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Financial Assistance FAQ'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFAQItem(
                'What is financial assistance?',
                'Financial assistance helps families who cannot afford full therapy costs by providing discounts or free sessions.',
              ),
              _buildFAQItem(
                'How is eligibility determined?',
                'Based on financial assessment score, family size, income, employment status, and special circumstances.',
              ),
              _buildFAQItem(
                'What is a general assessment?',
                'A quick 3-5 minute assessment that gives you an estimated discount range before choosing a child or institution.',
              ),
              _buildFAQItem(
                'How long is the assessment valid?',
                'Financial assessments are valid for 30 days from completion.',
              ),
              _buildFAQItem(
                'What documents are required?',
                'Proof of income, ID, and other supporting documents may be required for discounts above 50%.',
              ),
              _buildFAQItem(
                'How long does approval take?',
                'Typically 3-7 business days. Urgent cases may be processed faster.',
              ),
            ],
          ),
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
  
  void _showAssessmentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About Financial Assessment'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A financial assessment helps determine what level of assistance you might qualify for.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              _buildInfoItem('📊', 'Takes 3-5 minutes'),
              _buildInfoItem('🔒', 'Your information is kept confidential'),
              _buildInfoItem('🎯', 'Get an estimated discount range'),
              _buildInfoItem('📅', 'Valid for 30 days'),
              _buildInfoItem('👶', 'Apply to multiple children'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }
  
  void _showAssessmentRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assessment Required'),
        content: Text(
          'You need to complete a financial assessment before requesting assistance. '
          'This helps determine your eligibility and discount range.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GeneralFinancialAssessmentScreen(),
                ),
              );
            },
            child: Text('Start Assessment'),
          ),
        ],
      ),
    );
  }
  
  void _showAssessmentDetails() {
    if (_parentFinancial == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assessment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAssessmentDetailItem('Financial Score', '${_parentFinancial!.financialScore}/100'),
              _buildAssessmentDetailItem('Tier', _parentFinancial!.tierLabel),
              _buildAssessmentDetailItem('Discount Range', _parentFinancial!.discountRange),
              _buildAssessmentDetailItem('Priority Level', _parentFinancial!.priorityLevel),
              _buildAssessmentDetailItem('Credibility Score', '${_parentFinancial!.credibilityScore}/100'),
              if (_parentFinancial!.lastFinancialAssessment != null)
                _buildAssessmentDetailItem('Last Assessment', _formatDate(_parentFinancial!.lastFinancialAssessment!)),
              _buildAssessmentDetailItem('Days Remaining', '${_parentFinancial!.daysRemainingForAssessment} days'),
              
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 16),
              
              Text(
                'Recommendation:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(_parentFinancial!.tierRecommendation),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GeneralFinancialAssessmentScreen(),
                ),
              );
            },
            child: Text('Renew Assessment'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 18)),
          SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
  
  Widget _buildAssessmentDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: AppColors.primary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Financial Assistance'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadFinancialData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textGray),
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFinancialData,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFinancialData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NEW: General Assessment Card
                        _buildGeneralAssessmentCard(),
                        SizedBox(height: 20),
                        
                        // Financial Score Card
                        _buildFinancialScoreCard(),
                        SizedBox(height: 20),
                        
                        // Assessment Status (if valid)
                        if (_hasValidAssessment) _buildAssessmentStatus(),
                        
                        // Quick Actions
                        _buildQuickActions(),
                        SizedBox(height: 24),
                        
                        // Active Requests
                        _buildActiveRequestsSection(),
                        SizedBox(height: 24),
                        
                        // Completed Requests
                        if (_completedRequests.isNotEmpty) ...[
                          Text(
                            'Completed Requests (${_completedRequests.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 12),
                          ..._completedRequests
                              .map((request) => _buildRequestCard(request))
                              .toList(),
                          SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: _viewRequestHistory,
                              child: Text('View All History'),
                            ),
                          ),
                        ],
                        SizedBox(height: 32),
                        
                        // Footer Info
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 20, color: AppColors.info),
                                  SizedBox(width: 8),
                                  Text(
                                    'Need Help?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'For questions about financial assistance, contact our support team at support@therapy.com or call +1-800-HELP-NOW.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: _hasValidAssessment
          ? FloatingActionButton.extended(
              onPressed: _showRequestOptions,
              icon: Icon(Icons.add),
              label: Text('New Request'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }
}