import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../services/evaluation_service.dart';
import 'add_evaluation_screen.dart';
import 'edit_evaluation_screen.dart';

class EvaluationsScreen extends StatefulWidget {
  const EvaluationsScreen({super.key});

  @override
  State<EvaluationsScreen> createState() => _EvaluationsScreenState();
}

class _EvaluationsScreenState extends State<EvaluationsScreen> {
  List<dynamic> _evaluations = [];
  List<dynamic> _filteredEvaluations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  String _selectedProgressFilter = 'all';
  String _selectedMonthFilter = 'all';

  final List<String> _typeFilters = ['all', 'Initial', 'Mid', 'Final', 'Follow-up'];
  final List<String> _progressFilters = ['all', 'low', 'medium', 'high'];
  final List<String> _monthFilters = [
    'all',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadEvaluations();
  }

  Future<void> _loadEvaluations() async {
    try {
      setState(() => _isLoading = true);

      final response = await EvaluationService.getMyEvaluations();

      setState(() {
        _evaluations = response;
        _filteredEvaluations = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading evaluations: $e');
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load evaluations: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
        final score = e['progress_score'];
        double progressScore = 0.0;

        if (score != null) {
          if (score is double) {
            progressScore = score;
          } else if (score is int) {
            progressScore = score.toDouble();
          } else if (score is String) {
            progressScore = double.tryParse(score) ?? 0.0;
          }
        }

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

  Future<void> _deleteEvaluation(int evaluationId) async {
    final shouldDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Evaluation'),
        content: const Text('Are you sure you want to delete this evaluation? This action cannot be undone.'),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await EvaluationService.deleteEvaluation(evaluationId);

        setState(() {
          _evaluations.removeWhere((e) => e['evaluation_id'] == evaluationId);
          _filteredEvaluations.removeWhere((e) => e['evaluation_id'] == evaluationId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evaluation deleted successfully', style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting evaluation: $e', style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF(int evaluationId, String childName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Exporting evaluation for $childName...', style: TextStyle(color: AppColors.textDark)),
          ],
        ),
      ),
    );

    try {
      final result = await EvaluationService.downloadToPublicDownloads(evaluationId);

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        final file = File(result['filePath']);
        final fileExists = await file.exists();

        if (fileExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✅ PDF for $childName saved successfully', style: TextStyle(color: Colors.white)),
                  Text(
                    'Path: ${result['filePath']}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              action: SnackBarAction(
                label: 'OPEN FILE',
                textColor: Colors.white,
                onPressed: () => _openSavedPDF(result['filePath']),
              ),
            ),
          );
        } else {
          throw Exception('File was not created successfully');
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error exporting $childName: $e', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _openDownloadsFolder() async {
    try {
      String downloadsPath = '/storage/emulated/0/Download';
      final downloadsDir = Directory(downloadsPath);
      if (await downloadsDir.exists()) {
        await OpenFile.open(downloadsPath);
      } else {
        final directory = await getExternalStorageDirectory();
        final alternativePath = '${directory?.path}/Download';
        await OpenFile.open(alternativePath);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open downloads folder: $e', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.warning,
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
          backgroundColor: AppColors.warning,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _exportAllToPDF() async {
    if (_filteredEvaluations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No evaluations to export', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.warning,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    try {
      final shouldExport = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Export All Evaluations', style: TextStyle(color: AppColors.textDark)),
          content: Text('You are about to export ${_filteredEvaluations.length} evaluations to your Downloads folder.', style: TextStyle(color: AppColors.textGray)),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Exporting ${_filteredEvaluations.length} evaluations...', style: TextStyle(color: AppColors.textDark)),
              const SizedBox(height: 8),
              Text(
                'Files will be saved to Downloads folder',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
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
        resultMessage = '✅ Successfully exported $successCount evaluations to Downloads folder';
      } else if (successCount > 0 && failCount > 0) {
        resultMessage = '✅ $successCount files exported, ❌ $failCount failed';
      } else {
        resultMessage = '❌ Failed to export files';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultMessage, style: TextStyle(color: Colors.white)),
          backgroundColor: failCount == 0 ? AppColors.success : AppColors.warning,
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
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showExportedFiles(List<String> filePaths) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exported Files', style: TextStyle(color: AppColors.textDark)),
        backgroundColor: AppColors.surface,
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
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: AppColors.error),
                  title: Text(fileName, style: TextStyle(color: AppColors.textDark)),
                  subtitle: Text(
                    filePath,
                    style: TextStyle(fontSize: 10, color: AppColors.textGray),
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
            child: Text('Close', style: TextStyle(color: AppColors.textGray)),
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
                color: AppColors.textGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Filter Evaluations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 20),

            _buildFilterSection(
              'Evaluation Type',
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
                      foregroundColor: AppColors.textGray,
                      side: BorderSide(color: AppColors.textGray.withOpacity(0.3)),
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
                      backgroundColor: AppColors.primary,
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
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
              backgroundColor: isSelected ? AppColors.primary : AppColors.background,
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.textGray.withOpacity(0.2),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
    }).reduce((a, b) => a + b) / total).toDouble();

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
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                'Evaluation Statistics',
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
              _buildStatItem('High', highProgressCount.toString(), Icons.emoji_events, AppColors.success),
              _buildStatItem('Low', lowProgressCount.toString(), Icons.warning, AppColors.error),
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
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
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textGray.withOpacity(0.1),
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
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '$evaluationType Evaluation',
                          style: TextStyle(
                            color: AppColors.textGray,
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
                backgroundColor: AppColors.background,
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
                    color: AppColors.textGray,
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
                            Icon(Icons.calendar_today, size: 14, color: AppColors.textGray),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateWithMonth(createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                        if (attachment != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.attach_file, size: 14, color: AppColors.textGray),
                              const SizedBox(width: 4),
                              Text(
                                attachment.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
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
                        icon: Icon(Icons.picture_as_pdf, size: 20, color: AppColors.primary),
                        onPressed: () => _exportToPDF(evaluation['evaluation_id'], childName),
                        tooltip: 'Export to PDF',
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, size: 20, color: AppColors.textGray),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditEvaluationScreen(
                                evaluation: evaluation,
                                onEvaluationUpdated: _loadEvaluations,
                              ),
                            ),
                          );
                        },
                        tooltip: 'Edit Evaluation',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 20, color: AppColors.error),
                        onPressed: () => _deleteEvaluation(evaluation['evaluation_id']),
                        tooltip: 'Delete Evaluation',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Evaluations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        shadowColor: AppColors.primary.withOpacity(0.3),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_filteredEvaluations.isNotEmpty)
            Badge(
              label: Text(_filteredEvaluations.length.toString(), style: TextStyle(fontSize: 10)),
              backgroundColor: AppColors.error,
              textColor: Colors.white,
              child: IconButton(
                icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: _exportAllToPDF,
                tooltip: 'Export All Evaluations',
              ),
            ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Evaluations',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEvaluations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
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
              'Loading Evaluations...',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_evaluations.length} evaluations found',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by child name or notes...',
                hintStyle: TextStyle(color: AppColors.textGray),
                prefixIcon: Icon(Icons.search, color: AppColors.textGray),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.textGray.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: AppColors.surface,
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
                  '${_filteredEvaluations.length} evaluation(s) found',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    fontSize: 16,
                  ),
                ),
                if (_selectedFilter != 'all' || _selectedProgressFilter != 'all' || _selectedMonthFilter != 'all')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text('Filters Active', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                      ],
                    ),
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
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      deleteIconColor: AppColors.primary,
                    ),
                  if (_selectedProgressFilter != 'all')
                    Chip(
                      label: Text('Progress: $_selectedProgressFilter', style: TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() => _selectedProgressFilter = 'all');
                        _applyFilters();
                      },
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      deleteIconColor: AppColors.primary,
                    ),
                  if (_selectedMonthFilter != 'all')
                    Chip(
                      label: Text('Month: $_selectedMonthFilter', style: TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() => _selectedMonthFilter = 'all');
                        _applyFilters();
                      },
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      deleteIconColor: AppColors.primary,
                    ),
                ],
              ),
            ),

          // Evaluations List
          Expanded(
            child: _filteredEvaluations.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assessment, size: 64, color: AppColors.textGray.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No evaluations found',
                    style: TextStyle(fontSize: 18, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search or filters',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadEvaluations,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filteredEvaluations.length,
                itemBuilder: (context, index) =>
                    _buildEvaluationCard(_filteredEvaluations[index]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEvaluationScreen(),
            ),
          ).then((_) => _loadEvaluations());
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}