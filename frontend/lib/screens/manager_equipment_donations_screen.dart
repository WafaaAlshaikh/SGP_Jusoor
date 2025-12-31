import 'package:flutter/material.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/services/manager_dashboard_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ManagerEquipmentDonationsScreen extends StatefulWidget {
  const ManagerEquipmentDonationsScreen({Key? key}) : super(key: key);

  @override
  State<ManagerEquipmentDonationsScreen> createState() =>
      _ManagerEquipmentDonationsScreenState();
}

class _ManagerEquipmentDonationsScreenState
    extends State<ManagerEquipmentDonationsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<dynamic> _donations = [];
  List<dynamic> _filteredDonations = [];

  // متغيرات الفلاتر
  String _selectedStatus = 'all';
  String _selectedCondition = 'all';
  String? _selectedCategory;
  String _searchText = '';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _showFilters = false;

  // بيانات الفلاتر
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _statuses = [];
  List<Map<String, dynamic>> _conditions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await ManagerDashboardService.getEquipmentDonationStats();
      final donations = await ManagerDashboardService.getEquipmentDonationsList(
        page: _currentPage,
        status: _selectedStatus != 'all' ? _selectedStatus : null,
        condition: _selectedCondition != 'all' ? _selectedCondition : null,
        categoryId: _selectedCategory != 'all'
            ? int.tryParse(_selectedCategory ?? '')
            : null,
        search: _searchText.isNotEmpty ? _searchText : null,
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
      );

      setState(() {
        _stats = stats;
        _donations = donations['donations'];
        _filteredDonations = List.from(_donations);

        // تحميل بيانات الفلاتر
        _categories = List<Map<String, dynamic>>.from(
            donations['filters']['categories'] ?? []);
        _statuses = List<Map<String, dynamic>>.from(
            donations['filters']['statuses'] ?? []);
        _conditions = List<Map<String, dynamic>>.from(
            donations['filters']['conditions'] ?? []);

        _totalPages = donations['pagination']['pages'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    _currentPage = 1;
    _loadData();
  }

  void _resetFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedCondition = 'all';
      _selectedCategory = 'all';
      _searchText = '';
      _startDate = null;
      _endDate = null;
      _currentPage = 1;
    });
    _applyFilters();
  }

  Future<void> _showDatePicker(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _applyFilters();
    }
  }

  Future<void> _updateDonationStatus(int donationId, String status) async {
    try {
      await ManagerDashboardService.updateEquipmentDonationStatus(
          donationId, {'status': status});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الحالة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث الحالة: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatsCards() {
    final summary = _stats['summary'] ?? {};
    final byStatus = _stats['byStatus'] ?? {};
    final byCondition = _stats['byCondition'] ?? {};

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'إجمالي التبرعات',
                value: (summary['totalDonations'] ?? 0).toString(),
                icon: Icons.inventory_2_rounded,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'تم التسليم',
                value: (summary['deliveredDonations'] ?? 0).toString(),
                icon: Icons.check_circle_rounded,
                color: Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'آخر 30 يوم',
                value: (summary['recentDonations30Days'] ?? 0).toString(),
                icon: Icons.timeline_rounded,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'تحت المراجعة',
                value: (byStatus['pending'] ?? 0).toString(),
                icon: Icons.pending_actions_rounded,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'فلاتر البحث',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon:
                    Icon(_showFilters ? Icons.expand_less : Icons.expand_more),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
              ),
            ],
          ),

          // حقل البحث
          TextField(
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو رقم الهاتف...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
            onSubmitted: (_) => _applyFilters(),
          ),

          SizedBox(height: 12),

          if (_showFilters) ...[
            // فلاتر الحالة والشرط والفئة
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterDropdown(
                  value: _selectedStatus,
                  items: [
                    {'value': 'all', 'label': 'جميع الحالات'},
                    ..._statuses
                        .map((s) => {'value': s['value'], 'label': s['label']})
                        .toList()
                  ],
                  label: 'الحالة',
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
                _buildFilterDropdown(
                  value: _selectedCondition,
                  items: [
                    {'value': 'all', 'label': 'جميع الحالات'},
                    ..._conditions
                        .map((c) => {'value': c['value'], 'label': c['label']})
                        .toList()
                  ],
                  label: 'حالة الجهاز',
                  onChanged: (value) {
                    setState(() {
                      _selectedCondition = value;
                    });
                  },
                ),
                _buildFilterDropdown(
                  value: _selectedCategory ?? 'all',
                  items: [
                    {'value': 'all', 'label': 'جميع الفئات'},
                    ..._categories
                        .map((c) => {
                              'value': c['category_id'].toString(),
                              'label':
                                  c['name_ar'] ?? c['name_en'] ?? 'غير معروف'
                            })
                        .toList()
                  ],
                  label: 'الفئة',
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
              ],
            ),

            SizedBox(height: 12),

            // فلترة التاريخ
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showDatePicker(context, true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'من تاريخ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _startDate != null
                            ? DateFormat('yyyy/MM/dd').format(_startDate!)
                            : 'اختر تاريخ',
                        style: TextStyle(
                          color:
                              _startDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showDatePicker(context, false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'إلى تاريخ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _endDate != null
                            ? DateFormat('yyyy/MM/dd').format(_endDate!)
                            : 'اختر تاريخ',
                        style: TextStyle(
                          color: _endDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // أزرار التطبيق والإعادة
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text('تطبيق الفلاتر'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    child: Text('إعادة التعيين'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<Map<String, dynamic>> items,
    required String label,
    required Function(String) onChanged,
  }) {
    return Container(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: value,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item['value'],
                child: Text(item['label']),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationTile(Map<String, dynamic> donation) {
    final status = donation['status'] ?? 'pending';
    final condition = donation['condition'] ?? 'used_good';
    final equipmentName = donation['equipment_name'] ?? 'غير معروف';
    final contactPerson = donation['contact_person'] ?? 'غير معروف';
    final contactPhone = donation['contact_phone'] ?? '';
    final trackingCode = donation['tracking_code'] ?? '';
    final category = donation['category'] != null
        ? (donation['category']['name_ar'] ??
            donation['category']['name_en'] ??
            'غير معروف')
        : 'غير معروف';

    Color getStatusColor(String status) {
      switch (status) {
        case 'pending':
          return Colors.orange;
        case 'approved':
          return Colors.green;
        case 'rejected':
          return Colors.red;
        case 'scheduled':
          return Colors.blue;
        case 'delivered':
          return Colors.purple;
        case 'cancelled':
          return Colors.grey;
        default:
          return Colors.grey;
      }
    }

    String getStatusText(String status) {
      switch (status) {
        case 'pending':
          return 'قيد المراجعة';
        case 'approved':
          return 'مقبول';
        case 'rejected':
          return 'مرفوض';
        case 'scheduled':
          return 'مجدول';
        case 'delivered':
          return 'تم التسليم';
        case 'cancelled':
          return 'ملغي';
        default:
          return status;
      }
    }

    String getConditionText(String condition) {
      switch (condition) {
        case 'new':
          return 'جديد';
        case 'used_good':
          return 'مستعمل - جيد';
        case 'used_fair':
          return 'مستعمل - متوسط';
        case 'needs_repair':
          return 'يحتاج صيانة';
        default:
          return condition;
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: getStatusColor(status).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.medical_services,
            color: getStatusColor(status),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              equipmentName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'المتبرع: $contactPerson',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    getStatusText(status),
                    style: TextStyle(
                      fontSize: 11,
                      color: getStatusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    getConditionText(condition),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // معلومات الجهاز
                _buildInfoRow('الفئة', category),
                if (donation['description'] != null)
                  _buildInfoRow('الوصف', donation['description']),
                if (donation['estimated_value'] != null)
                  _buildInfoRow(
                      'القيمة التقديرية', '${donation['estimated_value']} JOD'),

                // معلومات الاتصال
                Divider(),
                _buildInfoRow('رقم الهاتف', contactPhone),
                if (donation['contact_email'] != null)
                  _buildInfoRow('البريد الإلكتروني', donation['contact_email']),
                _buildInfoRow('كود التتبع', trackingCode),
                if (donation['preferred_date'] != null)
                  _buildInfoRow(
                      'التاريخ المفضل',
                      DateFormat('yyyy/MM/dd')
                          .format(DateTime.parse(donation['preferred_date']))),

                // أزرار التحكم بالحالة
                if (status == 'pending')
                  Column(
                    children: [
                      Divider(),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _updateDonationStatus(
                                  donation['id'], 'approved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: Text('قبول'),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _updateDonationStatus(
                                  donation['id'], 'rejected'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: Text('رفض'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                if (status == 'approved')
                  Column(
                    children: [
                      Divider(),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _updateDonationStatus(donation['id'], 'scheduled'),
                        child: Text('تحديد موعد الاستلام'),
                      ),
                    ],
                  ),

                if (status == 'scheduled')
                  Column(
                    children: [
                      Divider(),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _updateDonationStatus(donation['id'], 'delivered'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                        ),
                        child: Text('تم التسليم'),
                      ),
                    ],
                  ),

                // أزرار الاتصال
                Divider(),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: contactPhone.isNotEmpty
                            ? () => launchUrl(Uri.parse('tel:$contactPhone'))
                            : null,
                        icon: Icon(Icons.phone, size: 16),
                        label: Text('اتصال'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: donation['contact_email'] != null
                            ? () => launchUrl(Uri.parse(
                                'mailto:${donation['contact_email']}'))
                            : null,
                        icon: Icon(Icons.email, size: 16),
                        label: Text('بريد'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة التبرعات العينية'),
        backgroundColor: AppColors.primaryDark,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // بطاقات الإحصائيات
                  _buildStatsCards(),
                  SizedBox(height: 20),

                  // فلاتر البحث
                  _buildFiltersSection(),
                  SizedBox(height: 20),

                  // قائمة التبرعات
                  if (_filteredDonations.isEmpty)
                    Container(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.medical_services_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد تبرعات عينية',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'سيظهر هنا جميع التبرعات العينية للمؤسسة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        ..._filteredDonations
                            .map((donation) => _buildDonationTile(
                                donation as Map<String, dynamic>))
                            .toList(),

                        // الترقيم الصفحي
                        if (_totalPages > 1)
                          Container(
                            margin: EdgeInsets.only(top: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.chevron_left),
                                  onPressed: _currentPage > 1
                                      ? () {
                                          setState(() {
                                            _currentPage--;
                                          });
                                          _loadData();
                                        }
                                      : null,
                                ),
                                Text('صفحة $_currentPage من $_totalPages'),
                                IconButton(
                                  icon: Icon(Icons.chevron_right),
                                  onPressed: _currentPage < _totalPages
                                      ? () {
                                          setState(() {
                                            _currentPage++;
                                          });
                                          _loadData();
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
