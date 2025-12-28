// lib/screens/admin/user_management.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/admin_api_service.dart';
import '../../theme/app_colors.dart';

class UserManagement extends StatefulWidget {
  @override
  _UserManagementState createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _roleFilter = 'All';
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;
  List<int> _selectedUsers = [];
  bool _selectAll = false;

  final List<String> _roleOptions = [
    'All',
    'Parent',
    'Specialist',
    'Manager',
    'Donor',
    'Admin'
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers({int page = 1}) async {
    try {
      setState(() => _isLoading = true);
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': '20',
      };
      
      if (_roleFilter != 'All') queryParams['role'] = _roleFilter;
      if (_searchQuery.isNotEmpty) queryParams['search'] = _searchQuery;

      final response = await http.get(
        Uri.parse('${AdminApiService.baseUrl}/users').replace(
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
          _users = data['data']?['users'] ?? [];
          _currentPage = data['data']?['page'] ?? 1;
          _totalPages = data['data']?['totalPages'] ?? 1;
          _isLoading = false;
          _selectedUsers.clear();
          _selectAll = false;
        });
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveUser(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        Uri.parse('${AdminApiService.baseUrl}/users/$userId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _suspendUser(int userId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Suspend User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter the reason for suspension:'),
            SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Suspension reason',
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final controller = (context as Element).findAncestorWidgetOfExactType<AlertDialog>()?.content;
              Navigator.pop(context, 'Suspension reason');
            },
            child: Text('Suspend'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? '';
        
        final response = await http.post(
          Uri.parse('${AdminApiService.baseUrl}/users/$userId/suspend'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'reason': reason}),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User suspended successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadUsers();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to suspend user'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _activateUser(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        Uri.parse('${AdminApiService.baseUrl}/users/$userId/activate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User activated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to activate user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedUsers = _users.map((user) => user['user_id'] as int).toList();
      } else {
        _selectedUsers.clear();
      }
    });
  }

  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUsers.contains(userId)) {
        _selectedUsers.remove(userId);
      } else {
        _selectedUsers.add(userId);
      }
      _selectAll = _selectedUsers.length == _users.length;
    });
  }

  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: _selectAll,
              onChanged: _toggleSelectAll,
              activeColor: AppColors.primary,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              'User',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Role',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Created',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              'Actions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> user) {
    final isSelected = _selectedUsers.contains(user['user_id']);
    final bool canSuspend = user['status'] == 'Approved' && user['role'] != 'Admin';
    final bool canApprove = user['status'] == 'Pending';
    final bool canActivate = user['status'] == 'Suspended' || user['status'] == 'Canceled';

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUserDetails(user),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleUserSelection(user['user_id']),
                    activeColor: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8),
                // User Info
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        user['email'] ?? 'No email',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (user['phone'] != null) ...[
                        SizedBox(height: 2),
                        Text(
                          user['phone'],
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Role
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user['role']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getRoleColor(user['role']).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _getRoleText(user['role']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(user['role']),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Status
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(user['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getStatusColor(user['status']).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _getStatusText(user['status']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(user['status']),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Created Date
                Expanded(
                  child: Text(
                    _formatDate(user['created_at']),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ),
                // Actions
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canApprove)
                        IconButton(
                          icon: Icon(Icons.check, size: 18),
                          color: AppColors.success,
                          onPressed: () => _approveUser(user['user_id']),
                          tooltip: 'Approve User',
                        ),
                      if (canSuspend)
                        IconButton(
                          icon: Icon(Icons.pause, size: 18),
                          color: AppColors.warning,
                          onPressed: () => _suspendUser(user['user_id']),
                          tooltip: 'Suspend User',
                        ),
                      if (canActivate)
                        IconButton(
                          icon: Icon(Icons.play_arrow, size: 18),
                          color: AppColors.success,
                          onPressed: () => _activateUser(user['user_id']),
                          tooltip: 'Activate User',
                        ),
                      IconButton(
                        icon: Icon(Icons.more_vert, size: 18),
                        color: AppColors.primary,
                        onPressed: () => _showActionMenu(user),
                        tooltip: 'More Options',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionMenu(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.visibility, color: AppColors.primary),
                title: Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showUserDetails(user);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: AppColors.primary),
                title: Text('Edit User'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement edit user
                },
              ),
              ListTile(
                leading: Icon(Icons.email, color: AppColors.primary),
                title: Text('Send Email'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement send email
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: AppColors.error),
                title: Text('Delete User', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(user);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  child: Text(user['full_name'][0]),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                title: Text(user['full_name'], style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(user['email']),
              ),
              Divider(),
              _buildDetailItem('Role', _getRoleText(user['role'])),
              _buildDetailItem('Status', _getStatusText(user['status'])),
              _buildDetailItem('Phone', user['phone'] ?? 'Not provided'),
              _buildDetailItem('Created', _formatDateTime(user['created_at'])),
              if (user['institution'] != null)
                _buildDetailItem('Institution', user['institution']['name']),
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGray),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User?'),
        content: Text('Are you sure you want to delete ${user['full_name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete user
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final parsedDate = DateTime.parse(date);
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }

  String _formatDateTime(String? date) {
    if (date == null) return 'N/A';
    try {
      final parsedDate = DateTime.parse(date);
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} ${parsedDate.hour}:${parsedDate.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date;
    }
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'Parent': return 'Parent';
      case 'Specialist': return 'Specialist';
      case 'Manager': return 'Manager';
      case 'Donor': return 'Donor';
      case 'Admin': return 'Admin';
      default: return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Parent': return AppColors.blue;
      case 'Specialist': return AppColors.green;
      case 'Manager': return AppColors.darkGreen;
      case 'Donor': return AppColors.ment;
      case 'Admin': return AppColors.primary;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Pending': return 'Pending';
      case 'Approved': return 'Approved';
      case 'Canceled': return 'Canceled';
      case 'Suspended': return 'Suspended';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return AppColors.yalw;
      case 'Approved': return AppColors.success;
      case 'Canceled': return AppColors.red;
      case 'Suspended': return AppColors.warning;
      default: return Colors.grey;
    }
  }

  Widget _buildPagination() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_users.length} users',
            style: TextStyle(color: AppColors.textGray),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, size: 16),
                onPressed: _currentPage > 1
                    ? () => _loadUsers(page: _currentPage - 1)
                    : null,
                color: _currentPage > 1 ? AppColors.primary : Colors.grey,
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $_currentPage of $_totalPages',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.arrow_forward_ios, size: 16),
                onPressed: _currentPage < _totalPages
                    ? () => _loadUsers(page: _currentPage + 1)
                    : null,
                color: _currentPage < _totalPages ? AppColors.primary : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions() {
    if (_selectedUsers.isEmpty) return SizedBox();
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedUsers.length} selected',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement bulk approve
            },
            icon: Icon(Icons.check, size: 16),
            label: Text('Approve Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement bulk suspend
            },
            icon: Icon(Icons.pause, size: 16),
            label: Text('Suspend Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.clear, color: AppColors.error),
            onPressed: () {
              setState(() {
                _selectedUsers.clear();
                _selectAll = false;
              });
            },
            tooltip: 'Clear Selection',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('User Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _loadUsers(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () {
              // TODO: Implement export
            },
            tooltip: 'Export Users',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search users...',
                          prefixIcon: Icon(Icons.search, color: AppColors.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _loadUsers();
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: _roleFilter,
                        items: _roleOptions.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(_getRoleText(role)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _roleFilter = value!);
                          _loadUsers();
                        },
                        decoration: InputDecoration(
                          labelText: 'Filter by Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Bulk Actions
          _buildBulkActions(),
          
          // Table Header
          _buildTableHeader(),
          
          // Users Table
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Loading users...',
                          style: TextStyle(color: AppColors.textGray),
                        ),
                      ],
                    ),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: AppColors.textLight,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textGray,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Try changing your search or filter',
                              style: TextStyle(color: AppColors.textLight),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          return _buildTableRow(_users[index]);
                        },
                      ),
          ),
          
          // Pagination
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }
}