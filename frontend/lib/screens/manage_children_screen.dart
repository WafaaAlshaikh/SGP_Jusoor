import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../services/api_service.dart';
import '../widgets/child_summary_stats.dart';
import '../widgets/child_card.dart';
import '../widgets/child_bottom_sheet.dart';
import '../widgets/child_form_dialog.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_state_widget.dart';

enum ChildSortOption { name, age, lastSession, registrationStatus }

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key});

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  List<Child> _allChildren = [];
  List<Child> _filteredChildren = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _searchQuery = '';
  String _selectedCondition = 'All';
  String _selectedRegistrationStatus = 'All';
  ChildSortOption _sortOption = ChildSortOption.name;

  @override
  void initState() {
    super.initState();
    _fetchChildren();
  }

  Future<void> _fetchChildren({int page = 1, int limit = 100}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception('No token');

      String sortStr = 'name';
      String orderStr = 'asc';

      switch (_sortOption) {
        case ChildSortOption.name:
          sortStr = 'name';
          orderStr = 'asc';
          break;
        case ChildSortOption.age:
          sortStr = 'age';
          orderStr = 'desc';
          break;
        case ChildSortOption.lastSession:
          sortStr = 'lastSession';
          orderStr = 'desc';
          break;
        case ChildSortOption.registrationStatus:
          sortStr = 'registration_status';
          orderStr = 'asc';
          break;
      }

      final resp = await ApiService.getChildren(
        token: token,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        diagnosis: _selectedCondition == 'All' ? null : _selectedCondition,
        registrationStatus: _selectedRegistrationStatus == 'All' ? null : _selectedRegistrationStatus,
        sort: sortStr,
        order: orderStr,
        page: page,
        limit: limit,
      );

      final List<dynamic> list = resp['data'] ?? [];
      final fetched = list.map((c) => Child.fromJson(c)).toList();

      setState(() {
        _allChildren = fetched;
        _filteredChildren = List.from(_allChildren);
        _isLoading = false;
      });

      print('✅ Loaded ${_allChildren.length} children');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      print('❌ Fetch children error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load children: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  final List<String> _conditions = [
    'All',
    'ASD',
    'ADHD',
    'Down Syndrome',
    'Speech & Language Disorder'
  ];

  final List<String> _registrationStatuses = [
    'All',
    'Not Registered',
    'Pending',
    'Approved',
    'Archived'
  ];

  void _applyLocalFilters() {
    _filteredChildren = _allChildren.where((child) {
      final matchesSearch = _searchQuery.isEmpty ||
          child.fullName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCondition = _selectedCondition == 'All' ||
          (child.condition ?? '') == _selectedCondition;

      final matchesRegistrationStatus = _selectedRegistrationStatus == 'All' ||
          child.registrationStatus == _selectedRegistrationStatus;

      return matchesSearch && matchesCondition && matchesRegistrationStatus;
    }).toList();

    _sortChildren();
  }

  void _sortChildren() {
    switch (_sortOption) {
      case ChildSortOption.name:
        _filteredChildren.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        break;
      case ChildSortOption.age:
        _filteredChildren.sort((a, b) => (b.age ?? 0).compareTo(a.age ?? 0));
        break;
      case ChildSortOption.lastSession:
        _filteredChildren.sort((a, b) {
          final dateA = a.lastSessionDate ?? DateTime(1900);
          final dateB = b.lastSessionDate ?? DateTime(1900);
          return dateB.compareTo(dateA);
        });
        break;
      case ChildSortOption.registrationStatus:
        _filteredChildren.sort((a, b) => a.registrationStatus.compareTo(b.registrationStatus));
        break;
    }
  }

  void _openAddEditChild({Child? child}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ChildFormDialog(child: child),
    );

    if (changed == true) {
      await _fetchChildren();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(child == null ? 'Child added successfully!' : 'Child updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _confirmDelete(Child child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 12),
            Text('Confirm Deletion', style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            )),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete ${child.fullName}? This action cannot be undone.',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? '';
        await ApiService.deleteChild(token, child.id);
        setState(() {
          _allChildren.removeWhere((c) => c.id == child.id);
          _applyLocalFilters();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${child.fullName} deleted successfully'),
            backgroundColor: Colors.green.shade500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red.shade500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter & Sort',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 24, color: Colors.grey.shade600),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      padding: EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Refine your children list',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 24),

              _buildFilterSection(
                title: 'Condition',
                icon: Icons.medical_services_outlined,
                options: _conditions,
                selectedValue: _selectedCondition,
                onChanged: (value) {
                  setState(() => _selectedCondition = value);
                },
              ),

              SizedBox(height: 24),

              _buildFilterSection(
                title: 'Registration Status',
                icon: Icons.assignment_turned_in_outlined,
                options: _registrationStatuses,
                selectedValue: _selectedRegistrationStatus,
                onChanged: (value) {
                  setState(() => _selectedRegistrationStatus = value);
                },
              ),

              SizedBox(height: 24),

              _buildSortSection(),

              SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCondition = 'All';
                          _selectedRegistrationStatus = 'All';
                          _sortOption = ChildSortOption.name;
                        });
                        Navigator.pop(context);
                        _fetchChildren();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text('Reset All', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _fetchChildren();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required List<String> options,
    required String selectedValue,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return ChoiceChip(
              label: Text(
                option,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                onChanged(selected ? option : 'All');
              },
              backgroundColor: Colors.grey.shade100,
              selectedColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              labelPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.sort_rounded, size: 20, color: Theme.of(context).primaryColor),
            SizedBox(width: 8),
            Text(
              'Sort By',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: ChildSortOption.values.map((option) {
              final isSelected = _sortOption == option;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                leading: Radio<ChildSortOption>(
                  value: option,
                  groupValue: _sortOption,
                  onChanged: (value) {
                    setState(() => _sortOption = value!);
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
                title: Text(
                  _getSortOptionText(option),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade700,
                  ),
                ),
                trailing: isSelected ? Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ) : null,
                onTap: () {
                  setState(() => _sortOption = option);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: option == ChildSortOption.values.first
                      ? BorderRadius.vertical(top: Radius.circular(12))
                      : option == ChildSortOption.values.last
                      ? BorderRadius.vertical(bottom: Radius.circular(12))
                      : BorderRadius.zero,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getSortOptionText(ChildSortOption option) {
    switch (option) {
      case ChildSortOption.name:
        return 'Name (A-Z)';
      case ChildSortOption.age:
        return 'Age (Youngest first)';
      case ChildSortOption.lastSession:
        return 'Last Session (Recent first)';
      case ChildSortOption.registrationStatus:
        return 'Registration Status';
    }
  }

  void _showSearchDialog() {
    String tempSearchQuery = _searchQuery;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Search Children',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 24, color: Colors.grey.shade600),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      padding: EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter child name...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (value) {
                  tempSearchQuery = value;
                },
                onSubmitted: (value) {
                  _applySearch(value);
                  Navigator.pop(context);
                },
              ),
              if (_searchQuery.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue.shade600),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current search: "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 24),
              Row(
                children: [
                  if (_searchQuery.isNotEmpty)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _applySearch('');
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text('Clear Search', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (_searchQuery.isNotEmpty) SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _applySearch(tempSearchQuery);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('Search', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _applySearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchChildren();
  }

  void _showQuickSymptomsSearch() {
    String symptomsText = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Symptoms Analysis',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Describe symptoms...',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., لا يتكلم، حركات متكررة، صعوبة تواصل...',
                ),
                onChanged: (value) => symptomsText = value,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (symptomsText.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please describe symptoms')),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        await _analyzeSymptoms(symptomsText);
                      },
                      child: Text('Analyze Symptoms'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _analyzeSymptoms(String symptoms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      setState(() {
        _isLoading = true;
      });

      final result = await ApiService.searchBySymptoms(token, symptoms, null);

      if (result['success'] == true) {
        _showSymptomsAnalysisResult(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Analysis failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSymptomsAnalysisResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Symptoms Analysis Results'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result['symptoms_analysis'] != null) ...[
                Text('Suggested Conditions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ..._buildAnalysisConditions(result['symptoms_analysis']),
              ],

              if (result['recommended_institutions'] != null &&
                  result['recommended_institutions'].isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Recommended Institutions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ..._buildAnalysisInstitutions(result['recommended_institutions']),
              ],

              if (result['next_steps'] != null) ...[
                SizedBox(height: 16),
                Text('Next Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                if (result['next_steps'] is List)
                  ...(result['next_steps'] as List).map<Widget>((step) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $step'),
                    );
                  }).toList()
                else
                  Text(result['next_steps'].toString()),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openAddEditChild();
            },
            child: Text('Add Child with These Symptoms'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAnalysisConditions(Map<String, dynamic> analysis) {
    final conditions = analysis['suggested_conditions'] ?? [];
    return conditions.map<Widget>((condition) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.medical_services, size: 16),
        title: Text(condition['arabic_name'] ?? condition['name'] ?? 'Unknown'),
        trailing: Text('${(condition['confidence'] * 100).toStringAsFixed(1)}%'),
      );
    }).toList();
  }

  List<Widget> _buildAnalysisInstitutions(List<dynamic> institutions) {
    return institutions.map<Widget>((inst) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.school, size: 16),
        title: Text(inst['name'] ?? 'Unknown'),
        subtitle: Text('Match: ${inst['match_score']}%'),
      );
    }).toList();
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.orange.shade700,
          ),
        ),
        backgroundColor: Colors.orange.shade50,
        deleteIcon: Icon(Icons.close_rounded, size: 16, color: Colors.orange.shade600),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.orange.shade200),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.1),
                          Theme.of(context).primaryColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading Children',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we fetch your children',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenList() {
    return RefreshIndicator(
      onRefresh: _fetchChildren,
      color: Theme.of(context).primaryColor,
      backgroundColor: Colors.white,
      displacement: 20,
      edgeOffset: 10,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _filteredChildren.length,
        itemBuilder: (ctx, idx) {
          final child = _filteredChildren[idx];
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            child: ChildCard(
              child: child,
              onView: () => ChildBottomSheet.show(context, child: child),
              onEdit: () => _openAddEditChild(child: child),
              onDelete: () => _confirmDelete(child),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Children Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: _searchQuery.isNotEmpty ? Colors.orange.shade200 : Colors.white,
                  ),
                  onPressed: _showSearchDialog,
                  tooltip: 'Search',
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white.withOpacity(0.3),
                ),
                IconButton(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: _selectedCondition != 'All' || _selectedRegistrationStatus != 'All'
                        ? Colors.blue.shade200
                        : Colors.white,
                  ),
                  onPressed: _showFilterDialog,
                  tooltip: 'Filters',
                ),
              ],
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Column(
        children: [
          ChildSummaryStats(childrenList: _allChildren),

          if (_selectedCondition != 'All' || _selectedRegistrationStatus != 'All' || _searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_rounded, size: 16, color: Colors.orange.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_searchQuery.isNotEmpty)
                            _buildActiveFilterChip('Search: "$_searchQuery"', () {
                              _applySearch('');
                            }),
                          if (_selectedCondition != 'All')
                            _buildActiveFilterChip('Condition: $_selectedCondition', () {
                              setState(() => _selectedCondition = 'All');
                              _fetchChildren();
                            }),
                          if (_selectedRegistrationStatus != 'All')
                            _buildActiveFilterChip('Status: $_selectedRegistrationStatus', () {
                              setState(() => _selectedRegistrationStatus = 'All');
                              _fetchChildren();
                            }),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCondition = 'All';
                        _selectedRegistrationStatus = 'All';
                        _searchQuery = '';
                      });
                      _fetchChildren();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade600,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.clear_all_rounded, size: 16),
                        SizedBox(width: 4),
                        Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                ? ErrorStateWidget(onRetry: _fetchChildren)
                : _filteredChildren.isEmpty
                ? EmptyStateWidget(onAdd: () => _openAddEditChild())
                : _buildChildrenList(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: FloatingActionButton(
              onPressed: _showQuickSymptomsSearch,
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              heroTag: 'symptoms_search',
              child: Icon(Icons.psychology_outlined, size: 24),
            ),
          ),
          FloatingActionButton(
            onPressed: () => _openAddEditChild(),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            heroTag: 'add_child',
            child: Icon(Icons.add_rounded, size: 28),
          ),
        ],
      ),
    );
  }
}