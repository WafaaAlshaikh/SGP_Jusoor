import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/child_model.dart';
import '../services/api_service.dart';
import '../widgets/child_summary_stats.dart';
import '../widgets/child_card.dart';
import '../widgets/child_bottom_sheet.dart';
import '../widgets/child_form_dialog.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_state_widget.dart';
import '../theme/app_colors.dart';

enum ChildSortOption { name, age, lastSession, registrationStatus }

class ManageChildrenScreen extends StatefulWidget {
  final Map<String, dynamic>? screeningData;

  const ManageChildrenScreen({super.key, this.screeningData});

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
    _initializeData();
    _fetchChildren();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.screeningData != null) {
        _openAddEditChild(screeningData: widget.screeningData);
      }
    });
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

      setState(() {
        _allChildren = fetched;
        _filteredChildren = List.from(_allChildren);
        _isLoading = false;
        _applyLocalFilters();
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load children: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    if (_filteredChildren.isEmpty) return;

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

  void _openAddEditChild({Child? child, Map<String, dynamic>? screeningData}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ChildFormDialog(
        child: child,
        screeningData: screeningData,
      ),
    );

    if (changed == true) {
      await _fetchChildren();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(child == null
              ? (screeningData != null
              ? 'Child added from screening results!'
              : 'Child added successfully!')
              : 'Child updated successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _confirmDelete(Child child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
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
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: AppColors.error, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Child?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete ${child.fullName}? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textGray,
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
                        foregroundColor: AppColors.textGray,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: AppColors.textGray.withOpacity(0.3)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
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

        final removedChild = child;

        setState(() {
          _allChildren.removeWhere((c) => c.id == child.id);
          _applyLocalFilters();
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${child.fullName} hidden'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('token') ?? '';
                  await ApiService.unhideChild(token, removedChild.id);

                  if (!mounted) return;

                  setState(() {
                    if (!_allChildren.any((c) => c.id == removedChild.id)) {
                      _allChildren.add(removedChild);
                    }
                    _applyLocalFilters();
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${removedChild.fullName} restored'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Restore failed: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
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
                    color: AppColors.textGray.withOpacity(0.3),
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
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 24, color: AppColors.textGray),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.background,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Refine your children list',
                style: TextStyle(
                  color: AppColors.textGray,
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
                        foregroundColor: AppColors.textGray,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: AppColors.textGray.withOpacity(0.3)),
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
                        backgroundColor: AppColors.primary,
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
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: BoxConstraints(
            maxHeight: 120,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((option) {
                final isSelected = selectedValue == option;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  constraints: BoxConstraints(
                    maxWidth: 150,
                  ),
                  child: FilterChip(
                    label: Text(
                      option,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      onChanged(selected ? option : 'All');
                    },
                    backgroundColor: AppColors.background,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.textGray.withOpacity(0.2),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
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
            Icon(Icons.sort_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Sort By',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.textGray.withOpacity(0.2)),
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
                  activeColor: AppColors.primary,
                ),
                title: Text(
                  _getSortOptionText(option),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textDark,
                  ),
                ),
                trailing: isSelected ? Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.primary,
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
    Timer? _debounceTimer;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        color: AppColors.textGray.withOpacity(0.3),
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
                          color: AppColors.textDark,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, size: 24, color: AppColors.textGray),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.background,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    controller: TextEditingController(text: tempSearchQuery),
                    decoration: InputDecoration(
                      hintText: 'Enter child name...',
                      hintStyle: TextStyle(color: AppColors.textGray),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.textGray.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textGray),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    onChanged: (value) {
                      tempSearchQuery = value;

                      _debounceTimer?.cancel();

                      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                        _applySearch(tempSearchQuery);
                        setModalState(() {});
                      });
                    },
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live search is active. Results update as you type.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
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
                              _debounceTimer?.cancel();
                              _applySearch('');
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textGray,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: AppColors.textGray.withOpacity(0.3)),
                            ),
                            child: const Text('Clear Search'),
                          ),
                        ),
                      if (_searchQuery.isNotEmpty) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _debounceTimer?.cancel();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _debounceTimer?.cancel();
    });
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
      backgroundColor: AppColors.surface,
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
                    color: AppColors.textGray.withOpacity(0.3),
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
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textGray),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Describe symptoms...',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.textGray.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  hintText: 'e.g., speech delay, repetitive movements, communication difficulty...',
                  hintStyle: TextStyle(color: AppColors.textGray.withOpacity(0.6)),
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
                        foregroundColor: AppColors.textGray,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: AppColors.textGray.withOpacity(0.3)),
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
                              backgroundColor: AppColors.warning,
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
                        backgroundColor: AppColors.primary,
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
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
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
        backgroundColor: AppColors.surface,
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
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.psychology, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Symptoms Analysis Results',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
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
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        const SizedBox(height: 8),
                        ..._buildAnalysisConditions(result['symptoms_analysis']),
                      ],

                      if (result['recommended_institutions'] != null &&
                          (result['recommended_institutions'] as List).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Recommended Institutions:',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        const SizedBox(height: 8),
                        ..._buildAnalysisInstitutions(result['recommended_institutions']),
                      ],

                      if (result['next_steps'] != null) ...[
                        const SizedBox(height: 16),
                        Text('Next Steps:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        const SizedBox(height: 8),
                        if (result['next_steps'] is List)
                          ...(result['next_steps'] as List).map<Widget>((step) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('• $step', style: TextStyle(color: AppColors.textGray)),
                            );
                          }).toList()
                        else
                          Text(result['next_steps'].toString(), style: TextStyle(color: AppColors.textGray)),
                      ],

                      if (result['symptoms_analysis'] == null &&
                          result['recommended_institutions'] == null &&
                          result['next_steps'] == null) ...[
                        Text('No analysis results available.',
                            style: TextStyle(color: AppColors.textGray)),
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
                        foregroundColor: AppColors.textGray,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: AppColors.textGray.withOpacity(0.3)),
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
                        backgroundColor: AppColors.primary,
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
        Text('No conditions suggested', style: TextStyle(color: AppColors.textGray))
      ];
    }

    return conditions.map<Widget>((condition) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.medical_services, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(condition['arabic_name'] ?? condition['name'] ?? 'Unknown',
                  style: TextStyle(fontSize: 14, color: AppColors.textDark)),
            ),
            Text('${(condition['confidence'] * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildAnalysisInstitutions(List<dynamic> institutions) {
    if (institutions.isEmpty) {
      return [
        Text('No institutions recommended', style: TextStyle(color: AppColors.textGray))
      ];
    }

    return institutions.map<Widget>((inst) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.school, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inst['name'] ?? 'Unknown', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                  if (inst['match_score'] != null)
                    Text('Match: ${inst['match_score']}%',
                        style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildActiveFiltersSection() {
    final hasActiveFilters = _selectedCondition != 'All' ||
        _selectedRegistrationStatus != 'All' ||
        _searchQuery.isNotEmpty;

    if (!hasActiveFilters) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Active Filters',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
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
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear_all_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Clear All',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
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
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.4,
      ),
      child: InputChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        backgroundColor: AppColors.primary.withOpacity(0.08),
        deleteIcon: Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Children',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch your children',
            style: TextStyle(
              color: AppColors.textGray,
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
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredChildren.length,
        itemBuilder: (ctx, idx) {
          if (idx >= _filteredChildren.length) {
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

  Widget _buildSearchBar() {
    Timer? _debounceTimer;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
          Icon(Icons.search_rounded, color: AppColors.textLight, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: _searchQuery),
              decoration: InputDecoration(
                hintText: 'Search for children...',
                hintStyle: TextStyle(color: AppColors.textLight),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
              ),
              onChanged: (value) {
                _debounceTimer?.cancel();

                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  _applySearch(value);
                });
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, color: AppColors.textLight, size: 20),
              onPressed: () {
                _debounceTimer?.cancel();
                _applySearch('');
              },
            ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.textLight.withOpacity(0.3),
          ),
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 24),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildStatItem(_allChildren.length.toString(), 'Total', Icons.people_alt_rounded),
          ),
          Expanded(
            child: _buildStatItem(
              _allChildren.where((c) => c.registrationStatus == 'Pending').length.toString(),
              'Pending',
              Icons.pending_actions_rounded,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              _allChildren.where((c) => c.registrationStatus == 'Approved').length.toString(),
              'Approved',
              Icons.verified_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatsSection(),
          _buildActiveFiltersSection(),
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
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              heroTag: 'symptoms_search',
              child: const Icon(Icons.psychology_outlined, size: 24),
            ),
          ),
          FloatingActionButton(
            onPressed: () => _openAddEditChild(),
            backgroundColor: AppColors.primary,
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