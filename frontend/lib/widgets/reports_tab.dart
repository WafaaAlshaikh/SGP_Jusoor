import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/evaluation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';

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

  final List<String> _typeFilters = [
    'all',
    'Initial',
    'Mid',
    'Final',
    'Follow-up'
  ];
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
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final evaluations = await _loadChildEvaluations();

      setState(() {
        _evaluations = evaluations;
        _filteredEvaluations = List<Map<String, dynamic>>.from(evaluations);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load evaluations. Please try again later.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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

        // Filter evaluations by child
        final childEvaluations = allEvaluations.where((eval) {
          final childName = eval['child_name']?.toString() ?? '';
          final evalChildId = eval['child_id']?.toString();
          final currentChildId = widget.child.id.toString();

          final matches = childName.toLowerCase().contains(
              widget.child.fullName.toLowerCase()) ||
              evalChildId == currentChildId;

          return matches;
        }).toList();

        print('✅ Found ${childEvaluations.length} evaluations for ${widget.child
            .fullName}');

        return childEvaluations;
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error loading child evaluations: $e');
      return [];
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = _evaluations;

    // Filter by type
    if (_selectedFilter != 'all') {
      filtered = filtered.where((e) => e['evaluation_type'] == _selectedFilter)
          .toList();
    }

    // Filter by progress
    if (_selectedProgressFilter != 'all') {
      filtered = filtered.where((e) {
        final progressScore = _parseProgressScore(e['progress_score'])
            .toDouble();
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
      e['child_name']?.toString().toLowerCase().contains(
          _searchQuery.toLowerCase()) == true ||
          e['notes']?.toString().toLowerCase().contains(
              _searchQuery.toLowerCase()) == true).toList();
    }

    setState(() => _filteredEvaluations = filtered);
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
        return 'August';
      case 9:
        return 'September';
      case 10:
        return 'October';
      case 11:
        return 'November';
      case 12:
        return 'December';
      default:
        return 'Unknown';
    }
  }

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
    return 70 + (DateTime
        .now()
        .millisecond % 26);
  }

  Future<void> _downloadEvaluation(Map<String, dynamic> evaluation) async {
    try {
      final evaluationId = evaluation['evaluation_id'];
      final childName = evaluation['child_name'] ?? 'Evaluation';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Exporting $childName report...',
                      style: TextStyle(color: AppColors.textDark)),
                ],
              ),
            ),
      );

      final result = await EvaluationService.downloadToPublicDownloads(
          evaluationId);

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ PDF for $childName saved successfully',
                style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
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
          content: Text('❌ Error exporting report: $e',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
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
          content: Text(
              'Cannot open file: $e', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _exportAllToPDF() async {
    if (_filteredEvaluations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No evaluations to export',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.warning,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    try {
      final shouldExport = await showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text('Export All Reports',
                  style: TextStyle(color: AppColors.textDark)),
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Text('You are about to export ${_filteredEvaluations
                  .length} reports to your Downloads folder.',
                  style: TextStyle(color: AppColors.textLight)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                      'Cancel', style: TextStyle(color: AppColors.textLight)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                      'Export All', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
      );

      if (shouldExport != true) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Exporting ${_filteredEvaluations.length} reports...',
                      style: TextStyle(color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Text(
                    'Files will be saved to Downloads folder',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
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
          final result = await EvaluationService.downloadToPublicDownloads(
              evaluation['evaluation_id']);
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
          print(
              'Failed to export evaluation ${evaluation['evaluation_id']}: $e');
        }
      }

      if (mounted) Navigator.pop(context);

      String resultMessage;
      if (successCount > 0 && failCount == 0) {
        resultMessage =
        '✅ Successfully exported $successCount reports to Downloads folder';
      } else if (successCount > 0 && failCount > 0) {
        resultMessage = '✅ $successCount files exported, ❌ $failCount failed';
      } else {
        resultMessage = '❌ Failed to export files';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultMessage, style: TextStyle(color: Colors.white)),
          backgroundColor: failCount == 0 ? AppColors.success : AppColors
              .warning,
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
          content: Text('❌ Error exporting PDFs: $e',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showExportedFiles(List<String> filePaths) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(
                'Exported Files', style: TextStyle(color: AppColors.textDark)),
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filePaths.length,
                itemBuilder: (context, index) {
                  final filePath = filePaths[index];
                  final fileName = filePath
                      .split('/')
                      .last;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                          Icons.picture_as_pdf, color: AppColors.error),
                      title: Text(fileName,
                          style: TextStyle(color: AppColors.textDark)),
                      subtitle: Text(
                        filePath,
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.open_in_new, color: AppColors.primary),
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
                child: Text(
                    'Close', style: TextStyle(color: AppColors.textLight)),
              ),
            ],
          ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Filter Reports',
                  style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
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
                      (value) =>
                      setState(() => _selectedProgressFilter = value),
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
                          foregroundColor: AppColors.textLight,
                          side: BorderSide(
                              color: AppColors.textLight.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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

  Widget _buildFilterSection(String title, List<String> options,
      String selected, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textDark),
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
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(option),
              backgroundColor: isSelected ? AppColors.primary : AppColors
                  .background,
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.textLight
                      .withOpacity(0.2),
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

    // Remove the child's name from the notes if it exists
    String notes = evaluation['notes']?.toString() ?? '';
    final childName = evaluation['child_name']?.toString() ?? '';
    if (childName.isNotEmpty) {
      // Remove child's name from the notes
      notes = notes.replaceAll('$childName', 'the child');
    }

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('${evaluation['evaluation_type']} Details',
                style: TextStyle(color: AppColors.buttonColor)),
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Specialist:',
                      evaluation['specialist_name']?.toString() ?? 'Not specified'),
                  _buildDetailRow('Evaluation Type:',
                      evaluation['evaluation_type']?.toString() ?? 'N/A'),
                  _buildDetailRow(
                      'Progress Score:', '${progressScore.round()}%'),
                  _buildDetailRow('Date:', _formatDateWithMonth(
                      evaluation['created_at']?.toString() ?? 'Unknown date')),
                  const SizedBox(height: 16),
                  if (notes.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textName,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notes,
                          style: TextStyle(color: AppColors.textGray),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    'Close', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textName,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
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
      backgroundColor: AppColors.background,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      backgroundColor: AppColors.background,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchAndFilter(),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              if (_errorMessage.isNotEmpty)
                _buildErrorState()
              else
                if (_filteredEvaluations.isEmpty)
                  _buildEmptyState()
                else
                  _buildEvaluationsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredEvaluations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final evaluation = _filteredEvaluations[index];
        return _buildEvaluationCard(evaluation);
      },
    );
  }

  Widget _buildEvaluationCard(Map<String, dynamic> evaluation) {
    final progressScore = _parseProgressScore(evaluation['progress_score']);
    final evaluationDate = DateTime.parse(evaluation['created_at']);
    final formattedDate = DateFormat('MMM d, y').format(evaluationDate);
    final evaluationType = evaluation['evaluation_type'] ?? 'Evaluation';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Handle tap
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      evaluationType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(progressScore).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getStatusColor(progressScore)
                            .withOpacity(0.3)),
                      ),
                      child: Text(
                        '${progressScore}%',
                        style: TextStyle(
                          color: _getStatusColor(progressScore),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Specialist and Date Row
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16,
                        color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Text(
                      evaluation['specialist_name'] ?? 'Specialist',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today_outlined, size: 14,
                        color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressScore / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.accent1,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStatusColor(progressScore),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // View Details Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _showEvaluationDetails(evaluation);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 12,
                            color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(int progress) {
    if (progress >= 75) return AppColors.success;
    if (progress >= 50) return AppColors.info;
    if (progress >= 25) return AppColors.warning;
    return AppColors.error;
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
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Reports...',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'For ${widget.child.fullName}',
            style: TextStyle(
              color: AppColors.textLight,
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
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load reports',
            style: TextStyle(fontSize: 16, color: AppColors.error),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No evaluations found',
        style: TextStyle(
          color: AppColors.textLight,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search reports...',
              hintStyle: const TextStyle(color: AppColors.textLight),
              prefixIcon: const Icon(
                  Icons.search, color: AppColors.primaryLight),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            style: const TextStyle(color: AppColors.textDark),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
                _applyFilters();
              });
            },
          ),
        ),

        const SizedBox(height: 16),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', _selectedFilter == 'all', () {
                setState(() {
                  _selectedFilter = 'all';
                  _applyFilters();
                });
              }),
              const SizedBox(width: 8),
              ..._typeFilters.where((f) => f != 'all').map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildFilterChip(
                    filter,
                    _selectedFilter == filter,
                        () {
                      setState(() {
                        _selectedFilter = filter;
                        _applyFilters();
                      });
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.accent1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.accent2,
            width: 1,
          ),
        ),
        child: Text(
          label[0].toUpperCase() + label.substring(1),
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

// الدوال المساعدة
  Color _getProgressColor(double score) {
    if (score < 40) return AppColors.error;
    if (score < 70) return AppColors.warning;
    return AppColors.success;
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
  }
}