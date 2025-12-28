// lib/screens/admin/system_settings.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/admin_api_service.dart';

class SystemSettings extends StatefulWidget {
  @override
  _SystemSettingsState createState() => _SystemSettingsState();
}

class _SystemSettingsState extends State<SystemSettings> {
  List<dynamic> _settings = [];
  bool _isLoading = true;
  String _categoryFilter = 'all';
  
  Map<String, dynamic> _changedSettings = {};
  Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final Map<String, String> queryParams = {};
      if (_categoryFilter != 'all') queryParams['category'] = _categoryFilter;

      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.get(
        Uri.parse('${AdminApiService.baseUrl}/settings').replace(
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
          _settings = data['data'] ?? [];
          _initializeControllers();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load settings');
      }
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    _controllers.clear();
    for (var setting in _settings) {
      final key = setting['setting_key'];
      final value = setting['setting_value']?.toString() ?? '';
      _controllers[key] = TextEditingController(text: value);
    }
  }

  Future<void> _updateSetting(String settingId, String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.put(
        Uri.parse('${AdminApiService.baseUrl}/settings/$settingId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'setting_value': value}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setting updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSettings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update setting'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveAllChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.post(
        Uri.parse('${AdminApiService.baseUrl}/settings/batch-update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'settings': _changedSettings}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All changes saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _changedSettings.clear();
        _loadSettings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save changes'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSettingWidget(Map<String, dynamic> setting) {
    final key = setting['setting_key'];
    final type = setting['setting_type'];
    final isEditable = setting['is_editable'] ?? true;
    final currentValue = setting['setting_value'];
    final controller = _controllers[key];

    Widget fieldWidget;

    switch (type) {
      case 'boolean':
        final boolValue = currentValue == true || currentValue == 'true';
        fieldWidget = Switch(
          value: boolValue,
          onChanged: isEditable
              ? (value) => _updateSetting(
                    setting['setting_id'].toString(),
                    key,
                    value,
                  )
              : null,
          activeColor: Colors.green,
        );
        break;

      case 'number':
        fieldWidget = TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          enabled: isEditable,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            suffixIcon: isEditable
                ? IconButton(
                    icon: Icon(Icons.save),
                    onPressed: () => _updateSetting(
                      setting['setting_id'].toString(),
                      key,
                      double.tryParse(controller!.text) ?? 0,
                    ),
                  )
                : null,
          ),
          onChanged: isEditable
              ? (value) {
                  _changedSettings[key] = double.tryParse(value) ?? 0;
                }
              : null,
        );
        break;

      case 'string':
      case 'text':
      case 'json':
      case 'array':
      default:
        fieldWidget = TextField(
          controller: controller,
          enabled: isEditable,
          maxLines: type == 'text' ? 3 : 1,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            suffixIcon: isEditable
                ? IconButton(
                    icon: Icon(Icons.save),
                    onPressed: () => _updateSetting(
                      setting['setting_id'].toString(),
                      key,
                      controller!.text,
                    ),
                  )
                : null,
          ),
          onChanged: isEditable
              ? (value) {
                  _changedSettings[key] = value;
                }
              : null,
        );
        break;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setting['display_name'] ?? key,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (setting['description'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            setting['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isEditable)
                  Chip(
                    label: Text(
                      'Read Only',
                      style: TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.grey[200],
                  ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(child: fieldWidget),
              ],
            ),
            
            SizedBox(height: 8),
            
            Row(
              children: [
                Chip(
                  label: Text(setting['category']),
                  backgroundColor: Colors.blue[50],
                ),
                SizedBox(width: 8),
                Text(
                  'Type: ${_getTypeText(type)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'boolean': return 'Boolean';
      case 'number': return 'Number';
      case 'string': return 'String';
      case 'text': return 'Text';
      case 'json': return 'JSON';
      case 'array': return 'Array';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _getCategories();

    return Scaffold(
      appBar: AppBar(
        title: Text('System Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _loadSettings(),
          ),
          if (_changedSettings.isNotEmpty)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveAllChanges,
              tooltip: 'Save All Changes',
            ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _categoryFilter,
              items: [
                DropdownMenuItem(value: 'all', child: Text('All Categories')),
                ...categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() => _categoryFilter = value!);
                _loadSettings();
              },
              decoration: InputDecoration(
                labelText: 'Filter by Category',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          
          // Save All Button
          if (_changedSettings.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have ${_changedSettings.length} unsaved changes',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveAllChanges,
                    icon: Icon(Icons.save, size: 16),
                    label: Text('Save All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          
          // Settings List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _settings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.settings, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No settings found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Try selecting a different category',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _settings.length,
                        itemBuilder: (context, index) {
                          return _buildSettingWidget(_settings[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _changedSettings.isNotEmpty
          ? FloatingActionButton(
              onPressed: _saveAllChanges,
              child: Icon(Icons.save),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }

  List<String> _getCategories() {
    final categories = <String>{};
    for (var setting in _settings) {
      categories.add(setting['category']);
    }
    return categories.toList();
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}