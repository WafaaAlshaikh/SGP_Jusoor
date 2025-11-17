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

  // نظام الألوان المتناسق مع التطبيق
  final Color _primaryColor = const Color(0xFF7815A0);
  final Color _secondaryColor = const Color(0xFF976EF4);
  final Color _accentColor = const Color(0xFFCAA9F8);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;
  final Color _textPrimary = const Color(0xFF212529);
  final Color _textSecondary = const Color(0xFF6C757D);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _warningColor = const Color(0xFFFF9800);
  final Color _errorColor = const Color(0xFFF44336);

  @override
  void initState() {
    super.initState();
    _initializeData();
    _fetchChildren();
  }

  void _initializeData() {
    _allChildren = [];
    _filteredChildren = [];
    _searchQuery = '';
    _selectedCondition = 'All';
    _selectedRegistrationStatus = 'All';
    _sortOption = ChildSortOption.name;
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

      print('✅ Loaded ${fetched.length} children from API');
      print('📊 API response data length: ${list.length}');

      setState(() {
        _allChildren = fetched;
        _filteredChildren = List.from(_allChildren);
        _isLoading = false;
        _applyLocalFilters(); // تطبيق الفلاتر بعد جلب البيانات
      });

    } catch (e) {
      print('❌ Fetch children error: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load children: $e'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    print('🔍 Applying filters - Search: "$_searchQuery", Condition: "$_selectedCondition", Status: "$_selectedRegistrationStatus"');

    _filteredChildren = _allChildren.where((child) {
      final matchesSearch = _searchQuery.isEmpty ||
          child.fullName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCondition = _selectedCondition == 'All' ||
          (child.condition ?? '') == _selectedCondition;

      final matchesRegistrationStatus = _selectedRegistrationStatus == 'All' ||
          child.registrationStatus == _selectedRegistrationStatus;

      return matchesSearch && matchesCondition && matchesRegistrationStatus;
    }).toList();

    print('📋 After filtering: ${_filteredChildren.length} children');

    _sortChildren();
  }

  void _sortChildren() {
    if (_filteredChildren.isEmpty) {
      print('ℹ️ No children to sort');
      return;
    }

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

    print('🔄 Sorted children by ${_sortOption.name}');
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
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _confirmDelete(Child child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: _errorColor, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Child?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete ${child.fullName}? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: _textSecondary.withOpacity(0.3)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            backgroundColor: _successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: _errorColor,
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
      backgroundColor: _surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter & Sort',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 24, color: _textSecondary),
                    style: IconButton.styleFrom(
                      backgroundColor: _backgroundColor,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Refine your children list',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              _buildFilterSection(
                title: 'Condition',
                icon: Icons.medical_services_outlined,
                options: _conditions,
                selectedValue: _selectedCondition,
                onChanged: (value) {
                  setState(() => _selectedCondition = value);
                },
              ),

              const SizedBox(height: 24),

              _buildFilterSection(
                title: 'Registration Status',
                icon: Icons.assignment_turned_in_outlined,
                options: _registrationStatuses,
                selectedValue: _selectedRegistrationStatus,
                onChanged: (value) {
                  setState(() => _selectedRegistrationStatus = value);
                },
              ),

              const SizedBox(height: 24),

              _buildSortSection(),

              const SizedBox(height: 32),

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
                        foregroundColor: _textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: _textSecondary.withOpacity(0.3)),
                      ),
                      child: const Text('Reset All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _fetchChildren();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply Filters'),
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
            Icon(icon, size: 20, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return FilterChip(
              label: Text(
                option,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : _textPrimary,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                onChanged(selected ? option : 'All');
              },
              backgroundColor: _backgroundColor,
              selectedColor: _primaryColor,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? _primaryColor : _textSecondary.withOpacity(0.2),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            Icon(Icons.sort_rounded, size: 20, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Sort By',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _textSecondary.withOpacity(0.2)),
          ),
          child: Column(
            children: ChildSortOption.values.map((option) {
              final isSelected = _sortOption == option;
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Radio<ChildSortOption>(
                  value: option,
                  groupValue: _sortOption,
                  onChanged: (value) {
                    setState(() => _sortOption = value!);
                  },
                  activeColor: _primaryColor,
                ),
                title: Text(
                  _getSortOptionText(option),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? _primaryColor : _textPrimary,
                  ),
                ),
                trailing: isSelected ? Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: _primaryColor,
                ) : null,
                onTap: () {
                  setState(() => _sortOption = option);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: option == ChildSortOption.values.first
                      ? const BorderRadius.vertical(top: Radius.circular(12))
                      : option == ChildSortOption.values.last
                      ? const BorderRadius.vertical(bottom: Radius.circular(12))
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
      backgroundColor: _surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Search Children',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 24, color: _textSecondary),
                    style: IconButton.styleFrom(
                      backgroundColor: _backgroundColor,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter child name...',
                  hintStyle: TextStyle(color: _textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _textSecondary.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor, width: 2),
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: _textSecondary),
                  filled: true,
                  fillColor: _backgroundColor,
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: _primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current search: "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 12,
                            color: _primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
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
                          foregroundColor: _textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: _textSecondary.withOpacity(0.3)),
                        ),
                        child: const Text('Clear Search'),
                      ),
                    ),
                  if (_searchQuery.isNotEmpty) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _applySearch(tempSearchQuery);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Search'),
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
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Symptoms Analysis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: _textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Describe symptoms...',
                  labelStyle: TextStyle(color: _textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _textSecondary.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor, width: 2),
                  ),
                  hintText: 'e.g., لا يتكلم، حركات متكررة، صعوبة تواصل...',
                  hintStyle: TextStyle(color: _textSecondary.withOpacity(0.6)),
                ),
                onChanged: (value) => symptomsText = value,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: _textSecondary.withOpacity(0.3)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (symptomsText.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Please describe symptoms'),
                              backgroundColor: _warningColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        await _analyzeSymptoms(symptomsText);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Analyze Symptoms'),
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
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      builder: (context) => Dialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.psychology, color: _primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Symptoms Analysis Results',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (result['symptoms_analysis'] != null) ...[
                        Text('Suggested Conditions:',
                            style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary)),
                        const SizedBox(height: 8),
                        ..._buildAnalysisConditions(result['symptoms_analysis']),
                      ],

                      if (result['recommended_institutions'] != null &&
                          (result['recommended_institutions'] as List).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Recommended Institutions:',
                            style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary)),
                        const SizedBox(height: 8),
                        ..._buildAnalysisInstitutions(result['recommended_institutions']),
                      ],

                      if (result['next_steps'] != null) ...[
                        const SizedBox(height: 16),
                        Text('Next Steps:', style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary)),
                        const SizedBox(height: 8),
                        if (result['next_steps'] is List)
                          ...(result['next_steps'] as List).map<Widget>((step) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('• $step', style: TextStyle(color: _textSecondary)),
                            );
                          }).toList()
                        else
                          Text(result['next_steps'].toString(), style: TextStyle(color: _textSecondary)),
                      ],

                      if (result['symptoms_analysis'] == null &&
                          result['recommended_institutions'] == null &&
                          result['next_steps'] == null) ...[
                        Text('No analysis results available.',
                            style: TextStyle(color: _textSecondary)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: _textSecondary.withOpacity(0.3)),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openAddEditChild();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add Child'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnalysisConditions(Map<String, dynamic> analysis) {
    final conditions = analysis['suggested_conditions'] ?? [];

    if (conditions.isEmpty) {
      return [
        Text('No conditions suggested', style: TextStyle(color: _textSecondary))
      ];
    }

    return conditions.map<Widget>((condition) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.medical_services, size: 16, color: _primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(condition['arabic_name'] ?? condition['name'] ?? 'Unknown',
                  style: TextStyle(fontSize: 14, color: _textPrimary)),
            ),
            Text('${(condition['confidence'] * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryColor)),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildAnalysisInstitutions(List<dynamic> institutions) {
    if (institutions.isEmpty) {
      return [
        Text('No institutions recommended', style: TextStyle(color: _textSecondary))
      ];
    }

    return institutions.map<Widget>((inst) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.school, size: 16, color: _primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inst['name'] ?? 'Unknown', style: TextStyle(fontSize: 14, color: _textPrimary)),
                  if (inst['match_score'] != null)
                    Text('Match: ${inst['match_score']}%',
                        style: TextStyle(fontSize: 12, color: _textSecondary)),
                ],
              ),
            ),
          ],
        ),
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
            color: _primaryColor,
          ),
        ),
        backgroundColor: _primaryColor.withOpacity(0.1),
        deleteIcon: Icon(Icons.close_rounded, size: 16, color: _primaryColor),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _primaryColor.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Children',
            style: TextStyle(
              fontSize: 16,
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch your children',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenList() {
    if (_filteredChildren.isEmpty) {
      return EmptyStateWidget(onAdd: () => _openAddEditChild());
    }

    return RefreshIndicator(
      onRefresh: _fetchChildren,
      color: _primaryColor,
      backgroundColor: _surfaceColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredChildren.length,
        itemBuilder: (ctx, idx) {
          if (idx >= _filteredChildren.length) {
            print('⚠️ Warning: Index $idx out of bounds for filtered children list');
            return const SizedBox.shrink();
          }

          final child = _filteredChildren[idx];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
    return Scaffold(
      backgroundColor: _backgroundColor,
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: _searchQuery.isNotEmpty ? _accentColor : Colors.white,
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
                        ? _accentColor
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
        backgroundColor: _primaryColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Column(
        children: [
          ChildSummaryStats(childrenList: _allChildren),

          if (_selectedCondition != 'All' || _selectedRegistrationStatus != 'All' || _searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_rounded, size: 16, color: _primaryColor),
                  const SizedBox(width: 8),
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
                      foregroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.clear_all_rounded, size: 16),
                        const SizedBox(width: 4),
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
                : _buildChildrenList(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: FloatingActionButton(
              onPressed: _showQuickSymptomsSearch,
              backgroundColor: _secondaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              heroTag: 'symptoms_search',
              child: const Icon(Icons.psychology_outlined, size: 24),
            ),
          ),
          FloatingActionButton(
            onPressed: () => _openAddEditChild(),
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            heroTag: 'add_child',
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ],
      ),
    );
  }
}