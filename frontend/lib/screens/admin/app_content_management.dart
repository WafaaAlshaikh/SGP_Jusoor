// lib/screens/admin/app_content_management.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/admin_api_service.dart';

class AppContentManagement extends StatefulWidget {
  @override
  _AppContentManagementState createState() => _AppContentManagementState();
}

class _AppContentManagementState extends State<AppContentManagement> {
  List<dynamic> _contents = [];
  bool _isLoading = true;
  String _contentTypeFilter = 'help_section';
  Map<String, dynamic> _selectedContent = {};
  bool _showForm = false;
  bool _isEditing = false;

  final Map<String, String> _contentTypes = {
    'help_section': 'Help Sections',
    'about_section': 'About Sections',
    'faq': 'FAQ',
    'privacy_policy': 'Privacy Policy',
    'terms_of_service': 'Terms of Service',
  };

  final _formKey = GlobalKey<FormState>();
  final _titleArController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _contentArController = TextEditingController();
  final _contentEnController = TextEditingController();
  final _sectionKeyController = TextEditingController();
  final _displayOrderController = TextEditingController();
  final _iconController = TextEditingController();

  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadContents();
  }

  Future<void> _loadContents() async {
    try {
      setState(() => _isLoading = true);
      
      final token = await AdminApiService.getToken();
      final response = await http.get(
        Uri.parse('${AdminApiService.baseUrl}/content')
            .replace(queryParameters: {
          'content_type': _contentTypeFilter,
          'page': '1',
          'limit': '100',
        }),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _contents = data['data']['contents'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load content');
      }
    } catch (e) {
      print('Error loading content: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showEditForm(Map<String, dynamic>? content) {
    if (content != null) {
      _selectedContent = content;
      _isEditing = true;
      
      _titleArController.text = content['title_ar'] ?? '';
      _titleEnController.text = content['title_en'] ?? '';
      _contentArController.text = content['content_ar'] ?? '';
      _contentEnController.text = content['content_en'] ?? '';
      _sectionKeyController.text = content['section_key'] ?? '';
      _displayOrderController.text = content['display_order']?.toString() ?? '0';
      _iconController.text = content['icon'] ?? '';
      _isActive = content['is_active'] ?? true;
    } else {
      _selectedContent = {};
      _isEditing = false;
      
      _titleArController.clear();
      _titleEnController.clear();
      _contentArController.clear();
      _contentEnController.clear();
      _sectionKeyController.clear();
      _displayOrderController.text = '0';
      _iconController.clear();
      _isActive = true;
    }

    setState(() => _showForm = true);
  }

  Future<void> _saveContent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final token = await AdminApiService.getToken();
      final url = _isEditing
          ? '${AdminApiService.baseUrl}/content/${_selectedContent['content_id']}'
          : '${AdminApiService.baseUrl}/content';

      final payload = {
        'content_type': _contentTypeFilter,
        'title_ar': _titleArController.text,
        'title_en': _titleEnController.text,
        'content_ar': _contentArController.text,
        'content_en': _contentEnController.text,
        'section_key': _sectionKeyController.text,
        'display_order': int.parse(_displayOrderController.text),
        'is_active': _isActive,
        'icon': _iconController.text.isNotEmpty ? _iconController.text : null,
        'metadata': {}
      };

      final response = _isEditing
          ? await http.put(Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: json.encode(payload))
          : await http.post(Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: json.encode(payload));

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Content updated successfully' : 'Content created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        _showForm = false;
        _loadContents();
        setState(() {});
      } else {
        throw Exception('Failed to save content');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving content: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteContent(String contentId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this content?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await AdminApiService.getToken();
      final response = await http.delete(
        Uri.parse('${AdminApiService.baseUrl}/content/$contentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Content deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadContents();
      } else {
        throw Exception('Failed to delete content');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting content: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildContentCard(Map<String, dynamic> content) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: content['icon'] != null
            ? Icon(_getIconFromString(content['icon']), color: Colors.blue)
            : CircleAvatar(
                child: Text(content['section_key']?.substring(0, 1).toUpperCase() ?? '?'),
              ),
        title: Text(
          content['title_ar'] ?? 'No Title',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content['title_en'] ?? 'No English Title'),
            SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('Order: ${content['display_order']}'),
                  backgroundColor: Colors.grey[200],
                ),
                SizedBox(width: 4),
                Chip(
                  label: Text(content['is_active'] ? 'Active' : 'Inactive'),
                  backgroundColor: content['is_active'] ? Colors.green[100] : Colors.red[100],
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
              value: 'edit',
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
              value: 'delete',
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditForm(content);
            } else if (value == 'delete') {
              _deleteContent(content['content_id'].toString());
            }
          },
        ),
        onTap: () {
          _showContentDetails(content);
        },
      ),
    );
  }

  void _showContentDetails(Map<String, dynamic> content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(content['title_ar'] ?? 'Content Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Arabic Title', content['title_ar']),
              _buildDetailItem('English Title', content['title_en']),
              _buildDetailItem('Section Key', content['section_key']),
              _buildDetailItem('Display Order', content['display_order']?.toString()),
              _buildDetailItem('Status', content['is_active'] ? 'Active' : 'Inactive'),
              SizedBox(height: 16),
              Text('Arabic Content:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(content['content_ar'] ?? 'No content'),
              SizedBox(height: 16),
              Text('English Content:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(content['content_en'] ?? 'No content'),
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

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }

  IconData _getIconFromString(String iconName) {
    final iconMap = {
      'help': Icons.help,
      'contact_support': Icons.contact_support,
      'feedback': Icons.feedback,
      'star': Icons.star,
      'info': Icons.info,
      'description': Icons.description,
      'security': Icons.security,
      'copyright': Icons.copyright,
      'email': Icons.email,
      'phone': Icons.phone,
      'chat': Icons.chat,
    };
    return iconMap[iconName] ?? Icons.article;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Content Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadContents,
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showEditForm(null),
          ),
        ],
      ),
      body: _showForm
          ? _buildContentForm()
          : Column(
              children: [
                // Filter
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    value: _contentTypeFilter,
                    items: _contentTypes.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _contentTypeFilter = value!);
                      _loadContents();
                    },
                    decoration: InputDecoration(
                      labelText: 'Content Type',
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                  ),
                ),

                // Content List
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _contents.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.article, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No content found',
                                    style: TextStyle(fontSize: 18, color: Colors.grey),
                                  ),
                                  SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _showEditForm(null),
                                    icon: Icon(Icons.add),
                                    label: Text('Create New Content'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _contents.length,
                              itemBuilder: (context, index) {
                                return _buildContentCard(_contents[index]);
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildContentForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit Content' : 'Create New Content',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // Arabic Title
              TextFormField(
                controller: _titleArController,
                decoration: InputDecoration(
                  labelText: 'Arabic Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Arabic title is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // English Title
              TextFormField(
                controller: _titleEnController,
                decoration: InputDecoration(
                  labelText: 'English Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'English title is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Section Key
              TextFormField(
                controller: _sectionKeyController,
                decoration: InputDecoration(
                  labelText: 'Section Key *',
                  border: OutlineInputBorder(),
                  helperText: 'Unique key (e.g., help_center, privacy_policy)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Section key is required';
                  }
                  if (!RegExp(r'^[a-z_]+$').hasMatch(value)) {
                    return 'Use lowercase letters and underscores only';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Display Order
              TextFormField(
                controller: _displayOrderController,
                decoration: InputDecoration(
                  labelText: 'Display Order',
                  border: OutlineInputBorder(),
                  helperText: 'Lower number appears first',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),

              // Icon
              TextFormField(
                controller: _iconController,
                decoration: InputDecoration(
                  labelText: 'Icon Name',
                  border: OutlineInputBorder(),
                  helperText: 'Material icon name (e.g., help, info)',
                ),
              ),
              SizedBox(height: 12),

              // Arabic Content
              TextFormField(
                controller: _contentArController,
                decoration: InputDecoration(
                  labelText: 'Arabic Content *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Arabic content is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // English Content
              TextFormField(
                controller: _contentEnController,
                decoration: InputDecoration(
                  labelText: 'English Content *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'English content is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Active Status
              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() => _isActive = value ?? true);
                    },
                  ),
                  Text('Active'),
                ],
              ),
              SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _showForm = false);
                    },
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveContent,
                    child: Text(_isEditing ? 'Update' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}