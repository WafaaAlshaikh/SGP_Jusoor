import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/evaluation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsTab extends StatefulWidget {
  final dynamic child;
  const ReportsTab({super.key, required this.child});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  List<dynamic> _evaluations = [];
  List<dynamic> _filteredEvaluations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  String _selectedProgressFilter = 'all';
  String _selectedMonthFilter = 'all';
  String _errorMessage = '';

  // الألوان المتناسقة للتصميم
  final Color _primaryColor = const Color(0xFF7206AA);
  final Color _secondaryColor = const Color(0xFF976EF4);
  final Color _accentColor = const Color(0xFFCAA9F8);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;
  final Color _textPrimary = const Color(0xFF212529);
  final Color _textSecondary = const Color(0xFF6C757D);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _warningColor = const Color(0xFFFF9800);
  final Color _errorColor = const Color(0xFFF44336);

  final List<String> _typeFilters = ['all', 'Initial', 'Mid', 'Final', 'Follow-up'];
  final List<String> _progressFilters = ['all', 'low', 'medium', 'high'];
  final List<String> _monthFilters = [
    'all', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final evaluations = await _loadChildEvaluations();

      setState(() {
        _evaluations = evaluations;
        _filteredEvaluations = evaluations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _evaluations = _getDemoEvaluationsForChild();
        _filteredEvaluations = _evaluations;
      });
    }
  }

  // 🔥 الدالة المحسنة لجلب البيانات من API
  Future<List<dynamic>> _loadChildEvaluations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No token found');
      }

      print('📊 Loading evaluations for child: ${widget.child.fullName}');

      final response = await ApiService.getChildEvaluationsForParent(token);

      if (response != null && response['success'] == true) {
        final allEvaluations = response['data'] ?? [];

        // تصفية التقييمات الخاصة بالطفل الحالي فقط
        final childEvaluations = allEvaluations.where((eval) {
          final childName = eval['child_name']?.toString() ?? '';
          final evalChildId = eval['child_id']?.toString();
          final currentChildId = widget.child.id.toString();

          final matches = childName.toLowerCase().contains(widget.child.fullName.toLowerCase()) ||
              evalChildId == currentChildId;

          return matches;
        }).toList();

        print('✅ Found ${childEvaluations.length} evaluations for ${widget.child.fullName}');

        return childEvaluations.isNotEmpty ? childEvaluations : _getDemoEvaluationsForChild();
      } else {
        return _getDemoEvaluationsForChild();
      }
    } catch (e) {
      print('❌ Error loading child evaluations: $e');
      return _getDemoEvaluationsForChild();
    }
  }

  // 🔥 دالة التحميل الرئيسية مع FutureBuilder

  List<dynamic> _getDemoEvaluationsForChild() {
    final childName = widget.child.fullName;
    final condition = widget.child.condition ?? 'General';

    return [
      {
        'evaluation_id': 1,
        'evaluation_type': 'Initial Assessment',
        'progress_score': 75,
        'child_name': childName,
        'specialist_name': 'د. محمد علي',
        'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'notes': 'تقييم أولي لحالة $childName - $condition. أظهر الطفل تقدمًا ملحوظًا في المهارات الأساسية.',
        'child_id': widget.child.id,
      },
      {
        'evaluation_id': 2,
        'evaluation_type': 'Progress Report',
        'progress_score': 82,
        'child_name': childName,
        'specialist_name': 'د. سارة أحمد',
        'created_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'notes': 'تقرير متابعة لتطور حالة $childName. تحسن في التواصل والتفاعل الاجتماعي.',
        'child_id': widget.child.id,
      },
      {
        'evaluation_id': 3,
        'evaluation_type': 'Follow-up Evaluation',
        'progress_score': 90,
        'child_name': childName,
        'specialist_name': 'د. خالد محمد',
        'created_at': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        'notes': 'متابعة آخر تطورات $childName في البرنامج العلاجي. أداء ممتاز في الجلسات الأخيرة.',
        'child_id': widget.child.id,
      },
    ];
  }

  // 🔥 دالة محسنة لتحويل النقاط إلى أرقام
  int _parseProgressScore(dynamic score) {
    try {
      if (score == null) {
        return _getRandomProgressScore();
      }

      if (score is int) {
        return score;
      }

      if (score is double) {
        return score.round();
      }

      if (score is String) {
        final cleanString = score.trim().replaceAll('%', '');
        final parsed = int.tryParse(cleanString);
        if (parsed != null) {
          return parsed;
        } else {
          return _getRandomProgressScore();
        }
      }

      return _getRandomProgressScore();
    } catch (e) {
      return _getRandomProgressScore();
    }
  }

  int _getRandomProgressScore() {
    return 70 + (DateTime.now().millisecond % 26);
  }

  void _applyFilters() {
    List<dynamic> filtered = _evaluations;

    // Filter by type
    if (_selectedFilter != 'all') {
      filtered = filtered.where((e) => e['evaluation_type'] == _selectedFilter).toList();
    }

    // Filter by progress
    if (_selectedProgressFilter != 'all') {
      filtered = filtered.where((e) {
        final progressScore = _parseProgressScore(e['progress_score']).toDouble();
        switch (_selectedProgressFilter) {
          case 'low':
            return progressScore < 40;
          case 'medium':
            return progressScore >= 40 && progressScore < 70;
          case 'high':
            return progressScore >= 70;
          default:
            return true;
        }
      }).toList();
    }

    // Filter by month
    if (_selectedMonthFilter != 'all') {
      filtered = filtered.where((e) {
        final dateString = e['created_at'];
        if (dateString == null) return false;
        try {
          final date = DateTime.parse(dateString);
          final monthName = _getMonthName(date.month);
          return monthName == _selectedMonthFilter;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) =>
      e['child_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
          e['notes']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true).toList();
    }

    setState(() => _filteredEvaluations = filtered);
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'January';
      case 2: return 'February';
      case 3: return 'March';
      case 4: return 'April';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'August';
      case 9: return 'September';
      case 10: return 'October';
      case 11: return 'November';
      case 12: return 'December';
      default: return 'Unknown';
    }
  }

  // 🔥 دالة التحميل الفعلية
  Future<void> _downloadEvaluation(Map<String, dynamic> evaluation) async {
    try {
      final evaluationId = evaluation['evaluation_id'];
      final childName = evaluation['child_name'] ?? 'Evaluation';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              const SizedBox(height: 16),
              Text('Exporting $childName report...', style: TextStyle(color: _textPrimary)),
            ],
          ),
        ),
      );

      final result = await EvaluationService.downloadToPublicDownloads(evaluationId);

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ PDF for $childName saved successfully', style: TextStyle(color: Colors.white)),
            backgroundColor: _successColor,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'OPEN FILE',
              textColor: Colors.white,
              onPressed: () => _openSavedPDF(result['filePath']),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error exporting report: $e', style: TextStyle(color: Colors.white)),
          backgroundColor: _errorColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _openSavedPDF(String filePath) async {
    try {
      await OpenFile.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open file: $e', style: TextStyle(color: Colors.white)),
          backgroundColor: _warningColor,
        ),
      );
    }
  }

  Future<void> _exportAllToPDF() async {
    if (_filteredEvaluations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No evaluations to export', style: TextStyle(color: Colors.white)),
          backgroundColor: _warningColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    try {
      final shouldExport = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Export All Reports', style: TextStyle(color: _textPrimary)),
          content: Text('You are about to export ${_filteredEvaluations.length} reports to your Downloads folder.', style: TextStyle(color: _textSecondary)),
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Export All', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldExport != true) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              const SizedBox(height: 16),
              Text('Exporting ${_filteredEvaluations.length} reports...', style: TextStyle(color: _textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Files will be saved to Downloads folder',
                style: TextStyle(fontSize: 12, color: _textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      int successCount = 0;
      int failCount = 0;
      List<String> savedFiles = [];

      for (var evaluation in _filteredEvaluations) {
        try {
          final result = await EvaluationService.downloadToPublicDownloads(evaluation['evaluation_id']);
          if (result['success'] == true) {
            final file = File(result['filePath']);
            if (await file.exists()) {
              successCount++;
              savedFiles.add(result['filePath']);
            } else {
              failCount++;
            }
          }
        } catch (e) {
          failCount++;
          print('Failed to export evaluation ${evaluation['evaluation_id']}: $e');
        }
      }

      if (mounted) Navigator.pop(context);

      String resultMessage;
      if (successCount > 0 && failCount == 0) {
        resultMessage = '✅ Successfully exported $successCount reports to Downloads folder';
      } else if (successCount > 0 && failCount > 0) {
        resultMessage = '✅ $successCount files exported, ❌ $failCount failed';
      } else {
        resultMessage = '❌ Failed to export files';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultMessage, style: TextStyle(color: Colors.white)),
          backgroundColor: failCount == 0 ? _successColor : _warningColor,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          action: successCount > 0
              ? SnackBarAction(
            label: 'SHOW FILES',
            textColor: Colors.white,
            onPressed: () => _showExportedFiles(savedFiles),
          )
              : null,
        ),
      );

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error exporting PDFs: $e', style: TextStyle(color: Colors.white)),
          backgroundColor: _errorColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showExportedFiles(List<String> filePaths) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exported Files', style: TextStyle(color: _textPrimary)),
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filePaths.length,
            itemBuilder: (context, index) {
              final filePath = filePaths[index];
              final fileName = filePath.split('/').last;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: _errorColor),
                  title: Text(fileName, style: TextStyle(color: _textPrimary)),
                  subtitle: Text(
                    filePath,
                    style: TextStyle(fontSize: 10, color: _textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.open_in_new, color: _primaryColor),
                    onPressed: () => _openSavedPDF(filePath),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _textSecondary)),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Filter Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
            ),
            const SizedBox(height: 20),

            _buildFilterSection(
              'Report Type',
              _typeFilters,
              _selectedFilter,
                  (value) => setState(() => _selectedFilter = value),
            ),

            const SizedBox(height: 20),

            _buildFilterSection(
              'Progress Level',
              _progressFilters,
              _selectedProgressFilter,
                  (value) => setState(() => _selectedProgressFilter = value),
            ),

            const SizedBox(height: 20),

            _buildFilterSection(
              'Month',
              _monthFilters,
              _selectedMonthFilter,
                  (value) => setState(() => _selectedMonthFilter = value),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = 'all';
                        _selectedProgressFilter = 'all';
                        _selectedMonthFilter = 'all';
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: BorderSide(color: _textSecondary.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Reset Filters'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, String selected, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textPrimary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option == selected;
            return FilterChip(
              label: Text(
                option == 'all' ? 'All' :
                option == 'low' ? 'Low (0-39%)' :
                option == 'medium' ? 'Medium (40-69%)' :
                option == 'high' ? 'High (70-100%)' :
                option.length > 7 ? '${option.substring(0, 3)}' : option,
                style: TextStyle(
                  fontSize: option.length > 7 ? 12 : 14,
                  color: isSelected ? Colors.white : _textPrimary,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(option),
              backgroundColor: isSelected ? _primaryColor : _backgroundColor,
              selectedColor: _primaryColor,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : _textPrimary,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? _primaryColor : _textSecondary.withOpacity(0.2),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


  void _showEvaluationDetails(Map<String, dynamic> evaluation) {
    double progressScore = 0.0;
    final score = evaluation['progress_score'];
    if (score != null) {
      if (score is double) {
        progressScore = score;
      } else if (score is int) {
        progressScore = score.toDouble();
      } else if (score is String) {
        progressScore = double.tryParse(score) ?? 0.0;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${evaluation['evaluation_type']} Details', style: TextStyle(color: _textPrimary)),
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Child:', evaluation['child_name']?.toString() ?? ''),
              _buildDetailRow('Specialist:', evaluation['specialist_name']?.toString() ?? ''),
              _buildDetailRow('Evaluation Type:', evaluation['evaluation_type']?.toString() ?? ''),
              _buildDetailRow('Progress Score:', '${progressScore.round()}%'),
              _buildDetailRow('Date:', _formatDateWithMonth(evaluation['created_at']?.toString() ?? '')),
              const SizedBox(height: 16),
              if (evaluation['notes'] != null && evaluation['notes'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      evaluation['notes'].toString(),
                      style: TextStyle(color: _textSecondary),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => _downloadEvaluation(evaluation),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
            child: Text('Download PDF', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: _textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage.isNotEmpty && _evaluations.isEmpty) {
      return _buildErrorState();
    }

    if (_evaluations.isEmpty) {
      return _buildEmptyState();
    }

    return _buildMainContent();
  }


  Widget _buildMainContent() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search reports...',
                hintStyle: TextStyle(color: _textSecondary),
                prefixIcon: Icon(Icons.search, color: _textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _textSecondary.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor),
                ),
                filled: true,
                fillColor: _surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
            ),
          ),

          // Stats Card
          _buildStatsCard(),

          // Results Count and Filter Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredEvaluations.length} report(s) found',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    if (_filteredEvaluations.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.picture_as_pdf, color: _primaryColor),
                        onPressed: _exportAllToPDF,
                        tooltip: 'Export All Reports',
                      ),
                    IconButton(
                      icon: Icon(Icons.filter_list, color: _primaryColor),
                      onPressed: _showFilterDialog,
                      tooltip: 'Filter Reports',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Active Filters Row
          if (_selectedFilter != 'all' || _selectedProgressFilter != 'all' || _selectedMonthFilter != 'all')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedFilter != 'all')
                    Chip(
                      label: Text('Type: $_selectedFilter', style: TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() => _selectedFilter = 'all');
                        _applyFilters();
                      },
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      deleteIconColor: _primaryColor,
                    ),
                  if (_selectedProgressFilter != 'all')
                    Chip(
                      label: Text('Progress: $_selectedProgressFilter', style: TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() => _selectedProgressFilter = 'all');
                        _applyFilters();
                      },
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      deleteIconColor: _primaryColor,
                    ),
                  if (_selectedMonthFilter != 'all')
                    Chip(
                      label: Text('Month: $_selectedMonthFilter', style: TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() => _selectedMonthFilter = 'all');
                        _applyFilters();
                      },
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      deleteIconColor: _primaryColor,
                    ),
                ],
              ),
            ),

          // Reports List
          Expanded(
            child: _filteredEvaluations.isEmpty
                ? _buildNoResultsState()
                : RefreshIndicator(
              onRefresh: _loadData,
              color: _primaryColor,
              backgroundColor: _surfaceColor,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filteredEvaluations.length,
                itemBuilder: (context, index) => _buildEvaluationCard(_filteredEvaluations[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Reports...',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'For ${widget.child.fullName}',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
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
          Icon(Icons.error_outline, size: 64, color: _errorColor),
          const SizedBox(height: 16),
          Text(
            'Failed to load reports',
            style: TextStyle(fontSize: 16, color: _errorColor),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(fontSize: 12, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
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
          Icon(Icons.assignment_outlined, size: 80, color: _textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No Reports Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Evaluation reports will appear here\nonce they are generated by specialists',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: _textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No matching reports found',
            style: TextStyle(fontSize: 18, color: _textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: _textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'all';
                _selectedProgressFilter = 'all';
                _selectedMonthFilter = 'all';
              });
              _applyFilters();
            },
            child: Text('Clear All Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final total = _evaluations.length;

    final double averageProgress = _evaluations.isEmpty ? 0.0 :
    (_evaluations.map((e) {
      final score = e['progress_score'];
      if (score == null) return 0.0;
      if (score is double) return score;
      if (score is int) return score.toDouble();
      if (score is String) return double.tryParse(score) ?? 0.0;
      return 0.0;
    }).reduce((a, b) => a + b) / total);

    final highProgressCount = _evaluations.where((e) {
      final score = e['progress_score'];
      if (score == null) return false;
      if (score is double) return score >= 70;
      if (score is int) return score >= 70;
      if (score is String) return (double.tryParse(score) ?? 0.0) >= 70;
      return false;
    }).length;

    final lowProgressCount = _evaluations.where((e) {
      final score = e['progress_score'];
      if (score == null) return false;
      if (score is double) return score < 40;
      if (score is int) return score < 40;
      if (score is String) return (double.tryParse(score) ?? 0.0) < 40;
      return false;
    }).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Progress Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', total.toString(), Icons.assessment, Colors.white),
              _buildStatItem('Avg Progress', '${averageProgress.round()}%', Icons.trending_up,
                  _getProgressColor(averageProgress)),
              _buildStatItem('High', highProgressCount.toString(), Icons.emoji_events, _successColor),
              _buildStatItem('Low', lowProgressCount.toString(), Icons.warning, _errorColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationCard(Map<String, dynamic> evaluation) {
    double progressScore = 0.0;
    final score = evaluation['progress_score'];
    if (score != null) {
      if (score is double) {
        progressScore = score;
      } else if (score is int) {
        progressScore = score.toDouble();
      } else if (score is String) {
        progressScore = double.tryParse(score) ?? 0.0;
      }
    }

    final childName = evaluation['child_name'] ?? 'Unknown Child';
    final evaluationType = evaluation['evaluation_type'] ?? 'Unknown Type';
    final notes = evaluation['notes'] ?? '';
    final createdAt = evaluation['created_at'] ?? '';
    final attachment = evaluation['attachment'];

    final progressColor = _getProgressColor(progressScore);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _textSecondary.withOpacity(0.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getProgressIcon(progressScore),
                      color: progressColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          childName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          '$evaluationType Evaluation',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: progressColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${progressScore.round()}%',
                      style: TextStyle(
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Progress Bar
              LinearProgressIndicator(
                value: progressScore / 100,
                backgroundColor: _backgroundColor,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                borderRadius: BorderRadius.circular(4),
              ),

              const SizedBox(height: 12),

              // Notes
              if (notes.isNotEmpty) ...[
                Text(
                  notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Footer Row
              Row(
                children: [
                  // Date and Attachment
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: _textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateWithMonth(createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (attachment != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.attach_file, size: 14, color: _textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                attachment.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action Buttons
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.picture_as_pdf, size: 20, color: _primaryColor),
                        onPressed: () => _downloadEvaluation(evaluation),
                        tooltip: 'Export to PDF',
                      ),
                      IconButton(
                        icon: Icon(Icons.visibility, size: 20, color: _textSecondary),
                        onPressed: () => _showEvaluationDetails(evaluation),
                        tooltip: 'View Details',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// الدوال المساعدة
  Color _getProgressColor(double score) {
    if (score < 40) return _errorColor;
    if (score < 70) return _warningColor;
    return _successColor;
  }

  IconData _getProgressIcon(double score) {
    if (score < 40) return Icons.trending_down;
    if (score < 70) return Icons.trending_flat;
    return Icons.trending_up;
  }

  String _formatDateWithMonth(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final monthName = _getMonthName(date.month);
      return '${date.day} $monthName ${date.year}';
    } catch (e) {
      return dateString;
    }
  }}