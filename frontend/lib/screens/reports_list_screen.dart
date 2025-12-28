import 'package:flutter/material.dart';

import '../services/reports_service.dart';
import '../theme/app_colors.dart';
import 'create_report_screen.dart';
import 'report_details_screen.dart';

class ReportsListScreen extends StatefulWidget {
  final ReportsScope scope;
  final String title;

  const ReportsListScreen({
    super.key,
    required this.scope,
    required this.title,
  });

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ReportsService.listReports(scope: widget.scope, limit: 100);
      setState(() {
        _reports = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatStatus(String raw) {
    if (raw.isEmpty) return 'Unknown';
    return raw.replaceAll('_', ' ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.warning;
      case 'in_review':
        return AppColors.info;
      case 'resolved':
      case 'closed':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.textWhite,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateReportScreen(
                    scope: widget.scope,
                  ),
                ),
              );
              if (created == true) {
                _load();
              }
            },
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _reports.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No reports yet')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _reports.length,
                          itemBuilder: (context, index) {
                            final r = _reports[index] as Map<String, dynamic>;
                            final id = (r['report_id'] as num?)?.toInt() ?? 0;
                            final title = r['title']?.toString() ?? 'Report';
                            final status = r['status']?.toString() ?? '';
                            final category = r['category']?.toString() ?? 'Other';
                            final priority = r['priority']?.toString() ?? 'medium';

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                title: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _Chip(
                                        label: _formatStatus(status),
                                        color: _statusColor(status),
                                      ),
                                      _Chip(label: category, color: AppColors.accent4),
                                      _Chip(label: 'Priority: $priority', color: AppColors.textLight),
                                      _Chip(label: '#$id', color: AppColors.primaryLight),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReportDetailsScreen(
                                        scope: widget.scope,
                                        reportId: id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
