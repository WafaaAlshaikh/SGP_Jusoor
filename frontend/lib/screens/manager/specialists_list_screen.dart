import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_specialist_service.dart';
import 'specialist_report_screen.dart';
import 'specialist_schedule_screen.dart';

class SpecialistsListScreen extends StatefulWidget {
  @override
  _SpecialistsListScreenState createState() => _SpecialistsListScreenState();
}

class _SpecialistsListScreenState extends State<SpecialistsListScreen> {
  List<dynamic> _specialists = [];
  List<dynamic> _filteredSpecialists = [];
  TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _selectedSpecialtyFilter = 'All';
  String _selectedRatingFilter = 'All';
  bool _isLoading = true;
  String _errorMessage = '';
  List<String> _specialties = [];
  List<String> _ratingFilters = ['All', '5 Stars', '4 Stars', '3 Stars', '2 Stars', '1 Star'];
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadSpecialists();
  }

  Future<void> _loadSpecialists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ManagerSpecialistService.getAllSpecialists();

      if (response['success'] == true) {
        final data = response['data'];
        List<dynamic> specialistsList = _extractSpecialistsList(data);
        _extractSpecialties(specialistsList);
        specialistsList = _fixSpecialistNames(specialistsList);

        setState(() {
          _specialists = specialistsList;
          _filteredSpecialists = _specialists;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load specialists';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Load specialists error: $e');
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _extractSpecialties(List<dynamic> specialists) {
    Set<String> specialtySet = {'All'};

    for (var specialist in specialists) {
      String? specialty = specialist['specialization'] ??
          specialist['specialty'] ??
          specialist['professional_info']?['specialization'] ??
          specialist['display_specialty'];

      if (specialty != null && specialty.isNotEmpty && specialty != 'null') {
        specialtySet.add(specialty);
      }
    }

    _specialties = specialtySet.toList();
  }

  List<dynamic> _extractSpecialistsList(dynamic data) {
    if (data == null) return [];

    if (data is List) return data;

    if (data is Map) {
      if (data['all_specialists'] is List) return data['all_specialists'];
      if (data['data'] is Map && data['data']['all_specialists'] is List) {
        return data['data']['all_specialists'];
      }
      if (data['specialists'] is List) return data['specialists'];

      for (var key in data.keys) {
        if (data[key] is List && (data[key] as List).isNotEmpty) {
          return data[key];
        }
      }
    }

    return [];
  }

  void _filterSpecialists() {
    String searchText = _searchController.text.toLowerCase();

    setState(() {
      _filteredSpecialists = _specialists.where((specialist) {
        String name = specialist['display_name']?.toString().toLowerCase() ?? '';
        String specialty = specialist['display_specialty']?.toString().toLowerCase() ?? '';
        String email = specialist['display_email']?.toString().toLowerCase() ?? '';
        String status = specialist['display_status']?.toString().toLowerCase() ?? '';
        double rating = specialist['display_rating']?.toDouble() ?? 0;

        // Search logic with better matching
        bool matchesSearch = searchText.isEmpty ||
            name.contains(searchText) ||
            specialty.contains(searchText) ||
            email.contains(searchText);

        // Status filter
        bool matchesStatusFilter = _selectedFilter == 'All' ||
            status == _selectedFilter.toLowerCase();

        // Specialty filter
        bool matchesSpecialtyFilter = _selectedSpecialtyFilter == 'All' ||
            specialty == _selectedSpecialtyFilter.toLowerCase();

        // Rating filter - New logic with ranges
        bool matchesRatingFilter = true;
        if (_selectedRatingFilter != 'All') {
          if (_selectedRatingFilter == '5 Stars') {
            matchesRatingFilter = rating >= 4.5 && rating <= 5.0;
          } else if (_selectedRatingFilter == '4 Stars') {
            matchesRatingFilter = rating >= 3.5 && rating < 4.5;
          } else if (_selectedRatingFilter == '3 Stars') {
            matchesRatingFilter = rating >= 2.5 && rating < 3.5;
          } else if (_selectedRatingFilter == '2 Stars') {
            matchesRatingFilter = rating >= 1.5 && rating < 2.5;
          } else if (_selectedRatingFilter == '1 Star') {
            matchesRatingFilter = rating >= 0.5 && rating < 1.5;
          }
        }

        return matchesSearch && matchesStatusFilter && matchesSpecialtyFilter && matchesRatingFilter;
      }).toList();
    });
  }

  Widget _buildFilterSection() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.accent2.withOpacity(0.2), width: 1),
        ),
        boxShadow: _showFilters ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ] : null,
      ),
      child: Column(
        children: [
          // Filter Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _showFilters ? AppColors.primary.withOpacity(0.1) : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showFilters ? AppColors.primary : AppColors.accent2,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 20,
                          color: _showFilters ? AppColors.primary : AppColors.textGray,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _showFilters ? AppColors.primary : AppColors.textDark,
                          ),
                        ),
                        SizedBox(width: 8),
                        if (_selectedFilter != 'All' || _selectedSpecialtyFilter != 'All' || _selectedRatingFilter != 'All')
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${[
                                _selectedFilter != 'All' ? 1 : 0,
                                _selectedSpecialtyFilter != 'All' ? 1 : 0,
                                _selectedRatingFilter != 'All' ? 1 : 0
                              ].where((x) => x > 0).length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Icon(
                      _showFilters ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: _showFilters ? AppColors.primary : AppColors.textGray,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filters Content
          if (_showFilters) ...[
            Divider(height: 0, color: AppColors.accent2.withOpacity(0.2)),

            // Status Filters
            _buildFilterCategory(
              title: 'Status',
              icon: Icons.verified_rounded,
              children: ['All', 'Approved', 'Pending', 'Archived'].map((status) {
                return _buildFilterChip(
                  label: status,
                  icon: status == 'Approved' ? Icons.check_circle_rounded :
                  status == 'Pending' ? Icons.pending_rounded :
                  status == 'Archived' ? Icons.archive_rounded : null,
                  isSelected: _selectedFilter == status,
                  onTap: () {
                    setState(() {
                      _selectedFilter = status;
                      _filterSpecialists();
                    });
                  },
                );
              }).toList(),
            ),

            // Specialty Filters
            if (_specialties.length > 1)
              _buildFilterCategory(
                title: 'Specialty',
                icon: Icons.medical_services_rounded,
                children: _specialties.map((specialty) {
                  return _buildFilterChip(
                    label: specialty,
                    icon: Icons.work_rounded,
                    isSelected: _selectedSpecialtyFilter == specialty,
                    onTap: () {
                      setState(() {
                        _selectedSpecialtyFilter = specialty;
                        _filterSpecialists();
                      });
                    },
                  );
                }).toList(),
              ),

            // Rating Filters
            _buildFilterCategory(
              title: 'Rating',
              icon: Icons.star_rounded,
              children: _ratingFilters.map((rating) {
                return _buildFilterChip(
                  label: rating,
                  icon: rating != 'All' ? Icons.star_rounded : null,
                  iconColor: rating != 'All' ? Colors.amber : null,
                  isSelected: _selectedRatingFilter == rating,
                  onTap: () {
                    setState(() {
                      _selectedRatingFilter = rating;
                      _filterSpecialists();
                    });
                  },
                );
              }).toList(),
            ),

            SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterCategory({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    Color? iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.accent2,
            width: isSelected ? 0 : 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : (iconColor ?? AppColors.textGray),
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _fixSpecialistNames(List<dynamic> specialists) {
    return specialists.map((specialist) {
      Map<String, dynamic> newSpec = Map.from(specialist);

      String? name = newSpec['full_name'] ??
          newSpec['name'] ??
          newSpec['personal_info']?['full_name'];

      String? email = newSpec['email'] ?? newSpec['personal_info']?['email'];

      String? specialty = newSpec['specialization'] ??
          newSpec['specialty'] ??
          newSpec['professional_info']?['specialization'];

      String? status = newSpec['status'] ??
          newSpec['account_status'] ??
          newSpec['approval_status'] ??
          newSpec['professional_info']?['approval_status'] ??
          'Unknown';

      double? rating = newSpec['rating']?.toDouble() ??
          newSpec['average_rating']?.toDouble() ??
          newSpec['professional_info']?['average_rating']?.toDouble() ??
          newSpec['display_rating']?.toDouble() ?? 0.0;

      newSpec['display_name'] = name ?? 'Specialist';
      newSpec['display_email'] = email ?? '';
      newSpec['display_specialty'] = specialty ?? 'Not Specified';
      newSpec['display_status'] = status;
      newSpec['display_rating'] = rating;

      return newSpec;
    }).toList();
  }

  Widget _buildSpecialistCard(Map<String, dynamic> specialist, int index) {
    final specialistId = specialist['specialist_id'] ?? specialist['id'] ?? 0;
    final name = specialist['display_name'] ?? 'Specialist';
    final specialty = specialist['display_specialty'] ?? 'Not Specified';
    final status = specialist['display_status'] ?? 'Unknown';
    final rating = specialist['display_rating']?.toDouble() ?? 0;
    final email = specialist['display_email'] ?? '';
    final hasRating = rating > 0;

    // 🔥 استخراج رابط الصورة
    String? profilePictureUrl;

    // جرب كل الاحتمالات للحصول على الصورة
    if (specialist['profile_picture'] != null) {
      profilePictureUrl = specialist['profile_picture'];
    } else if (specialist['personal_info']?['profile_picture'] != null) {
      profilePictureUrl = specialist['personal_info']['profile_picture'];
    } else if (specialist['specialist_info']?['personal_info']?['profile_picture'] != null) {
      profilePictureUrl = specialist['specialist_info']['personal_info']['profile_picture'];
    }

    // تأكد من أن الرابط يبدأ بـ http
    if (profilePictureUrl != null && !profilePictureUrl.startsWith('http')) {
      profilePictureUrl = 'http://10.0.2.2:5000/${profilePictureUrl.replaceAll(RegExp(r'^\/'), '')}';
    }

    Color statusColor = _getStatusColor(status);
    Color avatarColor = _getAvatarColor(index);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToReport(specialistId, name),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Section
                Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                                ? Image.network(
                              profilePictureUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: avatarColor,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: avatarColor,
                                  child: Center(
                                    child: Text(
                                      name.split(' ')
                                          .map((n) => n.isNotEmpty ? n[0].toUpperCase() : '')
                                          .take(2)
                                          .join(),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                                : Container(
                              color: avatarColor,
                              child: Center(
                                child: Text(
                                  name.split(' ')
                                      .map((n) => n.isNotEmpty ? n[0].toUpperCase() : '')
                                      .take(2)
                                      .join(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (hasRating)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.surface, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  rating.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 16),

                // Information Section (باقي الكود كما هو)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasRating)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                  SizedBox(width: 4),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.work_rounded, size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              specialty,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textGray,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.email_rounded, size: 14, color: AppColors.textLight),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Menu (باقي الكود كما هو)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  offset: Offset(0, 40),
                  onSelected: (value) async {
                    if (value == 'report') {
                      await _navigateToReport(specialistId, name);
                    } else if (value == 'schedule') {
                      await _navigateToSchedule(specialistId, name);
                    } else if (value == 'archive') {
                      await _archiveSpecialist(specialistId, name);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.analytics_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('View Report'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'schedule',
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('View Schedule'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive_rounded, color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          Text('Archive'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _navigateToReport(int specialistId, String name) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialistReportScreen(
          specialistId: specialistId,
          specialistName: name,
        ),
      ),
    );
  }

  Future<void> _navigateToSchedule(int specialistId, String name) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialistScheduleScreen.fromReport(
          specialistId: specialistId,
          specialistName: name,
        ),
      ),
    );
  }

  Future<void> _archiveSpecialist(int specialistId, String name) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Archive Specialist?', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to archive "$name"?\n\nArchived specialists can be restored later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ManagerSpecialistService.archiveSpecialist(
                  specialistId: specialistId,
                  forceArchive: false,
                );
                await _loadSpecialists();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Specialist archived successfully'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Archive'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return AppColors.success;
      case 'active': return AppColors.primary;
      case 'pending': return AppColors.warning;
      case 'archived': return AppColors.textGray;
      case 'rejected': return AppColors.error;
      default: return AppColors.textGray;
    }
  }

  Color _getAvatarColor(int index) {
    List<Color> colors = [
      AppColors.primary,
      AppColors.ment,
      AppColors.blue,
      AppColors.green,
      AppColors.darkGreen,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Specialists',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadSpecialists,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Search Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, specialty, or email...',
                      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 20, color: AppColors.textLight),
                        onPressed: () {
                          _searchController.clear();
                          _filterSpecialists();
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 0),
                    ),
                    style: TextStyle(fontSize: 14, color: AppColors.textDark),
                    onChanged: (value) => _filterSpecialists(),
                  ),
                ),

              ],
            ),
          ),

          // Filters Section
          _buildFilterSection(),

          // Results Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.accent2.withOpacity(0.1), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Specialists',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filteredSpecialists.length}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_filteredSpecialists.length != _specialists.length)
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _selectedFilter = 'All';
                        _selectedSpecialtyFilter = 'All';
                        _selectedRatingFilter = 'All';
                        _showFilters = false;
                        _filteredSpecialists = _specialists;
                      });
                    },
                    icon: Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 20),
                  Text(
                    'Loading Specialists...',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                ],
              ),
            )
                : _errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
                  SizedBox(height: 20),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGray, fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadSpecialists,
                    icon: Icon(Icons.refresh_rounded, size: 18),
                    label: Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
                : _filteredSpecialists.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 80, color: AppColors.accent4),
                  SizedBox(height: 20),
                  Text(
                    'No Specialists Found',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Try adjusting your search criteria or filters to find what you\'re looking for.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textLight, fontSize: 13),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _selectedFilter = 'All';
                        _selectedSpecialtyFilter = 'All';
                        _selectedRatingFilter = 'All';
                        _showFilters = false;
                        _filteredSpecialists = _specialists;
                      });
                    },
                    icon: Icon(Icons.clear_all_rounded, size: 18),
                    label: Text('Clear All Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _filteredSpecialists.length,
              itemBuilder: (context, index) {
                return _buildSpecialistCard(
                  _filteredSpecialists[index],
                  index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}