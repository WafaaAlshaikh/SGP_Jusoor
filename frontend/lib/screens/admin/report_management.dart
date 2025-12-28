// lib/screens/admin/report_management.dart
import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';

class ReportManagement extends StatefulWidget {
  @override
  _ReportManagementState createState() => _ReportManagementState();
}

class _ReportManagementState extends State<ReportManagement> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  String _statusFilter = 'open';
  String _priorityFilter = 'all';
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports({int page = 1}) async {
    try {
      setState(() => _isLoading = true);

      final data = await AdminApiService.getReports(
        page: page,
        limit: 20,
        status: (_statusFilter == 'all') ? null : _statusFilter,
        priority: (_priorityFilter == 'all') ? null : _priorityFilter,
      );

      if (data['success'] == true) {
        final payload = (data['data'] as Map?)?.cast<String, dynamic>() ?? {};
        setState(() {
          _reports = (payload['reports'] as List?) ?? [];
          _currentPage = (payload['page'] as int?) ?? 1;
          _totalPages = (payload['totalPages'] as int?) ?? 1;
          _isLoading = false;
        });
      } else {
        throw Exception(data['message'] ?? 'Failed to load reports');
      }
    } catch (e) {
      print('Error loading reports: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateReportStatus(int reportId, String status) async {
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تحديث حالة البلاغ'),
        content: TextField(
          decoration: InputDecoration(
            labelText: 'ملاحظات (اختياري)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement with actual text field value
              Navigator.pop(context, 'ملاحظات الإدارة');
            },
            child: Text('تحديث'),
          ),
        ],
      ),
    );

    try {
      final ok = await AdminApiService.updateReportStatus(reportId, status, adminNotes: notes);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة البلاغ'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReports();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديث الحالة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    report['title'] ?? 'بدون عنوان',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        _getPriorityText(report['priority']),
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _getPriorityColor(report['priority']),
                    ),
                    SizedBox(width: 8),
                    Chip(
                      label: Text(
                        _getStatusText(report['status']),
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _getStatusColor(report['status']),
                    ),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            Text(
              report['description'] ?? 'لا يوجد وصف',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            
            SizedBox(height: 12),
            
            _buildDetailRow('المبلغ: ${report['reporter']['full_name']}'),
            if (report['ReportInstitution'] != null)
              _buildDetailRow('المؤسسة: ${report['ReportInstitution']['name']}'),
            _buildDetailRow('التاريخ: ${_formatDate(report['created_at'])}'),
            
            SizedBox(height: 12),
            
            if (report['status'] == 'open')
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _updateReportStatus(report['report_id'], 'in_review'),
                    icon: Icon(Icons.play_arrow),
                    label: Text('بدء المعالجة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _updateReportStatus(report['report_id'], 'resolved'),
                    icon: Icon(Icons.check),
                    label: Text('حل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      return DateTime.parse(date).toLocal().toString().substring(0, 16);
    } catch (e) {
      return date;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'low': return 'منخفض';
      case 'medium': return 'متوسط';
      case 'high': return 'مرتفع';
      case 'critical': return 'حرج';
      default: return priority;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low': return Colors.green;
      case 'medium': return Colors.orange;
      case 'high': return Colors.red;
      case 'critical': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'open': return 'مفتوح';
      case 'in_review': return 'قيد المراجعة';
      case 'waiting_user': return 'بانتظار المستخدم';
      case 'forwarded_to_institution': return 'محول للمؤسسة';
      case 'resolved': return 'تم الحل';
      case 'closed': return 'مغلق';
      case 'rejected': return 'مرفوض';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open': return Colors.blue;
      case 'in_review': return Colors.orange;
      case 'waiting_user': return Colors.amber;
      case 'forwarded_to_institution': return Colors.purple;
      case 'resolved': return Colors.green;
      case 'closed': return Colors.grey;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildDetailRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة البلاغات'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _loadReports(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
                      DropdownMenuItem(value: 'open', child: Text('مفتوح')),
                      DropdownMenuItem(value: 'in_review', child: Text('قيد المراجعة')),
                      DropdownMenuItem(value: 'waiting_user', child: Text('بانتظار المستخدم')),
                      DropdownMenuItem(value: 'forwarded_to_institution', child: Text('محول للمؤسسة')),
                      DropdownMenuItem(value: 'resolved', child: Text('تم الحل')),
                      DropdownMenuItem(value: 'closed', child: Text('مغلق')),
                      DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                    ],
                    onChanged: (value) {
                      setState(() => _statusFilter = value!);
                      _loadReports();
                    },
                    decoration: InputDecoration(
                      labelText: 'الحالة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _priorityFilter,
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('جميع الأولويات')),
                      DropdownMenuItem(value: 'low', child: Text('منخفض')),
                      DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                      DropdownMenuItem(value: 'high', child: Text('مرتفع')),
                      DropdownMenuItem(value: 'critical', child: Text('حرج')),
                    ],
                    onChanged: (value) {
                      setState(() => _priorityFilter = value!);
                      _loadReports();
                    },
                    decoration: InputDecoration(
                      labelText: 'الأولوية',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Reports List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? Center(child: Text('لا توجد بلاغات'))
                    : ListView.builder(
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          return _buildReportCard(_reports[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}