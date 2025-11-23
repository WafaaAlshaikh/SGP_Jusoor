// lib/screens/comparison_analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/progress_analysis_service.dart';

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
        content: Text(message),
        backgroundColor: Colors.red,
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Text(
                  'Compare Specific Dates',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            Text(
              'Select two specific dates to compare progress between them',
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            SizedBox(height: 20),

            // Date Selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Date', style: TextStyle(fontWeight: FontWeight.w500)),
                      SizedBox(height: 8),
                      _buildDatePicker(
                        _startDate,
                        'Select Date',
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
                      Text('End Date', style: TextStyle(fontWeight: FontWeight.w500)),
                      SizedBox(height: 8),
                      _buildDatePicker(
                        _endDate,
                        'Select Date',
                            (date) => setState(() => _endDate = date),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Compare Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isComparingDates ? null : _compareDates,
                icon: _isComparingDates
                    ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.compare_arrows),
                label: Text(_isComparingDates ? 'Comparing...' : 'Compare Dates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF7815A0),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        );
        if (date != null) {
          onDateSelected(date);
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
            SizedBox(width: 12),
            Text(
              selectedDate != null
                  ? DateFormat('MMM dd, yyyy').format(selectedDate)
                  : hint,
              style: TextStyle(
                color: selectedDate != null ? Colors.black87 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodAnalysisSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Text(
                  'Analyze Time Periods',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            Text(
              'Quick analysis for standard time periods',
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            SizedBox(height: 20),

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
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Color(0xFF7815A0).withOpacity(0.1) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Color(0xFF7815A0) : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(period['icon']!, style: TextStyle(fontSize: 20)),
                        SizedBox(height: 4),
                        Text(
                          period['label']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Color(0xFF7815A0) : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20),

            // Analyze Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzingPeriod ? null : _analyzePeriod,
                icon: _isAnalyzingPeriod
                    ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.analytics),
                label: Text(_isAnalyzingPeriod ? 'Analyzing...' : 'Analyze Period'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF7815A0),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

        SizedBox(height: 16),

        Center(
          child: OutlinedButton.icon(
            onPressed: _clearResults,
            icon: Icon(Icons.clear),
            label: Text('Clear Results'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: BorderSide(color: Colors.grey),
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Text(
                  'Date Comparison Results',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Improvement Summary
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[50]!, Colors.lightBlue[50]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${improvement?['score_change'] ?? 0} Points Change',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${improvement?['percentage_change']?.toStringAsFixed(1) ?? '0'}% Improvement',
                    style: TextStyle(fontSize: 16, color: Colors.blue[600]),
                  ),
                  SizedBox(height: 8),
                  Chip(
                    label: Text(improvement?['trend'] ?? 'Stable'),
                    backgroundColor: _getTrendColor(improvement?['trend']),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // AI Analysis Summary
            if (aiAnalysis != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    aiAnalysis['direct_comparison_summary']?['overview'] ?? 'No analysis available',
                    style: TextStyle(color: Colors.grey[700], height: 1.4),
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Text(
                  'Period Analysis Results',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Period Summary
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Period', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(period?['type']?.toString().replaceAll('_', ' ') ?? 'N/A'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Evaluations', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(overview?['total_evaluations']?.toString() ?? '0'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Avg Score', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(overview?['average_score']?.toString() ?? 'N/A'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // AI Analysis
            if (aiAnalysis != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Period Assessment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    aiAnalysis['period_overview']?['summary'] ?? 'No analysis available',
                    style: TextStyle(color: Colors.grey[700], height: 1.4),
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
        return Colors.green[100]!;
      case 'declining':
        return Colors.red[100]!;
      default:
        return Colors.orange[100]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Comparison Analysis - ${widget.childName}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF7815A0),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Error Message
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(child: Text(_errorMessage, style: TextStyle(color: Colors.red[800]))),
                  ],
                ),
              ),

            // Date Comparison Section
            _buildDateComparisonSection(),
            SizedBox(height: 20),

            // Period Analysis Section
            _buildPeriodAnalysisSection(),
            SizedBox(height: 20),

            // Results Section
            _buildResultsSection(),
          ],
        ),
      ),
    );
  }
}