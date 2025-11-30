// lib/screens/comparison_analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/progress_analysis_service.dart';
import '../theme/app_colors.dart';

class ComparisonAnalysisScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ComparisonAnalysisScreen({
    Key? key,
    required this.childId,
    required this.childName,
  }) : super(key: key);

  @override
  State<ComparisonAnalysisScreen> createState() => _ComparisonAnalysisScreenState();
}

class _ComparisonAnalysisScreenState extends State<ComparisonAnalysisScreen> {
  // State variables
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPeriod = 'last_month';

  Map<String, dynamic>? _dateComparisonResult;
  Map<String, dynamic>? _periodAnalysisResult;

  bool _isComparingDates = false;
  bool _isAnalyzingPeriod = false;
  String _errorMessage = '';

  // Available periods
  final List<Map<String, String>> _periods = [
    {'value': 'last_week', 'label': 'Last Week', 'icon': '📅'},
    {'value': 'last_month', 'label': 'Last Month', 'icon': '📊'},
    {'value': 'last_3_months', 'label': 'Last 3 Months', 'icon': '📈'},
    {'value': 'last_6_months', 'label': 'Last 6 Months', 'icon': '🏆'},
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentEvaluations();
  }

  Future<void> _loadRecentEvaluations() async {
    try {
      final evaluations = await ProgressAnalysisService.getRecentEvaluations(widget.childId);
      if (evaluations.isNotEmpty) {
        final firstDate = DateTime.parse(evaluations.first['date']?.toString() ?? '');
        final lastDate = DateTime.parse(evaluations.last['date']?.toString() ?? '');

        setState(() {
          _startDate = firstDate;
          _endDate = lastDate;
        });
      }
    } catch (e) {
      print('Failed to load recent evaluations: $e');
    }
  }

