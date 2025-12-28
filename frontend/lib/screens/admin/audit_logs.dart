// lib/screens/admin/audit_logs.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/admin_api_service.dart';

class AuditLogs extends StatefulWidget {
  @override
  _AuditLogsState createState() => _AuditLogsState();
}

class _AuditLogsState extends State<AuditLogs> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;
  DateTimeRange? _dateRange;
  String? _adminFilter;
  String? _actionFilter;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs({int page = 1}) async {
    try {
      setState(() => _isLoading = true);
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': '50',
      };
      
      if (_dateRange != null) {
        queryParams['start_date'] = _dateRange!.start.toIso8601String();
        queryParams['end_date'] = _dateRange!.end.toIso8601String();
      }
      if (_adminFilter != null && _adminFilter!.isNotEmpty) {
        queryParams['admin_id'] = _adminFilter!;
      }
      if (_actionFilter != null && _actionFilter!.isNotEmpty) {
        queryParams['action_type'] = _actionFilter!;
      }

      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.get(
        Uri.parse('${AdminApiService.baseUrl}/audit-logs').replace(
          queryParameters: queryParams,
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          _logs = data['data']['logs'] ?? [];
          _currentPage = data['data']['page'] ?? 1;
          _totalPages = data['data']['totalPages'] ?? 1;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load audit logs');
      }
    } catch (e) {
      print('Error loading logs: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getActionColor(log['action_type']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getActionIcon(log['action_type']),
                    color: _getActionColor(log['action_type']),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getActionText(log['action_type']),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(log['created_at']),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            _buildDetailRow('Admin:', log['admin']['full_name']),
            _buildDetailRow('Target:', '${_getTargetText(log['target_type'])} #${log['target_id']}'),
            
            if (log['details'] != null && log['details'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    log['details'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            
            SizedBox(height: 12),
            
            Row(
              children: [
                Icon(Icons.computer, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  log['ip_address'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Spacer(),
                Icon(Icons.devices, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  log['user_agent']?.substring(0, 20) ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'user_approval':
      case 'institution_approval':
        return Icons.check;
      case 'user_suspension':
      case 'institution_suspension':
        return Icons.pause;
      case 'institution_rejection':
        return Icons.close;
      case 'report_resolution':
        return Icons.flag;
      case 'setting_change':
        return Icons.settings;
      case 'content_removal':
        return Icons.delete;
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      default:
        return Icons.history;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'user_approval':
      case 'institution_approval':
      case 'report_resolution':
        return Colors.green;
      case 'user_suspension':
      case 'institution_suspension':
        return Colors.orange;
      case 'institution_rejection':
      case 'content_removal':
        return Colors.red;
      case 'setting_change':
        return Colors.blue;
      case 'login':
        return Colors.teal;
      case 'logout':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getActionText(String action) {
    switch (action) {
      case 'user_approval': return 'User Approval';
      case 'institution_approval': return 'Institution Approval';
      case 'user_suspension': return 'User Suspension';
      case 'institution_suspension': return 'Institution Suspension';
      case 'institution_rejection': return 'Institution Rejection';
      case 'report_resolution': return 'Report Resolution';
      case 'setting_change': return 'Setting Change';
      case 'content_removal': return 'Content Removal';
      case 'login': return 'Admin Login';
      case 'logout': return 'Admin Logout';
      case 'password_change': return 'Password Change';
      case 'data_export': return 'Data Export';
      default: return action.replaceAll('_', ' ').toTitleCase();
    }
  }

  String _getTargetText(String target) {
    switch (target) {
      case 'User': return 'User';
      case 'Institution': return 'Institution';
      case 'Report': return 'Report';
      case 'SystemSetting': return 'Setting';
      case 'Donation': return 'Donation';
      case 'Session': return 'Session';
      case 'Child': return 'Child';
      default: return target;
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      final parsed = DateTime.parse(date).toLocal();
      return '${parsed.hour}:${parsed.minute.toString().padLeft(2, '0')} ${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      return date;
    }
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return SizedBox();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _currentPage > 1
                ? () => _loadLogs(page: _currentPage - 1)
                : null,
          ),
          Text('Page $_currentPage of $_totalPages'),
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: _currentPage < _totalPages
                ? () => _loadLogs(page: _currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audit Logs'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFiltersDialog,
            tooltip: 'Filter Logs',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _loadLogs(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _exportLogs,
            tooltip: 'Export Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.history, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total Logs: ${_logs.length}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_dateRange != null)
                    Chip(
                      label: Text(
                        '${_dateRange!.start.toLocal().toString().substring(0, 10)} - ${_dateRange!.end.toLocal().toString().substring(0, 10)}',
                      ),
                      onDeleted: () {
                        setState(() => _dateRange = null);
                        _loadLogs();
                      },
                    ),
                ],
              ),
            ),
          ),
          
          // Action Statistics
          if (_logs.isNotEmpty) _buildActionStats(),
          
          // Logs List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No audit logs found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Try changing your filters or date range',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return _buildLogCard(_logs[index]);
                        },
                      ),
          ),
          
          // Pagination
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildActionStats() {
    final stats = <String, int>{};
    for (var log in _logs) {
      final action = log['action_type'];
      stats[action] = (stats[action] ?? 0) + 1;
    }
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: stats.entries.map((entry) {
          return Chip(
            label: Text('${_getActionText(entry.key)}: ${entry.value}'),
            backgroundColor: _getActionColor(entry.key).withOpacity(0.1),
            labelStyle: TextStyle(color: _getActionColor(entry.key)),
          );
        }).toList(),
      ),
    );
  }

  void _showFiltersDialog() {
    final adminController = TextEditingController(text: _adminFilter);
    final actionController = TextEditingController(text: _actionFilter);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Logs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: adminController,
              decoration: InputDecoration(
                labelText: 'Admin ID',
                border: OutlineInputBorder(),
                hintText: 'Enter admin ID',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: actionController,
              decoration: InputDecoration(
                labelText: 'Action Type',
                border: OutlineInputBorder(),
                hintText: 'e.g., user_approval, setting_change',
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _dateRange,
                );
                if (picked != null) {
                  setState(() => _dateRange = picked);
                }
              },
              icon: Icon(Icons.calendar_today, size: 18),
              label: Text(_dateRange == null 
                  ? 'Select Date Range' 
                  : 'Change Date Range'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 45),
              ),
            ),
            if (_dateRange != null) ...[
              SizedBox(height: 8),
              Text(
                'Selected: ${_dateRange!.start.toLocal().toString().substring(0, 10)} to ${_dateRange!.end.toLocal().toString().substring(0, 10)}',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _adminFilter = null;
                _actionFilter = null;
                _dateRange = null;
              });
              _loadLogs();
              Navigator.pop(context);
            },
            child: Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _adminFilter = adminController.text.isNotEmpty ? adminController.text : null;
                _actionFilter = actionController.text.isNotEmpty ? actionController.text : null;
              });
              _loadLogs();
              Navigator.pop(context);
            },
            child: Text('Apply Filters'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.get(
        Uri.parse('${AdminApiService.baseUrl}/audit-logs/export').replace(
          queryParameters: {
            'start_date': _dateRange?.start.toIso8601String() ?? DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
            'end_date': _dateRange?.end.toIso8601String() ?? DateTime.now().toIso8601String(),
          },
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logs exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export logs'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Extension for string title case
extension StringExtension on String {
  String toTitleCase() {
    return split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }
}