  // 🔥 مقارنة بين تاريخين
  Future<void> _compareDates() async {
    if (_startDate == null || _endDate == null) {
      _showError('Please select both start and end dates');
      return;
    }

    if (_startDate!.isAfter(_endDate!)) {
      _showError('Start date must be before end date');
      return;
    }

    try {
      setState(() {
        _isComparingDates = true;
        _errorMessage = '';
        _dateComparisonResult = null;
      });

      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);

      final result = await ProgressAnalysisService.compareDateRangeProgress(
        widget.childId,
        startDate: startDateStr,
        endDate: endDateStr,
      );

      setState(() {
        _dateComparisonResult = result;
      });
    } catch (e) {
      _showError('Failed to compare dates: $e');
    } finally {
      setState(() {
        _isComparingDates = false;
      });
    }
  }

  // 📊 تحليل فترة محددة
  Future<void> _analyzePeriod() async {
    try {
      setState(() {
        _isAnalyzingPeriod = true;
        _errorMessage = '';
        _periodAnalysisResult = null;
      });

      final result = await ProgressAnalysisService.analyzePeriodProgress(
        widget.childId,
        period: _selectedPeriod,
      );

      setState(() {
        _periodAnalysisResult = result;
      });
    } catch (e) {
      _showError('Failed to analyze period: $e');
    } finally {
      setState(() {
        _isAnalyzingPeriod = false;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _clearResults() {
    setState(() {
      _dateComparisonResult = null;
      _periodAnalysisResult = null;
      _errorMessage = '';
    });
  }

  // ========== UI COMPONENTS ==========

  Widget _buildDateComparisonSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.compare_arrows, color: AppColors.info, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Compare Specific Dates',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            Text(
              'Select two specific dates to compare progress between them',
              style: TextStyle(
                color: AppColors.textGray,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 24),

            // Date Selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildDatePicker(
                        _startDate,
                        'Select Start Date',
                            (date) => setState(() => _startDate = date),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildDatePicker(
                        _endDate,
                        'Select End Date',
                            (date) => setState(() => _endDate = date),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Compare Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isComparingDates ? null : _compareDates,
                icon: _isComparingDates
                    ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(Icons.compare_arrows, size: 20),
                label: Text(
                  _isComparingDates ? 'Comparing...' : 'Compare Dates',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(DateTime? selectedDate, String hint, Function(DateTime) onDateSelected) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.surface,
                  onSurface: AppColors.textDark,
                ),
                dialogBackgroundColor: AppColors.surface,
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          onDateSelected(date);
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent2),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat('MMM dd, yyyy').format(selectedDate)
                    : hint,
                style: TextStyle(
                  color: selectedDate != null ? AppColors.textDark : AppColors.textLight,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodAnalysisSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.timeline, color: AppColors.success, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Analyze Time Periods',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            Text(
              'Quick analysis for standard time periods',
              style: TextStyle(
                color: AppColors.textGray,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 24),

            // Period Selection Grid
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: _periods.length,
              itemBuilder: (context, index) {
                final period = _periods[index];
                final isSelected = _selectedPeriod == period['value'];

                return InkWell(
                  onTap: () => setState(() => _selectedPeriod = period['value']!),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.accent2,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        )
                      ] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(period['icon']!, style: TextStyle(fontSize: 20)),
                        SizedBox(height: 6),
                        Text(
                          period['label']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? AppColors.primary : AppColors.textGray,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 24),

            // Analyze Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzingPeriod ? null : _analyzePeriod,
                icon: _isAnalyzingPeriod
                    ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(Icons.analytics, size: 20),
                label: Text(
                  _isAnalyzingPeriod ? 'Analyzing...' : 'Analyze Period',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_dateComparisonResult == null && _periodAnalysisResult == null) {
      return SizedBox();
    }

    return Column(
      children: [
        if (_dateComparisonResult != null)
          _buildDateComparisonResults(_dateComparisonResult!),

        if (_periodAnalysisResult != null)
          _buildPeriodAnalysisResults(_periodAnalysisResult!),

        SizedBox(height: 20),

        Center(
          child: OutlinedButton.icon(
            onPressed: _clearResults,
            icon: Icon(Icons.clear, size: 18),
            label: Text(
              'Clear Results',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textGray,
              side: BorderSide(color: AppColors.textLight),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateComparisonResults(Map<String, dynamic> result) {
    final comparison = result['direct_comparison'];
    final improvement = comparison?['improvement'];
    final aiAnalysis = result['ai_direct_comparison'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.fact_check, color: AppColors.info, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Date Comparison Results',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Improvement Summary
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.info.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    '${improvement?['score_change'] ?? 0} Points Change',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.info,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${improvement?['percentage_change']?.toStringAsFixed(1) ?? '0'}% Improvement',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getTrendColor(improvement?['trend']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      improvement?['trend'] ?? 'Stable',
                      style: TextStyle(
                        color: _getTrendTextColor(improvement?['trend']),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // AI Analysis Summary
            if (aiAnalysis != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Analysis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent1),
                    ),
                    child: Text(
                      aiAnalysis['direct_comparison_summary']?['overview'] ?? 'No analysis available',
                      style: TextStyle(
                        color: AppColors.textGray,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodAnalysisResults(Map<String, dynamic> result) {
    final period = result['period'];
    final overview = result['overview'];
    final aiAnalysis = result['ai_period_analysis'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.timeline, color: AppColors.success, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Period Analysis Results',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Period Summary
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Period',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          period?['type']?.toString().replaceAll('_', ' ') ?? 'N/A',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluations',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          overview?['total_evaluations']?.toString() ?? '0',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avg Score',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          overview?['average_score']?.toString() ?? 'N/A',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // AI Analysis
            if (aiAnalysis != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Period Assessment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent1),
                    ),
                    child: Text(
                      aiAnalysis['period_overview']?['summary'] ?? 'No analysis available',
                      style: TextStyle(
                        color: AppColors.textGray,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getTrendColor(String? trend) {
    switch (trend?.toLowerCase()) {
      case 'improving':
        return AppColors.success.withOpacity(0.2);
      case 'declining':
        return AppColors.error.withOpacity(0.2);
      default:
        return AppColors.warning.withOpacity(0.2);
    }
  }

  Color _getTrendTextColor(String? trend) {
    switch (trend?.toLowerCase()) {
      case 'improving':
        return AppColors.success;
      case 'declining':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Comparison Analysis - ${widget.childName}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Error Message
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Date Comparison Section
            _buildDateComparisonSection(),
            SizedBox(height: 24),

            // Period Analysis Section
            _buildPeriodAnalysisSection(),
            SizedBox(height: 24),

            // Results Section
            _buildResultsSection(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}