// lib/screens/manager/manager_donations_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_dashboard_service.dart';
import '../../services/equipment_management_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'manager_impact_posts_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class ManagerDonationsScreen extends StatefulWidget {
  const ManagerDonationsScreen({Key? key}) : super(key: key);

  @override
  State<ManagerDonationsScreen> createState() => _ManagerDonationsScreenState();
}

class _ManagerDonationsScreenState extends State<ManagerDonationsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _stats = {};
  List<dynamic> _donations = [];

  List<dynamic> _allocations = [];
  List<dynamic> _campaigns = [];
  List<dynamic> _filteredDonations = [];
  List<dynamic> _filteredAllocations = [];
  List<dynamic> _topDonors = [];
  List<dynamic> _latestDonations = [];
  List<dynamic> _donationDistribution = [];

  final ScrollController _donationsScrollController = ScrollController();
  int _donationsViewIndex = 0;

  bool _isLoadingImpactV2 = false;
  Map<String, dynamic>? _impactV2;
  String? _impactV2Error;

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Color _equipmentStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'delivered':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return AppColors.textGray;
    }
  }

  void _openEquipmentDonationManageSheet(Map<String, dynamic> donation) {
    // Equipment in-kind donations are auto-approved and added to inventory immediately.
    // Manager approval workflow has been removed.
    return;
  }

  Future<void> _openEquipmentCampaignManageSheet(Map<String, dynamic> campaign) async {
    final campaignIdRaw = campaign['campaign_id'] ?? campaign['id'];
    final campaignId = campaignIdRaw is int ? campaignIdRaw : int.tryParse(campaignIdRaw.toString());
    if (campaignId == null) return;

    String status = (campaign['status'] ?? 'open').toString();
    final quantityController = TextEditingController(text: (campaign['quantity_fulfilled'] ?? '').toString());

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Manage Equipment Campaign', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('open')),
                    DropdownMenuItem(value: 'partially_fulfilled', child: Text('partially_fulfilled')),
                    DropdownMenuItem(value: 'fulfilled', child: Text('fulfilled')),
                    DropdownMenuItem(value: 'closed', child: Text('closed')),
                  ],
                  onChanged: (v) {
                    if (v != null) status = v;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Quantity fulfilled',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok == true) {
      final quantity = int.tryParse(quantityController.text.trim());
      final payload = <String, dynamic>{
        'status': status,
        'quantity_fulfilled': quantity,
      };
      payload.removeWhere((k, v) => v == null);

      try {
        await EquipmentManagementService.updateManagerEquipmentCampaign(
          campaignId: campaignId,
          status: payload['status'] as String?,
          quantityFulfilled: payload['quantity_fulfilled'] as int?,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment campaign updated')),
        );
        await _loadEquipmentCampaigns();
        await _loadEquipmentCampaignStats();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  DateTimeRange? _selectedRange;
  String _quickFilter = 'all';
  String _searchText = '';
  bool _onlyInvoiceLinked = false;
  int? _expandedDonorId;

  late TabController _tabController;
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> _processedDonors = [];

  bool _isLoadingEquipment = false;
  Map<String, dynamic> _equipmentStats = {};
  List<dynamic> _equipmentDonations = [];
  String? _equipmentError;

  bool _isLoadingEquipmentCampaigns = false;
  String? _equipmentCampaignsError;
  List<Map<String, dynamic>> _equipmentCampaigns = [];
  Map<String, dynamic> _equipmentCampaignStats = {};
  List<Map<String, dynamic>> _equipmentCampaignCategories = [];
  int _equipmentCampaignPage = 1;
  int _equipmentCampaignPages = 1;

  Map<String, dynamic> _equipmentCampaignFilters = {
    'status': 'open',
    'categoryId': null,
    'childId': null,
    'needId': null,
    'search': '',
    'minFulfillment': null,
    'maxFulfillment': null,
    'minPriority': null,
    'maxPriority': null,
    'startDate': null,
    'endDate': null,
  };

  // ========== متغيرات الفلاتر المتقدمة الجديدة ==========
  Map<String, dynamic> _filterState = {
    'dateRange': 'all',
    'dateFrom': null,
    'dateTo': null,
    'amountMin': null,
    'amountMax': null,
    'donorTypes': [], // individual, corporate, anonymous
    'campaignIds': [],
    'invoiceStatus': [], // paid, pending, overdue
    'donationFrequency': [], // one_time, monthly, quarterly, yearly
    'minDonationsCount': 1,
    'sortBy': 'date_desc',
    'onlyLargeDonations': false,
    'onlyWithContact': false,
    'onlyRecurring': false,
  };

  List<Map<String, dynamic>> _availableCampaigns = [];
  List<Map<String, dynamic>> _donorsList = [];
  bool _showAdvancedFilters = false;
  final GlobalKey<FormState> _filterFormKey = GlobalKey<FormState>();
  // ========== نهاية متغيرات الفلاتر المتقدمة ==========

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _donationsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final result = await ManagerDashboardService.getDonationDetails();
    final campaigns = await ManagerDashboardService.getDonationCampaigns();
    final stats = await ManagerDashboardService.getDonationStatistics();

    // Debug: طباعة تفاصيل البيانات
    print('=== Debug Donation Data ===');
    print('Total donations: ${result['donations']?.length ?? 0}');
    print('Total campaigns: ${campaigns.length}');
    print('Campaigns list:');
    for (var i = 0; i < campaigns.length; i++) {
      final camp = campaigns[i] as Map<String, dynamic>;
      print('  ${i + 1}. ID: ${camp['campaign_id']}, Name: "${camp['name']}"');
    }
    
    print('\nSample donations:');
    final donations = List<dynamic>.from(result['donations'] as List? ?? []);
    for (var i = 0; i < min(3, donations.length); i++) {
      final donation = donations[i] as Map<String, dynamic>;
      print('  ${i + 1}. Amount: ${donation['amount']}, CampaignID: ${donation['campaign_id']}');
    }
    print('===========================\n');

    await _loadImpactV2();
    await _loadEquipmentDonations();
    await _loadEquipmentCampaigns();
    await _loadEquipmentCampaignStats();

    setState(() {
      _data = result;
      _stats = stats;
      _donations = List<dynamic>.from(result['donations'] as List? ?? []);

      _allocations = List<dynamic>.from(result['allocations'] as List? ?? []);
      _campaigns = campaigns;

      final topDonor = stats['topDonor'];
      _topDonors = topDonor != null ? [topDonor] : [];
      _latestDonations = List<dynamic>.from(stats['latestDonations'] ?? []);
      _donationDistribution = List<dynamic>.from(stats['distribution'] ?? []);
      _applyFilters();
      _processLatestDonations();
      _isLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeCampaignData();
    });

    _loadFilterData();
  } catch (e) {
    print('Error loading data: $e');
    setState(() {
      _isLoading = false;
    });
  }
}
  Future<void> _loadImpactV2() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoadingImpactV2 = true;
        _impactV2Error = null;
      });

      final data = await ManagerDashboardService.getInstitutionDonationImpactV2();

      if (!mounted) return;
      setState(() {
        _impactV2 = data;
        _isLoadingImpactV2 = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _impactV2 = null;
        _impactV2Error = 'Failed to load impact';
        _isLoadingImpactV2 = false;
      });
    }
  }

  Future<void> _loadEquipmentDonations() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoadingEquipment = true;
        _equipmentError = null;
      });

      final stats = await ManagerDashboardService.getEquipmentDonationStats();
      final list = await ManagerDashboardService.getEquipmentDonationsList(page: 1, limit: 20);

      if (!mounted) return;
      setState(() {
        _equipmentStats = Map<String, dynamic>.from(stats);
        _equipmentDonations = List<dynamic>.from(list['donations'] ?? []);
        _isLoadingEquipment = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _equipmentError = e.toString();
        _isLoadingEquipment = false;
      });
    }
  }

  Future<void> _loadEquipmentCampaigns() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoadingEquipmentCampaigns = true;
        _equipmentCampaignsError = null;
      });

      final result = await EquipmentManagementService.getManagerEquipmentCampaigns(
        status: (_equipmentCampaignFilters['status'] as String?)?.isEmpty == true
            ? null
            : _equipmentCampaignFilters['status'] as String?,
        categoryId: _equipmentCampaignFilters['categoryId'] as int?,
        childId: _equipmentCampaignFilters['childId'] as int?,
        needId: _equipmentCampaignFilters['needId'] as int?,
        search: (_equipmentCampaignFilters['search'] as String?)?.trim(),
        minFulfillment: _equipmentCampaignFilters['minFulfillment'] as double?,
        maxFulfillment: _equipmentCampaignFilters['maxFulfillment'] as double?,
        minPriority: _equipmentCampaignFilters['minPriority'] as int?,
        maxPriority: _equipmentCampaignFilters['maxPriority'] as int?,
        startDate: _equipmentCampaignFilters['startDate'] as DateTime?,
        endDate: _equipmentCampaignFilters['endDate'] as DateTime?,
        page: _equipmentCampaignPage,
        limit: 20,
      );

      final rawCampaigns = result['campaigns'];
      final pagination = result['pagination'] as Map<String, dynamic>?;
      final filters = result['filters'] as Map<String, dynamic>?;

      final campaigns = (rawCampaigns is List)
          ? rawCampaigns.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      final categoriesRaw = filters?['categories'];
      final categories = (categoriesRaw is List)
          ? categoriesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _equipmentCampaigns = campaigns;
        _equipmentCampaignCategories = categories;
        _equipmentCampaignPages = (pagination?['pages'] ?? 1) is int ? (pagination?['pages'] ?? 1) as int : 1;
        _isLoadingEquipmentCampaigns = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _equipmentCampaignsError = e.toString();
        _isLoadingEquipmentCampaigns = false;
      });
    }
  }

  Future<void> _loadEquipmentCampaignStats() async {
    try {
      final data = await EquipmentManagementService.getManagerEquipmentCampaignStats(
        status: (_equipmentCampaignFilters['status'] as String?)?.isEmpty == true
            ? null
            : _equipmentCampaignFilters['status'] as String?,
        categoryId: _equipmentCampaignFilters['categoryId'] as int?,
        childId: _equipmentCampaignFilters['childId'] as int?,
        needId: _equipmentCampaignFilters['needId'] as int?,
        startDate: _equipmentCampaignFilters['startDate'] as DateTime?,
        endDate: _equipmentCampaignFilters['endDate'] as DateTime?,
      );
      if (!mounted) return;
      setState(() {
        _equipmentCampaignStats = Map<String, dynamic>.from(data);
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _openEquipmentCampaignFilters() async {
    final current = Map<String, dynamic>.from(_equipmentCampaignFilters);

    final searchController = TextEditingController(text: (current['search'] ?? '').toString());
    final childIdController = TextEditingController(text: current['childId']?.toString() ?? '');
    final needIdController = TextEditingController(text: current['needId']?.toString() ?? '');
    final minFulfillmentController = TextEditingController(text: current['minFulfillment']?.toString() ?? '');
    final maxFulfillmentController = TextEditingController(text: current['maxFulfillment']?.toString() ?? '');
    final minPriorityController = TextEditingController(text: current['minPriority']?.toString() ?? '');
    final maxPriorityController = TextEditingController(text: current['maxPriority']?.toString() ?? '');

    String status = (current['status'] ?? 'open').toString();
    int? categoryId = current['categoryId'] as int?;
    DateTime? startDate = current['startDate'] as DateTime?;
    DateTime? endDate = current['endDate'] as DateTime?;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Equipment Campaign Filters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('open')),
                    DropdownMenuItem(value: 'partially_fulfilled', child: Text('partially_fulfilled')),
                    DropdownMenuItem(value: 'fulfilled', child: Text('fulfilled')),
                    DropdownMenuItem(value: 'closed', child: Text('closed')),
                  ],
                  onChanged: (v) {
                    if (v != null) status = v;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  value: categoryId,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Category'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All')),
                    ..._equipmentCampaignCategories.map((c) {
                      final id = c['category_id'];
                      final name = (c['name_ar'] ?? c['name_en'] ?? '').toString();
                      if (id is! int) return const DropdownMenuItem<int?>(value: null, child: Text(''));
                      return DropdownMenuItem<int?>(value: id, child: Text(name.isEmpty ? 'Category $id' : name));
                    }).toList(),
                  ],
                  onChanged: (v) => categoryId = v,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Search (name/type)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: childIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Child ID'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: needIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Need ID'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minFulfillmentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Min fulfillment %'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: maxFulfillmentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Max fulfillment %'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minPriorityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Min priority'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: maxPriorityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Max priority'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                            initialDate: startDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            startDate = picked;
                          }
                        },
                        child: Text(startDate == null ? 'Start date' : DateFormat('yyyy-MM-dd').format(startDate!)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                            initialDate: endDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            endDate = picked;
                          }
                        },
                        child: Text(endDate == null ? 'End date' : DateFormat('yyyy-MM-dd').format(endDate!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (applied == true) {
      final parsedChildId = int.tryParse(childIdController.text.trim());
      final parsedNeedId = int.tryParse(needIdController.text.trim());
      final parsedMinF = double.tryParse(minFulfillmentController.text.trim());
      final parsedMaxF = double.tryParse(maxFulfillmentController.text.trim());
      final parsedMinP = int.tryParse(minPriorityController.text.trim());
      final parsedMaxP = int.tryParse(maxPriorityController.text.trim());

      setState(() {
        _equipmentCampaignFilters = {
          'status': status,
          'categoryId': categoryId,
          'childId': parsedChildId,
          'needId': parsedNeedId,
          'search': searchController.text.trim(),
          'minFulfillment': parsedMinF,
          'maxFulfillment': parsedMaxF,
          'minPriority': parsedMinP,
          'maxPriority': parsedMaxP,
          'startDate': startDate,
          'endDate': endDate,
        };
        _equipmentCampaignPage = 1;
      });

      await _loadEquipmentCampaigns();
      await _loadEquipmentCampaignStats();
    }
  }

  // ========== دوال الفلاتر المتقدمة الجديدة ==========
  void _loadFilterData() async {
  try {
    // تحميل الحملات من البيانات الموجودة
    final List<Map<String, dynamic>> campaignList = [];
    
    for (final campaign in _campaigns) {
      final camp = _asStringMap(campaign);
      if (camp != null) {
        campaignList.add(camp);
      }
    }
    
    setState(() {
      _availableCampaigns = campaignList;
    });

    // تجميع المتبرعين من البيانات المحملة
    final Set<Map<String, dynamic>> uniqueDonors = {};

    // جمع من التبرعات
    for (final donation in _donations) {
      final donor = _asStringMap(donation['donor']);
      if (donor != null && donor['id'] != null) {
        uniqueDonors.add(donor);
      }
    }

    // جمع من أحدث التبرعات
    for (final donation in _latestDonations) {
      final donor = _asStringMap(donation['donor']);
      if (donor != null && donor['id'] != null) {
        uniqueDonors.add(donor);
      }
    }

    // جمع من أفضل المتبرعين
    for (final donorData in _topDonors) {
      final donorInfo = _asStringMap(donorData['donor_info']);
      if (donorInfo != null && donorInfo['id'] != null) {
        uniqueDonors.add(donorInfo);
      }
    }

    setState(() {
      _donorsList = uniqueDonors.toList();
    });
    
    // طباعة معلومات التشخيص
    print('=== Campaign Data Analysis ===');
    print('Total campaigns in system: ${_campaigns.length}');
    print('Total donations: ${_donations.length}');
    print('Latest donations: ${_latestDonations.length}');
    
    // تحليل ارتباط التبرعات بالحملات
    int linkedToCampaign = 0;
    for (final donation in _donations) {
      final donationMap = _asStringMap(donation);
      if (donationMap != null) {
        final campaignId = donationMap['campaign_id'] ?? donationMap['campaign']?['campaign_id'];
        if (campaignId != null) linkedToCampaign++;
      }
    }
    
    print('Donations linked to campaigns: $linkedToCampaign/${_donations.length}');
    print('=============================\n');
    
  } catch (e) {
    print('Error loading filter data: $e');
  }
}
void _analyzeCampaignData() {
  print('🔍 Campaign Data Analysis:');
  print('==========================');
  
  // 1. التحقق من الحملات
  print('Campaigns (${_campaigns.length}):');
  for (var i = 0; i < min(5, _campaigns.length); i++) {
    final campaign = _asStringMap(_campaigns[i]) ?? {};
    print('  ${i + 1}. ${campaign['name'] ?? 'Unnamed'} (ID: ${campaign['campaign_id']})');
  }
  
  // 2. التحقق من التبرعات
  print('\nDonations (${_donations.length}):');
  int withCampaign = 0;
  for (var i = 0; i < min(5, _donations.length); i++) {
    final donation = _asStringMap(_donations[i]) ?? {};
    final hasCampaign = donation['campaign_id'] != null || donation['campaign'] != null;
    if (hasCampaign) withCampaign++;
    print('  ${i + 1}. Amount: ${donation['amount']}, Has Campaign: $hasCampaign');
  }
  
  // 3. التحقق من أحدث التبرعات
  print('\nLatest Donations (${_latestDonations.length}):');
  for (var i = 0; i < min(3, _latestDonations.length); i++) {
    final donation = _asStringMap(_latestDonations[i]) ?? {};
    print('  ${i + 1}. Amount: ${donation['amount']}, Campaign: ${donation['campaign']}');
  }
  
  print('\n📊 Summary:');
  print('  - Campaigns available: ${_campaigns.length}');
  print('  - Total donations: ${_donations.length}');
  print('  - Donations with campaign: $withCampaign');
  print('  - Donations without campaign: ${_donations.length - withCampaign}');
  print('==========================\n');
}

  void _applyAdvancedFilters() {
    List<dynamic> filteredDonations = List<dynamic>.from(_donations);
    List<dynamic> filteredAllocations = List<dynamic>.from(_allocations);

    // فلترة حسب التاريخ
    filteredDonations = _filterByDate(filteredDonations);
    filteredAllocations = _filterByDate(filteredAllocations);

    // فلترة حسب المبلغ
    filteredDonations = _filterByAmount(filteredDonations);
    filteredAllocations = _filterByAmount(filteredAllocations);

    // فلترة حسب نوع المتبرع
    filteredDonations = _filterByDonorType(filteredDonations);

    // فلترة حسب الحملات
    filteredDonations = _filterByCampaign(filteredDonations);

    // فلترة حسب حالة الفواتير
    filteredAllocations = _filterByInvoiceStatus(filteredAllocations);

    // فلترة حسب التكرار
    filteredDonations = _filterByFrequency(filteredDonations);

    // فلترات إضافية
    if (_filterState['onlyLargeDonations'] == true) {
      filteredDonations = filteredDonations.where((d) {
        final amount = double.tryParse(d['amount'].toString()) ?? 0;
        return amount >= 1000; // تبرعات كبيرة
      }).toList();
    }

    if (_filterState['onlyWithContact'] == true) {
      filteredDonations = filteredDonations.where((d) {
        final donor = _asStringMap(d['donor']) ?? {};
        return (donor['email'] != null || donor['phone'] != null);
      }).toList();
    }

    if (_filterState['onlyRecurring'] == true) {
      final recurringDonors = _identifyRecurringDonors(filteredDonations);
      filteredDonations = filteredDonations.where((d) {
        final donorIdRaw = _asStringMap(d['donor'])?['id'] ?? 0;
        final donorId = donorIdRaw is int ? donorIdRaw : int.tryParse(donorIdRaw.toString()) ?? 0;
        return recurringDonors.contains(donorId);
      }).toList();
    }

    // تطبيق الترتيب
    filteredDonations = _applySorting(filteredDonations);

    setState(() {
      _filteredDonations = filteredDonations;
      _filteredAllocations = filteredAllocations;
    });
  }

  List<dynamic> _filterByDate(List<dynamic> items) {
    if (_filterState['dateRange'] == 'all') return items;

    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    switch (_filterState['dateRange']) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'yesterday':
        startDate = DateTime(now.year, now.month, now.day - 1);
        endDate = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        break;
      case 'this_week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case 'last_week':
        startDate = now.subtract(Duration(days: now.weekday + 6));
        endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case 'this_month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'last_month':
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'this_quarter':
        final quarter = ((now.month - 1) / 3).floor();
        startDate = DateTime(now.year, quarter * 3 + 1, 1);
        endDate = DateTime(now.year, quarter * 3 + 4, 0, 23, 59, 59);
        break;
      case 'last_quarter':
        final quarter = ((now.month - 1) / 3).floor();
        final lastQuarter = quarter == 0 ? 3 : quarter - 1;
        final year = quarter == 0 ? now.year - 1 : now.year;
        startDate = DateTime(year, lastQuarter * 3 + 1, 1);
        endDate = DateTime(year, lastQuarter * 3 + 4, 0, 23, 59, 59);
        break;
      case 'this_year':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'last_year':
        startDate = DateTime(now.year - 1, 1, 1);
        endDate = DateTime(now.year - 1, 12, 31, 23, 59, 59);
        break;
      case 'custom':
        startDate = _filterState['dateFrom'];
        endDate = _filterState['dateTo'];
        break;
    }

    if (startDate == null || endDate == null) return items;

    return items.where((item) {
      DateTime? date;
      final dateStr = item['date']?.toString();

      if (dateStr != null) {
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {
          return false;
        }
      }

      return date != null &&
             !date.isBefore(startDate!) &&
             !date.isAfter(endDate!);
    }).toList();
  }

  List<dynamic> _filterByAmount(List<dynamic> items) {
    final minAmount = _filterState['amountMin'];
    final maxAmount = _filterState['amountMax'];

    if (minAmount == null && maxAmount == null) return items;

    return items.where((item) {
      final amount = double.tryParse(item['amount'].toString()) ?? 0;

      bool passesMin = minAmount == null || amount >= minAmount;
      bool passesMax = maxAmount == null || amount <= maxAmount;

      return passesMin && passesMax;
    }).toList();
  }

  List<dynamic> _filterByDonorType(List<dynamic> items) {
    final donorTypes = _filterState['donorTypes'] as List<String>;

    if (donorTypes.isEmpty) return items;

    return items.where((item) {
      final donor = _asStringMap(item['donor']) ?? {};
      final isCorporate = donor['is_corporate'] == true;
      final hasName = donor['name'] != null && donor['name'].toString().isNotEmpty;
      final isAnonymous = !hasName || donor['name'].toString().toLowerCase() == 'anonymous';

      if (donorTypes.contains('corporate') && isCorporate) return true;
      if (donorTypes.contains('individual') && !isCorporate && hasName && !isAnonymous) return true;
      if (donorTypes.contains('anonymous') && isAnonymous) return true;

      return false;
    }).toList();
  }

  List<dynamic> _filterByCampaign(List<dynamic> items) {
    final campaignIds = _filterState['campaignIds'] as List<int>;

    if (campaignIds.isEmpty) return items;

    return items.where((item) {
      final campaignId = item['campaign_id'] ?? item['campaign']?['id'];
      return campaignId != null && campaignIds.contains(campaignId);
    }).toList();
  }

  List<dynamic> _filterByInvoiceStatus(List<dynamic> items) {
    final invoiceStatuses = _filterState['invoiceStatus'] as List<String>;

    if (invoiceStatuses.isEmpty) return items;

    return items.where((item) {
      final invoiceId = item['invoice_id'];
      if (invoiceId == null) return false;

      final invoice = (_data['invoices'] as Map<String, dynamic>?)?[invoiceId.toString()];
      final status = invoice?['status']?.toString().toLowerCase();

      return status != null && invoiceStatuses.contains(status);
    }).toList();
  }

  List<dynamic> _filterByFrequency(List<dynamic> items) {
    final frequencies = _filterState['donationFrequency'] as List<String>;

    if (frequencies.isEmpty) return items;

    // تجميع التبرعات حسب المتبرعين
    final Map<int, List<dynamic>> donorDonations = {};

    for (final donation in items) {
      final donorIdRaw = _asStringMap(donation['donor'])?['id'] ?? 0;
      final donorId = donorIdRaw is int ? donorIdRaw : int.tryParse(donorIdRaw.toString()) ?? 0;
      donorDonations.putIfAbsent(donorId, () => []).add(donation);
    }

    // تحديد نمط التبرع لكل متبرع
    final Set<int> matchingDonorIds = {};

    for (final entry in donorDonations.entries) {
      final donations = entry.value;
      if (donations.length < 2 && frequencies.contains('one_time')) {
        matchingDonorIds.add(entry.key);
        continue;
      }

      final pattern = _determineDonationPattern(donations);

      if (frequencies.contains(pattern)) {
        matchingDonorIds.add(entry.key);
      }
    }

    return items.where((item) {
      final donorIdRaw = _asStringMap(item['donor'])?['id'] ?? 0;
      final donorId = donorIdRaw is int ? donorIdRaw : int.tryParse(donorIdRaw.toString()) ?? 0;
      return matchingDonorIds.contains(donorId);
    }).toList();
  }

  String _determineDonationPattern(List<dynamic> donations) {
    if (donations.length < 2) return 'one_time';

    final dates = <DateTime>[];
    for (final donation in donations) {
      final dateStr = donation['date']?.toString();
      if (dateStr != null) {
        try {
          dates.add(DateTime.parse(dateStr));
        } catch (_) {}
      }
    }

    if (dates.length < 2) return 'one_time';

    dates.sort();
    final totalDays = dates.last.difference(dates.first).inDays;
    final avgDays = totalDays / (dates.length - 1);

    if (avgDays <= 35) return 'monthly';
    if (avgDays <= 95) return 'quarterly';
    if (avgDays <= 370) return 'yearly';
    return 'one_time';
  }

  Set<int> _identifyRecurringDonors(List<dynamic> donations) {
    final Map<int, List<dynamic>> donorDonations = {};
    final Set<int> recurringDonors = {};

    for (final donation in donations) {
      final donorIdRaw = _asStringMap(donation['donor'])?['id'] ?? 0;
      final donorId = donorIdRaw is int ? donorIdRaw : int.tryParse(donorIdRaw.toString()) ?? 0;
      donorDonations.putIfAbsent(donorId, () => []).add(donation);
    }

    for (final entry in donorDonations.entries) {
      if (entry.value.length >= 2) {
        recurringDonors.add(entry.key);
      }
    }

    return recurringDonors;
  }

  List<dynamic> _applySorting(List<dynamic> items) {
    final sortBy = _filterState['sortBy'] as String;

    items.sort((a, b) {
      switch (sortBy) {
        case 'date_desc':
          final dateA = DateTime.tryParse(a['date']?.toString() ?? '');
          final dateB = DateTime.tryParse(b['date']?.toString() ?? '');
          return dateB?.compareTo(dateA ?? DateTime(1900)) ?? 0;

        case 'date_asc':
          final dateA = DateTime.tryParse(a['date']?.toString() ?? '');
          final dateB = DateTime.tryParse(b['date']?.toString() ?? '');
          return dateA?.compareTo(dateB ?? DateTime(1900)) ?? 0;

        case 'amount_desc':
          final amountA = double.tryParse(a['amount'].toString()) ?? 0;
          final amountB = double.tryParse(b['amount'].toString()) ?? 0;
          return amountB.compareTo(amountA);

        case 'amount_asc':
          final amountA = double.tryParse(a['amount'].toString()) ?? 0;
          final amountB = double.tryParse(b['amount'].toString()) ?? 0;
          return amountA.compareTo(amountB);

        case 'donor_name':
          final nameA = (_asStringMap(a['donor'])?['name'] ?? '').toString().toLowerCase();
          final nameB = (_asStringMap(b['donor'])?['name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);

        default:
          return 0;
      }
    });

    return items;
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final initialStart = _selectedRange?.start ?? DateTime(now.year, now.month, 1);
    final initialEnd = _selectedRange?.end ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
        _quickFilter = 'custom';
        _filterState['dateRange'] = 'custom';
        _filterState['dateFrom'] = picked.start;
        _filterState['dateTo'] = picked.end;
      });
      _applyAdvancedFilters();
    }
  }

  void _resetFilters() {
    setState(() {
      _filterState = {
        'dateRange': 'all',
        'dateFrom': null,
        'dateTo': null,
        'amountMin': null,
        'amountMax': null,
        'donorTypes': [],
        'campaignIds': [],
        'invoiceStatus': [],
        'donationFrequency': [],
        'minDonationsCount': 1,
        'sortBy': 'date_desc',
        'onlyLargeDonations': false,
        'onlyWithContact': false,
        'onlyRecurring': false,
      };
      _selectedRange = null;
      _quickFilter = 'all';
      _searchText = '';
      _onlyInvoiceLinked = false;
      _applyAdvancedFilters();
    });
  }
  // ========== نهاية دوال الفلاتر المتقدمة ==========

  void _processLatestDonations() {
    final Map<int, Map<String, dynamic>> donorsMap = {};

    for (final donation in _latestDonations) {
      final donor = _asStringMap(donation['donor']) ?? {};
      final donorId = donor['id'] ?? 0;

      if (donorId == 0) continue; // Skip anonymous

      if (!donorsMap.containsKey(donorId)) {
        donorsMap[donorId] = {
          'donor': donor,
          'donations': [],
          'totalAmount': 0.0,
          'donationCount': 0,
          'firstDonationDate': null,
          'lastDonationDate': null,
        };
      }

      final amount = double.tryParse(donation['amount'].toString()) ?? 0;
      final dateStr = donation['date']?.toString();
      DateTime? date;
      if (dateStr != null) {
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {}
      }

      final donorData = donorsMap[donorId]!;
      donorData['donations'].add(donation);
      donorData['totalAmount'] += amount;
      donorData['donationCount'] += 1;

      if (date != null) {
        if (donorData['firstDonationDate'] == null ||
            date.isBefore(donorData['firstDonationDate'])) {
          donorData['firstDonationDate'] = date;
        }
        if (donorData['lastDonationDate'] == null ||
            date.isAfter(donorData['lastDonationDate'])) {
          donorData['lastDonationDate'] = date;
        }
      }
    }

    // Convert to list and sort by total amount (descending)
    _processedDonors = donorsMap.values.toList()
      ..sort((a, b) => (b['totalAmount'] as double)
          .compareTo(a['totalAmount'] as double));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: const Text('Donations & Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.analytics_rounded,  size: 20),
              text: 'Donations',
            ),
            Tab(
              icon: Icon(Icons.campaign_rounded, size: 20),
              text: 'Campaigns',
            ),
            Tab(
              icon: Icon(Icons.volunteer_activism_rounded, size: 20),
              text: 'Equipment',
            ),
            Tab(
              icon: Icon(Icons.inventory_2_rounded, size: 20),
              text: 'Eq Campaigns',
            ),
          ],
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDonationsAnalyticsTab(),
                  _buildCampaignsTab(),
                  _buildEquipmentDonationsTab(),
                  _buildEquipmentCampaignsTab(),
                ],
              ),
            ),
      floatingActionButton: _currentTabIndex == 1
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => _openCampaignDialog(),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildDonationsAnalyticsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Donations & Analytics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    _buildViewToggleButton(
                      index: 0,
                      icon: Icons.analytics_rounded,
                      label: 'Analytics',
                    ),
                    _buildViewToggleButton(
                      index: 1,
                      icon: Icons.list_rounded,
                      label: 'List',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_donationsViewIndex == 1) _buildFiltersBar(),
        Expanded(
          child: _donationsViewIndex == 0
              ? _buildAnalyticsContent()
              : _buildDonationsListContent(),
        ),
      ],
    );
  }

  Widget _buildEquipmentDonationsTab() {
    if (_isLoadingEquipment) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_equipmentError != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load: $_equipmentError')));
    }

    final summary = (_equipmentStats['summary'] is Map)
        ? Map<String, dynamic>.from(_equipmentStats['summary'] as Map)
        : <String, dynamic>{};
    final total = _toInt(summary['totalDonations']);
    final delivered = _toInt(summary['deliveredDonations']);
    final recent30 = _toInt(summary['recentDonations30Days']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total',
                value: total.toString(),
                icon: Icons.inventory_2_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Delivered',
                value: delivered.toString(),
                icon: Icons.check_circle_rounded,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Last 30d',
                value: recent30.toString(),
                icon: Icons.schedule_rounded,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Latest Equipment Donations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            IconButton(onPressed: _loadEquipmentDonations, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 8),
        if (_equipmentDonations.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Text('No equipment donations')))
        else
          ..._equipmentDonations.map((d) {
            final m = _asStringMap(d) ?? {};
            final title = (m['equipment_name'] ?? '').toString();
            final status = (m['status'] ?? '').toString();
            final donor = (m['contact_person'] ?? (m['donor'] is Map ? (m['donor']['full_name'] ?? '') : '')).toString();
            final created = (m['created_at'] ?? '').toString();
            final statusColor = _equipmentStatusColor(status);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent2.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'Equipment' : title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Donor: ${donor.isEmpty ? 'Anonymous' : donor}', style: const TextStyle(color: AppColors.textGray)),
                    if (created.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Created: $created', style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                    ],
                  ],
                ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildEquipmentCampaignsTab() {
    final summary = (_equipmentCampaignStats['summary'] is Map)
        ? Map<String, dynamic>.from(_equipmentCampaignStats['summary'] as Map)
        : <String, dynamic>{};
    final fulfillmentRate = _toDouble(summary['fulfillment_rate']);
    final campaignsCount = _toInt(summary['campaigns_count']);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Campaigns',
                      value: campaignsCount.toString(),
                      icon: Icons.campaign_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Fulfillment',
                      value: '${fulfillmentRate.toStringAsFixed(1)}%',
                      icon: Icons.percent_rounded,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openEquipmentCampaignFilters,
                      icon: const Icon(Icons.filter_alt_rounded, size: 18),
                      label: const Text('Filters'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () async {
                      await _loadEquipmentCampaigns();
                      await _loadEquipmentCampaignStats();
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingEquipmentCampaigns
              ? const Center(child: CircularProgressIndicator())
              : _equipmentCampaignsError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Failed to load: $_equipmentCampaignsError'),
                      ),
                    )
                  : _equipmentCampaigns.isEmpty
                      ? const Center(child: Text('No equipment campaigns found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _equipmentCampaigns.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _equipmentCampaigns.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton(
                                      onPressed: _equipmentCampaignPage > 1
                                          ? () {
                                              setState(() => _equipmentCampaignPage -= 1);
                                              _loadEquipmentCampaigns();
                                            }
                                          : null,
                                      child: const Text('Prev'),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Page $_equipmentCampaignPage / $_equipmentCampaignPages'),
                                    ),
                                    TextButton(
                                      onPressed: _equipmentCampaignPage < _equipmentCampaignPages
                                          ? () {
                                              setState(() => _equipmentCampaignPage += 1);
                                              _loadEquipmentCampaigns();
                                            }
                                          : null,
                                      child: const Text('Next'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final c = _equipmentCampaigns[index];
                            final title = (c['equipment_name'] ?? '').toString();
                            final status = (c['status'] ?? '').toString();
                            final needed = _toInt(c['quantity_needed']);
                            final fulfilled = _toInt(c['quantity_fulfilled']);
                            final fulfillment = _toDouble(c['fulfillment_percentage']);
                            final child = _asStringMap(c['child']);
                            final need = _asStringMap(c['need']);

                            final childName = child?['full_name']?.toString();
                            final needId = need?['need_id']?.toString();
                            final needStatus = need?['status']?.toString();
                            final needSeverity = need?['severity']?.toString();
                            final needPriority = need?['priority_score']?.toString();
                            final idRaw = c['campaign_id'] ?? c['id'];
                            final campaignId = idRaw is int ? idRaw : int.tryParse(idRaw.toString());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.accent2.withOpacity(0.18)),
                              ),
                              child: InkWell(
                                onTap: () => _openEquipmentCampaignManageSheet(c),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title.isEmpty ? 'Equipment Campaign' : title,
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Needed: $needed | Fulfilled: $fulfilled | ${fulfillment.toStringAsFixed(1)}%',
                                      style: const TextStyle(color: AppColors.textGray),
                                    ),
                                    if (childName != null || needId != null || needStatus != null || needSeverity != null || needPriority != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${childName != null ? 'Child: $childName' : ''}'
                                        '${childName != null && needId != null ? ' • ' : ''}'
                                        '${needId != null ? 'Need: $needId' : ''}'
                                        '${(childName != null || needId != null) && (needStatus != null || needSeverity != null || needPriority != null) ? ' • ' : ''}'
                                        '${needStatus != null ? 'Status: $needStatus' : ''}'
                                        '${needSeverity != null ? ' | Severity: $needSeverity' : ''}'
                                        '${needPriority != null ? ' | Priority: $needPriority' : ''}',
                                        style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        if (campaignId != null)
                                          Expanded(
                                            child: Text(
                                              'Campaign ID: $campaignId',
                                              style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                                            ),
                                          )
                                        else
                                          const Spacer(),
                                        OutlinedButton(
                                          onPressed: () => _openEquipmentCampaignManageSheet(c),
                                          child: const Text('Manage'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildViewToggleButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _donationsViewIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _donationsViewIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    final summary = _stats['summary'] as Map<String, dynamic>? ?? {};
    final recent = summary['recent30Days'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      controller: _donationsScrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildImpactV2Section(),
          const SizedBox(height: 16),
          // Stats Summary Cards
          // _buildStatsSummary(summary, recent),
          // const SizedBox(height: 16),
           _buildMonthlyDonationsChart(),
        const SizedBox(height: 16),
        
        _buildCampaignDistributionChart(),
        const SizedBox(height: 16),
        
        _buildDonationTypeComparisonChart(),
        const SizedBox(height: 16),
        

          // Top Donor Card
          _buildTopDonorCard(),
          const SizedBox(height: 16),

          // Distribution Chart
          _buildDistributionChart(),
          const SizedBox(height: 16),

          // Quick Donations Summary (جديد)
          _buildQuickDonationsSummary(),
          const SizedBox(height: 16),

          // Top Donors Section
          _buildTopDonorsSection(),
          const SizedBox(height: 16),

          // Recent Donors Section
          _buildLatestAnalyticsDonationsSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

 // أضف هذه الويدجت بعد _buildImpactV2Section في _buildAnalyticsContent()

Widget _buildMonthlyDonationsChart() {
  final Map<String, double> monthlyData = {};
  
  // تجميع البيانات الشهرية
  for (final donation in _filteredDonations) {
    final dateStr = donation['date']?.toString();
    if (dateStr != null) {
      try {
        final date = DateTime.parse(dateStr);
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final amount = double.tryParse(donation['amount'].toString()) ?? 0;
        monthlyData[key] = (monthlyData[key] ?? 0) + amount;
      } catch (_) {}
    }
  }
  
  final sortedMonths = monthlyData.keys.toList()..sort();
  final List<double> amounts = sortedMonths.map((month) => monthlyData[month] ?? 0).toList();
  
  if (sortedMonths.isEmpty) {
    return _buildEmptyChart('Monthly Donations');
  }
  
  // تحضير بيانات المخطط
  final barGroups = List.generate(sortedMonths.length, (index) {
    final month = sortedMonths[index];
    final monthNumber = int.tryParse(month.substring(5)) ?? 1;
    
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: amounts[index],
          gradient: LinearGradient(
            colors: [_getChartColor(index), _getChartColor(index).withOpacity(0.8)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 20,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: amounts.isNotEmpty ? amounts.reduce((a, b) => a > b ? a : b) * 1.1 : 1,
            color: Colors.grey.withOpacity(0.1),
          ),
        ),
      ],
    );
  });

  return Container(
    height: 260,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Donations',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Last 12 months',
          style: TextStyle(fontSize: 12, color: AppColors.textGray),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: BarChart(
            BarChartData(
              barGroups: barGroups,
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: AppColors.accent3, width: 1),
              ),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.accent1,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < sortedMonths.length) {
                        final monthName = _getMonthName(sortedMonths[value.toInt()]);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Transform.rotate(
                            angle: -0.3,
                            child: Text(
                              monthName,
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 28,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Text(
                          '${value.toInt()} JOD',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (bar) => AppColors.primary.withOpacity(0.9),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final monthName = _getMonthName(sortedMonths[group.x.toInt()]);
                    return BarTooltipItem(
                      '$monthName\n',
                      const TextStyle(color: Colors.white, fontSize: 11),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toStringAsFixed(0)} JOD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildCampaignDistributionChart() {
  // خريطة لتخزين إجمالي التبرعات لكل حملة
  final Map<String, double> campaignAmounts = {};
  double totalDonations = 0;
  
  // خريطة لأسماء الحملات
  final Map<int, String> campaignIdToName = {};
  
  // 1. تجميع أسماء الحملات
  for (final campaign in _campaigns) {
    final camp = campaign as Map<String, dynamic>;
    final id = camp['campaign_id'] as int?;
    final name = camp['name']?.toString() ?? 'Unnamed Campaign';
    if (id != null) {
      campaignIdToName[id] = name;
      campaignAmounts[name] = 0; // تهيئة بقيمة 0
    }
  }
  
  // 2. تجميع التبرعات من _donations (المصدر الأساسي)
  for (final donation in _donations) {
    final donationMap = _asStringMap(donation);
    if (donationMap == null) continue;
    
    final amount = double.tryParse(donationMap['amount']?.toString() ?? '0') ?? 0;
    if (amount == 0) continue;
    
    totalDonations += amount;
    
    // البحث عن campaign_id في أماكن مختلفة
    dynamic campaignIdRaw = donationMap['campaign_id'] ?? 
                           donationMap['campaign']?['campaign_id'] ?? 
                           donationMap['campaign']?['id'];
    
    String campaignName;
    
    if (campaignIdRaw != null) {
      final campaignId = campaignIdRaw is int ? campaignIdRaw : int.tryParse(campaignIdRaw.toString());
      
      if (campaignId != null && campaignIdToName.containsKey(campaignId)) {
        campaignName = campaignIdToName[campaignId]!;
      } else {
        // إذا كان هناك campaign_id ولكن ليس في قائمة الحملات
        campaignName = donationMap['campaign']?['name']?.toString() ?? 'Campaign $campaignId';
      }
    } else {
      // تبرعات عامة (بدون حملة)
      campaignName = 'General Donations';
    }
    
    campaignAmounts[campaignName] = (campaignAmounts[campaignName] ?? 0) + amount;
  }
  
  // 3. تجميع التبرعات من _latestDonations (المصدر الثانوي)
  for (final donation in _latestDonations) {
    final donationMap = _asStringMap(donation);
    if (donationMap == null) continue;
    
    final amount = double.tryParse(donationMap['amount']?.toString() ?? '0') ?? 0;
    if (amount == 0) continue;
    
    totalDonations += amount;
    
    dynamic campaignIdRaw = donationMap['campaign_id'] ?? 
                           donationMap['campaign']?['campaign_id'] ?? 
                           donationMap['campaign']?['id'];
    
    String campaignName;
    
    if (campaignIdRaw != null) {
      final campaignId = campaignIdRaw is int ? campaignIdRaw : int.tryParse(campaignIdRaw.toString());
      
      if (campaignId != null && campaignIdToName.containsKey(campaignId)) {
        campaignName = campaignIdToName[campaignId]!;
      } else {
        campaignName = donationMap['campaign']?['name']?.toString() ?? 'Campaign $campaignId';
      }
    } else {
      campaignName = 'General Donations';
    }
    
    campaignAmounts[campaignName] = (campaignAmounts[campaignName] ?? 0) + amount;
  }
  
  // 4. إزالة الحملات التي ليس لها تبرعات (إلا إذا أردنا عرضها)
  final validCampaigns = campaignAmounts.entries
      .where((entry) => entry.value > 0)
      .toList();
  
  if (validCampaigns.isEmpty) {
    return _buildNoCampaignsDataWidget();
  }
  
  // 5. فرز الحملات حسب القيمة
  validCampaigns.sort((a, b) => b.value.compareTo(a.value));
  
  final List<MapEntry<String, double>> sorted = validCampaigns;
  final total = sorted.fold(0.0, (sum, entry) => sum + entry.value);
  
  // 6. إنشاء المخطط الدائري
  final sections = sorted.asMap().entries.map((entry) {
    final index = entry.key;
    final item = entry.value;
    final value = item.value;
    final percentage = ((value / total) * 100).toStringAsFixed(1);
    final color = _getChartColor(index);
    
    return PieChartSectionData(
      color: color,
      value: value,
      title: value >= (total * 0.05) ? '$percentage%' : '',
      radius: 50,
      titleStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [Shadow(color: Colors.black38, blurRadius: 1)],
      ),
    );
  }).toList();

  return Container(
    height: 260,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donations by Campaign',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Total: ${total.toStringAsFixed(0)} JOD • ${sorted.length} campaign${sorted.length != 1 ? 's' : ''}',
          style: TextStyle(fontSize: 12, color: AppColors.textGray),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              // المخطط الدائري
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 25,
                    sectionsSpace: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // مفتاح الألوان
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < min(sorted.length, 6); i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getChartColor(i),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sorted[i].key,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${sorted[i].value.toStringAsFixed(0)} JOD',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${((sorted[i].value / total) * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (sorted.length > 6)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+ ${sorted.length - 6} more campaign${sorted.length - 6 != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textGray,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// دالة لعرض رسالة عندما لا توجد بيانات
Widget _buildNoCampaignsDataWidget() {
  final hasCampaigns = _campaigns.isNotEmpty;
  final hasDonations = _donations.isNotEmpty;
  
  String title;
  String message;
  IconData icon;
  
  if (hasCampaigns && !hasDonations) {
    title = 'No Donations Yet';
    message = 'You have campaigns but no donations have been made yet.';
    icon = Icons.money_off;
  } else if (!hasCampaigns && hasDonations) {
    title = 'Donations Not Linked to Campaigns';
    message = 'All donations are general and not assigned to specific campaigns.';
    icon = Icons.link_off;
  } else if (!hasCampaigns && !hasDonations) {
    title = 'No Data Available';
    message = 'Create campaigns and receive donations to see distribution.';
    icon = Icons.data_array;
  } else {
    title = 'Loading Campaign Data';
    message = 'Processing donation distribution...';
    icon = Icons.hourglass_empty;
  }
  
  return Container(
    height: 260,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donations by Campaign',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Distribution analysis',
          style: TextStyle(fontSize: 12, color: AppColors.textGray),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 60, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                
                if (hasCampaigns)
                  Column(
                    children: [
                      const Text(
                        'Available Campaigns:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: min(3, _campaigns.length),
                          itemBuilder: (context, index) {
                            final campaign = _campaigns[index] as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getChartColor(index),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      campaign['name']?.toString() ?? 'Unnamed',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGray,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
Widget _buildDonationTypeComparisonChart() {
  double moneyTotal = 0;
  double equipmentValue = 0;
  
  // التبرعات النقدية
  for (final donation in _filteredDonations) {
    moneyTotal += double.tryParse(donation['amount'].toString()) ?? 0;
  }
  
  // قيمة المعدات (افتراضية)
  for (final equipment in _equipmentDonations) {
    final value = double.tryParse(equipment['estimated_value']?.toString() ?? '0') ?? 0;
    equipmentValue += value;
  }
  
  final total = moneyTotal + equipmentValue;
  final maxValue = max(moneyTotal, equipmentValue) * 1.1;
  
  return Container(
    height: 280,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donations by Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Money vs Equipment donations',
          style: TextStyle(fontSize: 12, color: AppColors.textGray),
        ),
        const SizedBox(height: 16),
        
        // مخطط الأعمدة المقارنة
        Expanded(
          child: BarChart(
            BarChartData(
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: moneyTotal,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 40,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ],
                  showingTooltipIndicators: [0],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: equipmentValue,
                      gradient: LinearGradient(
                        colors: [Colors.purple, Colors.purple.withOpacity(0.8)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 40,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ],
                  showingTooltipIndicators: [0],
                ),
              ],
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: AppColors.accent3, width: 1),
              ),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.accent1,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final labels = ['Money', 'Equipment'];
                      if (value.toInt() < labels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            labels[value.toInt()],
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Text(
                          '${value.toInt()} JOD',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (bar) => AppColors.primary.withOpacity(0.9),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final labels = ['Money', 'Equipment'];
                    final values = [moneyTotal, equipmentValue];
                    return BarTooltipItem(
                      '${labels[group.x.toInt()]}\n',
                      const TextStyle(color: Colors.white, fontSize: 12),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toStringAsFixed(0)} JOD\n',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: '${total > 0 ? ((rod.toY / total) * 100).toStringAsFixed(1) : "0.0"}% of total',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              minY: 0,
              maxY: maxValue,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // الإحصائيات التفصيلية
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTypeStatItem(
              title: 'Money Donations',
              value: '${moneyTotal.toStringAsFixed(0)} JOD',
              percentage: total > 0 ? (moneyTotal / total * 100) : 0,
              color: AppColors.primary,
            ),
            _buildTypeStatItem(
              title: 'Equipment Value',
              value: '${equipmentValue.toStringAsFixed(0)} JOD',
              percentage: total > 0 ? (equipmentValue / total * 100) : 0,
              color: Colors.purple,
            ),
          ],
        ),
      ],
    ),
  );
}

// ========== دوال مساعدة ==========

Widget _buildEmptyChart(String title) {
  return Container(
    height: 180,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTypeStatItem({
  required String title,
  required String value,
  required double percentage,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textGray,
          ),
        ),
      ],
    ),
  );
}

Color _getChartColor(int index) {
  final colors = [
    AppColors.primary,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.blue,
    Colors.red,
    Colors.teal,
    Colors.amber,
    Colors.pink,
    Colors.cyan,
  ];
  return colors[index % colors.length];
}

String _getMonthName(String monthKey) {
  try {
    final monthNum = int.parse(monthKey.substring(5));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[monthNum - 1];
  } catch (_) {
    return monthKey;
  }
}

// أضف هذه الاستيرادات في بداية الملف إن لم تكن موجودة:
// import 'package:fl_chart/fl_chart.dart';

  Widget _buildImpactV2Section() {
    final recent = _stats['summary']?['recent30Days'] as Map<String, dynamic>? ?? {};
    final money = (_impactV2?['money_impact'] is Map)
        ? Map<String, dynamic>.from(_impactV2!['money_impact'] as Map)
        : <String, dynamic>{};
    final equipment = (_impactV2?['equipment_impact'] is Map)
        ? Map<String, dynamic>.from(_impactV2!['equipment_impact'] as Map)
        : <String, dynamic>{};
    final posts = (_impactV2?['impact_posts'] is Map)
        ? Map<String, dynamic>.from(_impactV2!['impact_posts'] as Map)
        : <String, dynamic>{};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Impact Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              if (_isLoadingImpactV2)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadImpactV2,
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManagerImpactPostsScreen()),
                );
              },
              icon: const Icon(Icons.article_rounded, size: 18),
              label: const Text('Manage Impact Posts'),
            ),
          ),
          if ((_impactV2Error ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _impactV2Error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Money Donated',
                  value: '${_toDouble(money['totalDonationsAmount']).toStringAsFixed(0)} JOD',
                  icon: Icons.attach_money_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Avg Donation',
                  value: '${(_toDouble(money['totalDonationsAmount']) / (_toDouble(money['donationCount']) > 0 ? _toDouble(money['donationCount']) : 1)).toStringAsFixed(0)} JOD',
                  icon: Icons.trending_up_rounded,
                  color: Colors.orange,
                ),
              ),

              
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Equipment Donated',
                  value: _toInt(equipment['total_count']).toString(),
                  icon: Icons.medical_services,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Equipment Allocated',
                  value: _toInt(equipment['allocated_count']).toString(),
                  icon: Icons.inventory_2,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Impact Posts',
                  value: _toInt(posts['total']).toString(),
                  icon: Icons.article_rounded,
                  color: AppColors.accent3,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
      child: _buildStatCard(
        title: 'Last 30 Days',
        value: '${_toDouble(recent['amount']).toStringAsFixed(0)} JOD',
        icon: Icons.calendar_month_rounded,
        color: Colors.purple,
      ),
    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDonationsSummary() {
    final donations = _filteredDonations;
    final allocations = _filteredAllocations;

    double totalDonations = 0;
    for (final d in donations) {
      final amount = double.tryParse(d['amount'].toString()) ?? 0;
      totalDonations += amount;
    }

    double totalAllocated = 0;
    for (final a in allocations) {
      final amount = double.tryParse(a['amount_allocated'].toString()) ?? 0;
      totalAllocated += amount;
    }

    final available = totalDonations - totalAllocated;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Donations Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                onPressed: () {
                  setState(() {
                    _donationsViewIndex = 1;
                  });
                },
                tooltip: 'View detailed donations',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Total Donations',
                  value: '${totalDonations.toStringAsFixed(0)} JOD',
                  icon: Icons.volunteer_activism_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Allocated',
                  value: '${totalAllocated.toStringAsFixed(0)} JOD',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${available.toStringAsFixed(0)} JOD',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: available >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Progress bar للتحصيل والتخصيص
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Allocation Progress',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: totalDonations > 0 ? (totalAllocated / totalDonations).clamp(0.0, 1.0) : 0,
                backgroundColor: Colors.grey.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${totalDonations > 0 ? ((totalAllocated / totalDonations) * 100).toStringAsFixed(1) : "0.0"}% allocated',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${((totalDonations - totalAllocated) / totalDonations * 100).toStringAsFixed(1)}% available',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationsListContent() {
    return Column(
      children: [
        // Donations and Allocations List
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Charts Section
                _buildChartsSection(),
                const SizedBox(height: 16),
                
                // Allocations List
                _buildAllocationsList(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDonationsSummaryCard() {
    final donations = _filteredDonations;
    final allocations = _filteredAllocations;

    double totalDonations = 0;
    for (final d in donations) {
      final amount = double.tryParse(d['amount'].toString()) ?? 0;
      totalDonations += amount;
    }

    double totalAllocated = 0;
    for (final a in allocations) {
      final amount = double.tryParse(a['amount_allocated'].toString()) ?? 0;
      totalAllocated += amount;
    }

    final available = totalDonations - totalAllocated;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Donations Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.analytics_rounded, size: 20),
                onPressed: () {
                  setState(() {
                    _donationsViewIndex = 0;
                  });
                },
                tooltip: 'View analytics',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Total Donations', '${totalDonations.toStringAsFixed(0)} JOD'),
          const SizedBox(height: 8),
          _buildSummaryRow('Allocated to support', '${totalAllocated.toStringAsFixed(0)} JOD'),
          const SizedBox(height: 8),
          _buildSummaryRow('Current estimated balance', '${available.toStringAsFixed(0)} JOD'),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(Map<String, dynamic> summary, Map<String, dynamic> recent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Donation Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildStatCard(
                title: 'Total Donations',
                value: '${_toDouble(summary['totalDonations']).toStringAsFixed(0)} JOD',
                icon: Icons.attach_money_rounded,
                color: AppColors.primary,
              ),
              _buildStatCard(
                title: 'Total Donors',
                value: (summary['totalDonors'] ?? 0).toString(),
                icon: Icons.people_rounded,
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'Avg Donation',
                value: '${_toDouble(summary['avgDonation']).toStringAsFixed(0)} JOD',
                icon: Icons.trending_up_rounded,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: 'Last 30 Days',
                value: '${_toDouble(recent['amount']).toStringAsFixed(0)} JOD',
                icon: Icons.calendar_month_rounded,
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopDonorCard() {
    final topDonor = _stats['topDonor'] as Map<String, dynamic>?;
    
    if (topDonor == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No top donor data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Top Donor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Donor #${topDonor['donor_id']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDonorStat(
                            icon: Icons.attach_money_rounded,
                            label: 'Total',
                            value: '${_toDouble(topDonor['total_amount']).toStringAsFixed(0)} JOD',
                          ),
                          const SizedBox(width: 16),
                          _buildDonorStat(
                            icon: Icons.receipt_long_rounded,
                            label: 'Donations',
                            value: (topDonor['donation_count'] ?? 0).toString(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionChart() {
    if (_donationDistribution.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No donation distribution data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Donation Amount Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ..._donationDistribution.map((item) {
            final percentage = double.tryParse(item['percentage'].toString()) ?? 0;
            return _buildDistributionBar(
              label: item['range'].toString(),
              percentage: percentage,
              count: item['count']?.toString() ?? '0',
              total: '${_toDouble(item['total']).toStringAsFixed(0)} JOD',
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDistributionBar({
    required String label,
    required double percentage,
    required String count,
    required String total,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count donations',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                total,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopDonorsSection() {
    if (_topDonors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No top donors data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Donors',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._topDonors.asMap().entries.map((entry) {
            final index = entry.key;
            final donor = entry.value;
            final donorInfo = _asStringMap(donor['donor_info']) ?? {};
            
            return _buildTopDonorTile(
              rank: index + 1,
              name: donorInfo['name']?.toString() ?? 'Anonymous',
              totalAmount: '${_toDouble(donor['total_amount']).toStringAsFixed(0)} JOD',
              donationCount: (donor['donation_count'] ?? 0).toString(),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTopDonorTile({
    required int rank,
    required String name,
    required String totalAmount,
    required String donationCount,
  }) {
    Color rankColor;
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        break;
      case 2:
        rankColor = Colors.grey;
        break;
      case 3:
        rankColor = Colors.brown;
        break;
      default:
        rankColor = Colors.grey.withOpacity(0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: rankColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.attach_money_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      totalAmount,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.receipt_long_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$donationCount donations',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget _buildLatestAnalyticsDonationsSection() {
    if (_processedDonors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No recent donations data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Donors',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._processedDonors.map((donorData) {
            final donor = _asStringMap(donorData['donor']) ?? {};
            final totalAmount = donorData['totalAmount'] as double;
            final donationCount = donorData['donationCount'] as int;
            final firstDate = donorData['firstDonationDate'] as DateTime?;
            final lastDate = donorData['lastDonationDate'] as DateTime?;
            
            return _buildDonorCard(
              donor: donor,
              totalAmount: totalAmount,
              donationCount: donationCount,
              firstDonationDate: firstDate,
              lastDonationDate: lastDate,
              donations: donorData['donations'] as List<dynamic>,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDonorCard({
    required Map<String, dynamic> donor,
    required double totalAmount,
    required int donationCount,
    required DateTime? firstDonationDate,
    required DateTime? lastDonationDate,
    required List<dynamic> donations,
  }) {
    final isExpanded = _expandedDonorId == donor['id'];
    final isCorporateSponsor = donor['is_corporate'] == true ||
        totalAmount >= 1000;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      donor['name']?.toString().substring(0, 1).toUpperCase() ?? 'A',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            donor['name']?.toString() ?? 'Anonymous',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isCorporateSponsor)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'Corporate Sponsor',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${donationCount.toString()} donation${donationCount != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDonorStatItem(
                            icon: Icons.attach_money_rounded,
                            value: '${totalAmount.toStringAsFixed(0)} JOD',
                            label: 'Total Donated',
                          ),
                          const SizedBox(width: 16),
                          _buildDonorStatItem(
                            icon: Icons.calendar_today_rounded,
                            value: lastDonationDate != null
                                ? '${lastDonationDate.day}/${lastDonationDate.month}/${lastDonationDate.year}'
                                : 'N/A',
                            label: 'Last Donation',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (donor['email'] != null)
                    _buildContactInfoRow(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      value: donor['email'].toString(),
                    ),
                  if (donor['phone'] != null)
                    _buildContactInfoRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone',
                      value: donor['phone'].toString(),
                    ),
                  
                  const SizedBox(height: 16),
                  const Text(
                    'Donation History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDonationDetailsRow(
                    label: 'First Donation',
                    value: firstDonationDate != null
                        ? '${firstDonationDate.day}/${firstDonationDate.month}/${firstDonationDate.year}'
                        : 'N/A',
                  ),
                  _buildDonationDetailsRow(
                    label: 'Donation Frequency',
                    value: _calculateFrequency(donations),
                  ),
                  _buildDonationDetailsRow(
                    label: 'Average Donation',
                    value: '${(totalAmount / donationCount).toStringAsFixed(0)} JOD',
                  ),
                  
                  const SizedBox(height: 16),
                  const Text(
                    'Recent Donations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...donations.take(3).map((donation) {
                    final amount = double.tryParse(donation['amount'].toString()) ?? 0;
                    final dateStr = donation['date']?.toString();
                    final campaign = donation['campaign'] as Map<String, dynamic>?;
                    
                    return _buildRecentDonationItem(
                      amount: amount,
                      date: dateStr,
                      campaignName: campaign?['name']?.toString(),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _viewDonorDetails(
                            donor: donor,
                            donations: donations,
                            totalAmount: totalAmount,
                            donationCount: donationCount,
                            firstDonationDate: firstDonationDate,
                            lastDonationDate: lastDonationDate,
                          ),
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text('View Details'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _contactDonor(donor),
                          icon: const Icon(Icons.message_rounded, size: 16),
                          label: const Text('Contact'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedDonorId = null;
                    } else {
                      _expandedDonorId = donor['id'];
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationDetailsRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDonationItem({
    required double amount,
    required String? date,
    required String? campaignName,
  }) {
    DateTime? parsedDate;
    if (date != null) {
      try {
        parsedDate = DateTime.parse(date);
      } catch (_) {}
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${amount.toStringAsFixed(0)} JOD',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (parsedDate != null)
            Text(
              '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          if (campaignName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                campaignName,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _calculateFrequency(List<dynamic> donations) {
    if (donations.length < 2) return 'One-time';
    
    final dates = <DateTime>[];
    for (final donation in donations) {
      final dateStr = donation['date']?.toString();
      if (dateStr != null) {
        try {
          dates.add(DateTime.parse(dateStr));
        } catch (_) {}
      }
    }
    
    if (dates.length < 2) return 'One-time';
    
    dates.sort();
    final daysBetween = dates.last.difference(dates.first).inDays;
    final avgDays = daysBetween / (dates.length - 1);
    
    if (avgDays <= 30) return 'Monthly';
    if (avgDays <= 90) return 'Quarterly';
    if (avgDays <= 365) return 'Yearly';
    return 'Occasional';
  }

  void _viewDonorDetails({
    required Map<String, dynamic> donor,
    required List<dynamic> donations,
    required double totalAmount,
    required int donationCount,
    required DateTime? firstDonationDate,
    required DateTime? lastDonationDate,
  }) {
    _showDonorDetailsDialog(
      context: context,
      donorInfo: donor,
      totalAmount: totalAmount,
      donationCount: donationCount,
      firstDonationDate: firstDonationDate,
      lastDonationDate: lastDonationDate,
      donations: donations,
    );
  }

  void _contactDonor(Map<String, dynamic> donor) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email_rounded),
              title: const Text('Send Email'),
              onTap: () {
                Navigator.pop(context);
                if (donor['email'] != null) {
                  launchUrl(Uri.parse('mailto:${donor['email']}'));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_rounded),
              title: const Text('Make a Call'),
              onTap: () {
                Navigator.pop(context);
                if (donor['phone'] != null) {
                  launchUrl(Uri.parse('tel:${donor['phone']}'));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.message_rounded),
              title: const Text('Send Message'),
              onTap: () {
                Navigator.pop(context);
                // Implement message functionality
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDonorDetailsDialog({
    required BuildContext context,
    required Map<String, dynamic> donorInfo,
    required double totalAmount,
    required int donationCount,
    required DateTime? firstDonationDate,
    required DateTime? lastDonationDate,
    required List<dynamic> donations,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: donorInfo['avatar_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: Image.network(
                                    donorInfo['avatar_url'].toString(),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.person_rounded, size: 30, color: AppColors.primary),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                donorInfo['name']?.toString() ?? 'Anonymous',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              
                              const SizedBox(height: 4),
                              
                              if (donorInfo['is_corporate_sponsor'] == true)
                                Row(
                                  children: [
                                    const Icon(Icons.business_rounded, size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      donorInfo['company_name']?.toString() ?? 'Corporate Sponsor',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Donation Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDetailStatItem(
                                label: 'Total Donated',
                                value: '${totalAmount.toStringAsFixed(0)} JOD',
                              ),
                              _buildDetailStatItem(
                                label: 'Average Donation',
                                value: '${(totalAmount / donationCount).toStringAsFixed(0)} JOD',
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDetailStatItem(
                                label: 'First Donation',
                                value: firstDonationDate != null
                                  ? DateFormat('yyyy/MM/dd').format(firstDonationDate!)
                                  : 'N/A',
                              ),
                              _buildDetailStatItem(
                                label: 'Last Donation',
                                value: lastDonationDate != null
                                  ? DateFormat('yyyy/MM/dd').format(lastDonationDate!)
                                  : 'N/A',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Recent Donations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    ...donations.take(5).map((donation) {
                      final amount = double.tryParse(donation['amount'].toString()) ?? 0;
                      final dateString = donation['date']?.toString();
                      final campaign = donation['campaign'] as Map<String, dynamic>?;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.volunteer_activism_rounded, color: Colors.green),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${amount.toStringAsFixed(0)} JOD',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (dateString != null)
                                        Text(
                                          _formatDate(dateString),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 4),
                                  
                                  if (campaign != null && campaign['name'] != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.campaign_rounded, size: 12, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          campaign['name'].toString(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
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
                    }).toList(),
                    
                    if (donations.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '+ ${donations.length - 5} more donations',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailStatItem({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        
        const SizedBox(height: 4),
        
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsDonationTile({
    required String amount,
    required String donorName,
    required String date,
    String? campaignName,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volunteer_activism_rounded, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  donorName,
                  style: const TextStyle(fontSize: 14),
                ),
                if (campaignName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        campaignName,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== دوال الفلاتر المتقدمة الجديدة ==========
  Widget _buildFiltersBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Column(
            children: [
              // Quick Filters
              _buildQuickFiltersRow(),
              const SizedBox(height: 12),
              
              // Search and Advanced Toggle
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by donor name, amount, invoice number...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        _searchText = value.trim();
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.date_range_rounded),
                    onPressed: _showDateRangePicker,
                    tooltip: 'Select date range',
                  ),
                  IconButton(
                    icon: Icon(
                      _showAdvancedFilters ? Icons.filter_alt_off : Icons.filter_alt,
                    ),
                    onPressed: () {
                      setState(() {
                        _showAdvancedFilters = !_showAdvancedFilters;
                      });
                    },
                    tooltip: _showAdvancedFilters ? 'Hide advanced filters' : 'Show advanced filters',
                  ),
                ],
              ),
              
              // Advanced Filters
              if (_showAdvancedFilters) ...[
                const SizedBox(height: 16),
                _buildAdvancedFilters(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFiltersRow() {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': 'Today', 'value': 'today'},
      {'label': 'This Week', 'value': 'this_week'},
      {'label': 'This Month', 'value': 'this_month'},
      {'label': 'Large Donations', 'value': 'large'},
      {'label': 'Recurring', 'value': 'recurring'},
    ];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _quickFilter == filter['value'] ||
              (filter['value'] == 'large' && _filterState['onlyLargeDonations'] == true) ||
              (filter['value'] == 'recurring' && _filterState['onlyRecurring'] == true);
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (filter['value'] == 'large') {
                    _filterState['onlyLargeDonations'] = selected;
                    if (selected) _quickFilter = 'custom';
                  } else if (filter['value'] == 'recurring') {
                    _filterState['onlyRecurring'] = selected;
                    if (selected) _quickFilter = 'custom';
                  } else {
                    _quickFilter = selected ? filter['value']! : 'all';
                    _filterState['dateRange'] = filter['value'];
                  }
                });
                _applyAdvancedFilters();
              },
              backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Form(
      key: _filterFormKey,
      child: Column(
        children: [
          // Amount Range
          _buildAmountFilter(),
          const SizedBox(height: 12),
          
          // Donor Type
          _buildDonorTypeFilter(),
          const SizedBox(height: 12),
          
          // Campaign Filter
          _buildCampaignFilter(),
          const SizedBox(height: 12),
          
          // Additional Filters
          _buildAdditionalFilters(),
          const SizedBox(height: 12),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_filterFormKey.currentState?.validate() ?? false) {
                      _applyAdvancedFilters();
                      setState(() {
                        _showAdvancedFilters = false;
                      });
                    }
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amount Range (JOD)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Min',
                  prefixText: 'JOD ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                initialValue: _filterState['amountMin']?.toString(),
                onChanged: (value) {
                  final num = double.tryParse(value);
                  _filterState['amountMin'] = num;
                },
              ),
            ),
            const SizedBox(width: 12),
            const Text('to', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Max',
                  prefixText: 'JOD ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                initialValue: _filterState['amountMax']?.toString(),
                onChanged: (value) {
                  final num = double.tryParse(value);
                  _filterState['amountMax'] = num;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDonorTypeFilter() {
    final types = [
      {'label': 'Individuals', 'value': 'individual'},
      {'label': 'Corporate', 'value': 'corporate'},
      {'label': 'Anonymous', 'value': 'anonymous'},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donor Type',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: types.map((type) {
            final isSelected = (_filterState['donorTypes'] as List).contains(type['value']);
            
            return ChoiceChip(
              label: Text(type['label']!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  final donorTypes = List<String>.from(_filterState['donorTypes']);
                  if (selected) {
                    donorTypes.add(type['value']!);
                  } else {
                    donorTypes.remove(type['value']);
                  }
                  _filterState['donorTypes'] = donorTypes;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCampaignFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Campaign',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'Select campaign',
          ),
          items: [
            const DropdownMenuItem(value: 0, child: Text('All Campaigns')),
            ..._availableCampaigns.map((campaign) {
              return DropdownMenuItem(
                value: campaign['campaign_id'] as int,
                child: Text(campaign['name']?.toString() ?? 'Unnamed'),
              );
            }).toList(),
          ],
          value: _filterState['campaignIds'].isNotEmpty ? _filterState['campaignIds'][0] : 0,
          onChanged: (value) {
            setState(() {
              if (value == 0) {
                _filterState['campaignIds'] = [];
              } else {
                _filterState['campaignIds'] = [value!];
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildAdditionalFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Filters',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        
        // Invoice-linked only
        Row(
          children: [
            Switch(
              value: _onlyInvoiceLinked,
              onChanged: (val) {
                setState(() {
                  _onlyInvoiceLinked = val;
                });
                _applyFilters();
              },
              activeColor: AppColors.primary,
            ),
            const Text(
              'Invoice-linked only',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        
        // Only with contact info
        Row(
          children: [
            Switch(
              value: _filterState['onlyWithContact'] == true,
              onChanged: (val) {
                setState(() {
                  _filterState['onlyWithContact'] = val;
                });
              },
              activeColor: AppColors.primary,
            ),
            const Text(
              'Only donors with contact info',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        
        // Sorting
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Sort by',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          value: _filterState['sortBy'] as String,
          items: const [
            DropdownMenuItem(value: 'date_desc', child: Text('Date (Newest first)')),
            DropdownMenuItem(value: 'date_asc', child: Text('Date (Oldest first)')),
            DropdownMenuItem(value: 'amount_desc', child: Text('Amount (High to Low)')),
            DropdownMenuItem(value: 'amount_asc', child: Text('Amount (Low to High)')),
            DropdownMenuItem(value: 'donor_name', child: Text('Donor Name (A-Z)')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _filterState['sortBy'] = value;
              });
            }
          },
        ),
      ],
    );
  }
  // ========== نهاية دوال الفلاتر المتقدمة ==========

  Widget _buildQuickFilterChip(String label, String value) {
    final bool selected = _quickFilter == value && !(_quickFilter == 'all' && _selectedRange != null);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _quickFilter = value;
            if (value != 'custom') {
              _selectedRange = null;
            }
          });
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDonationsList() {
    final donations = _filteredDonations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Donations'),
        if (donations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No donations found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...donations.map((d) => _buildDonationTile(d)).toList(),
      ],
    );
  }

  Widget _buildDonationTile(Map<String, dynamic> donation) {
    final amount = double.tryParse(donation['amount'].toString()) ?? 0;
    final dateString = donation['date']?.toString();
    DateTime? date;
    if (dateString != null) {
      try {
        date = DateTime.parse(dateString);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent3.withOpacity(0.15),
            ),
            child: const Icon(Icons.volunteer_activism_rounded, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${amount.toStringAsFixed(0)} JOD',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date != null ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' : 'Date not available',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationsList() {
    final allocations = _filteredAllocations;
    final invoices = (_data['invoices'] as Map?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Allocations to families / invoices'),
        if (allocations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No allocations found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...allocations.map((a) => _buildAllocationTile(a as Map<String, dynamic>, invoices)).toList(),
      ],
    );
  }

  Widget _buildAllocationTile(Map<String, dynamic> allocation, Map invoices) {
    final amount = double.tryParse(allocation['amount_allocated'].toString()) ?? 0;
    final invoiceId = allocation['invoice_id'];
    final invoice = invoiceId != null ? invoices[invoiceId] as Map<String, dynamic>? : null;

    final dateString = allocation['created_at']?.toString();
    DateTime? date;
    if (dateString != null) {
      try {
        date = DateTime.parse(dateString);
      } catch (_) {}
    }

    final status = invoice != null ? invoice['status']?.toString() ?? '' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.15),
            ),
            child: const Icon(Icons.receipt_long_rounded, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${amount.toStringAsFixed(0)} JOD allocated',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (invoiceId != null)
                  Text(
                    'Invoice #$invoiceId${status.isNotEmpty ? ' • $status' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 4),
                Text(
                  date != null ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' : 'Date not available',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    final donations = _filteredDonations;
    final allocations = _filteredAllocations;

    double totalDonations = 0;
    for (final d in donations) {
      final amount = double.tryParse((d as Map<String, dynamic>)['amount'].toString()) ?? 0;
      totalDonations += amount;
    }

    double totalAllocated = 0;
    for (final a in allocations) {
      final amount = double.tryParse((a as Map<String, dynamic>)['amount_allocated'].toString()) ?? 0;
      totalAllocated += amount;
    }

    final double remaining =
    ((totalDonations - totalAllocated).clamp(0.0, double.infinity)).toDouble();

    if (totalDonations <= 0 && totalAllocated <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No data yet to display donation charts.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Donation Impact Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildAllocationBar(totalDonations, totalAllocated, remaining),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildChartLegendItem('Allocated to families', totalDonations > 0 ? (totalAllocated / totalDonations * 100) : 0, Colors.green),
              _buildChartLegendItem('Remaining balance', totalDonations > 0 ? (remaining / totalDonations * 100) : 0, AppColors.accent3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationBar(double total, double allocated, double remaining) {
    if (total <= 0) {
      return Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(7),
        ),
      );
    }

    final allocatedRatio = (allocated / total).clamp(0.0, 1.0);
    final remainingRatio = (remaining / total).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final allocatedWidth = width * allocatedRatio;
        final remainingWidth = width * remainingRatio;

        return Stack(
          children: [
            Container(
              height: 14,
              width: width,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            Container(
              height: 14,
              width: allocatedWidth,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            Positioned(
              left: allocatedWidth,
              child: Container(
                height: 14,
                width: remainingWidth,
                decoration: BoxDecoration(
                  color: AppColors.accent3,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartLegendItem(String label, double percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  double _campaignToDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _campaignToInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime? _campaignParseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  String _campaignFormatDate(dynamic v) {
    final dt = _campaignParseDate(v);
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int? _campaignDaysLeft(dynamic endDate) {
    final end = _campaignParseDate(endDate);
    if (end == null) return null;
    final now = DateTime.now();
    return end.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  Widget _buildCampaignsSummaryCard() {
    final campaigns = _campaigns.map((e) => e as Map<String, dynamic>).toList();
    final totalCollected = campaigns.fold<double>(0, (sum, c) => sum + _campaignToDouble(c['total_donations']));
    final totalGoal = campaigns.fold<double>(0, (sum, c) => sum + _campaignToDouble(c['target_amount']));
    final activeCount = campaigns.where((c) => (c['status'] ?? '').toString() == 'Active').length;
    final completionRate = totalGoal > 0 ? ((totalCollected / totalGoal) * 100).clamp(0.0, 100.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Campaigns Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCampaignKpiTile(
                  title: 'Total collected',
                  value: '${totalCollected.toStringAsFixed(0)} JOD',
                  icon: Icons.volunteer_activism,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCampaignKpiTile(
                  title: 'Campaigns goal',
                  value: '${totalGoal.toStringAsFixed(0)} JOD',
                  icon: Icons.flag,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCampaignKpiTile(
                  title: 'Active campaigns',
                  value: activeCount.toString(),
                  icon: Icons.campaign,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCampaignKpiTile(
                  title: 'Completion rate',
                  value: '${completionRate.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: AppColors.accent3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignMiniMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsTab() {
    if (_campaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_rounded,
              size: 64,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No campaigns yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first donation campaign',
              style: TextStyle(fontSize: 14, color: Colors.grey.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCampaignsSummaryCard(),
        const SizedBox(height: 12),
        ..._campaigns.map((e) {
          final campaign = e as Map<String, dynamic>;
          return _buildCampaignTile(campaign);
        }).toList(),
      ],
    );
  }

  void _applyFilters() {
    List<dynamic> donations = List<dynamic>.from(_donations);
    List<dynamic> allocations = List<dynamic>.from(_allocations);

    DateTimeRange? effectiveRange = _selectedRange;

    if (effectiveRange == null && _quickFilter != 'all') {
      final now = DateTime.now();
      if (_quickFilter == 'this_month') {
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        effectiveRange = DateTimeRange(start: start, end: end);
      } else if (_quickFilter == 'last_month') {
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0, 23, 59, 59);
        effectiveRange = DateTimeRange(start: start, end: end);
      } else if (_quickFilter == 'last_3_months') {
        final start = DateTime(now.year, now.month - 2, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        effectiveRange = DateTimeRange(start: start, end: end);
      }
    }

    bool isInRange(DateTime? date) {
      if (effectiveRange == null || date == null) return true;
      return !date.isBefore(effectiveRange.start) && !date.isAfter(effectiveRange.end);
    }

    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    donations = donations.where((d) {
      final map = d as Map<String, dynamic>;
      final date = _parseDate(map['date']);
      if (!isInRange(date)) return false;

      if (_searchText.isNotEmpty) {
        final text = _searchText.toLowerCase();
        final amountStr = map['amount']?.toString().toLowerCase() ?? '';
        if (!amountStr.contains(text)) {
          return false;
        }
      }

      return true;
    }).toList();

    allocations = allocations.where((a) {
      final map = a as Map<String, dynamic>;
      final date = _parseDate(map['created_at']);
      if (!isInRange(date)) return false;

      if (_onlyInvoiceLinked && (map['invoice_id'] == null)) {
        return false;
      }

      if (_searchText.isNotEmpty) {
        final text = _searchText.toLowerCase();
        final amountStr = map['amount_allocated']?.toString().toLowerCase() ?? '';
        final invoiceIdStr = map['invoice_id']?.toString().toLowerCase() ?? '';
        if (!amountStr.contains(text) && !invoiceIdStr.contains(text)) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      _filteredDonations = donations;
      _filteredAllocations = allocations;
    });
  }

  Future<void> _openCampaignDialog({Map<String, dynamic>? campaign}) async {
    final isEdit = campaign != null;

    final nameController = TextEditingController(text: campaign?['name']?.toString() ?? '');
    final descriptionController = TextEditingController(text: campaign?['description']?.toString() ?? '');
    final targetController = TextEditingController(text: campaign != null ? campaign['target_amount']?.toString() ?? '' : '');

    String status = campaign?['status']?.toString() ?? 'Upcoming';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Campaign' : 'Create Campaign'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target amount (JOD)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'Upcoming', child: Text('Upcoming')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'Archived', child: Text('Archived')),
                  ],
                  onChanged: (val) {
                    if (val != null) status = val;
                  },
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final targetText = targetController.text.trim();
                if (name.isEmpty || targetText.isEmpty) return;

                final body = <String, dynamic>{
                  'name': name,
                  'description': descriptionController.text.trim(),
                  'target_amount': double.tryParse(targetText) ?? 0,
                  'status': status,
                };

                try {
                  if (isEdit) {
                    await ManagerDashboardService.updateDonationCampaign(
                      campaign!['campaign_id'] as int,
                      body,
                    );
                  } else {
                    await ManagerDashboardService.createDonationCampaign(body);
                  }
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (_) {
                  if (context.mounted) {
                    Navigator.pop(context, false);
                  }
                }
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _loadData();
    }
  }

  Widget _buildCampaignTile(Map<String, dynamic> campaign) {
    final double target = (campaign['target_amount'] ?? 0).toDouble();
    final double total = (campaign['total_donations'] ?? 0).toDouble();
    final double progress = (campaign['progress_percentage'] ?? 0).toDouble();

    final donorsCount = _campaignToInt(campaign['donors_count']);
    final remaining = (target - total) > 0 ? (target - total) : 0.0;
    final daysLeft = _campaignDaysLeft(campaign['end_date']);
    final startDate = _campaignFormatDate(campaign['start_date']);
    final endDate = _campaignFormatDate(campaign['end_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showCampaignImpact(campaign),
        onLongPress: () => _openCampaignDialog(campaign: campaign),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    campaign['name']?.toString() ?? 'Campaign',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(campaign['status']?.toString() ?? ''),
              ],
            ),
            const SizedBox(height: 4),
            if ((campaign['description']?.toString().isNotEmpty ?? false))
              Text(
                campaign['description'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress > 0 ? (progress / 100).clamp(0.0, 1.0) : 0.0,
              backgroundColor: Colors.grey.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent3),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${total.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} JOD',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${progress.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCampaignMiniMetric(
                    label: 'Donors',
                    value: donorsCount.toString(),
                    icon: Icons.people,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCampaignMiniMetric(
                    label: 'Remaining',
                    value: '${remaining.toStringAsFixed(0)} JOD',
                    icon: Icons.savings,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCampaignMiniMetric(
                    label: 'Days left',
                    value: daysLeft == null ? '-' : (daysLeft < 0 ? '0' : daysLeft.toString()),
                    icon: Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Start: $startDate',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'End: $endDate',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showCampaignImpact(campaign),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.accent1.withOpacity(0.9)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('View analytics'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openCampaignDialog(campaign: campaign),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Manage'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Active':
        color = Colors.green;
        break;
      case 'Completed':
        color = Colors.blueAccent;
        break;
      case 'Archived':
        color = Colors.grey;
        break;
      default:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showCampaignImpact(Map<String, dynamic> campaign) async {
    final campaignId = campaign['campaign_id'] as int?;
    if (campaignId == null) return;

    Map<String, dynamic>? impact;
    try {
      final result = await ManagerDashboardService.getDonationCampaignImpact(campaignId);
      impact = result;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load campaign impact: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted || impact == null) return;

    final double totalDonations = (impact['total_donations'] ?? 0).toDouble();
    final double targetAmount = (impact['target_amount'] ?? 0).toDouble();
    final double progress = (impact['progress_percentage'] ?? 0).toDouble();
    final double allocated = (impact['total_allocated_from_campaign'] ?? 0).toDouble();
    final int sessionsSupported = impact['supported_sessions_count'] ?? 0;
    final int childrenSupported = impact['supported_children_count'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      campaign['name']?.toString() ?? 'Campaign',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pop(context);
                      _openCampaignDialog(campaign: campaign);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if ((campaign['description']?.toString().isNotEmpty ?? false))
                Text(
                  campaign['description'] as String,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress > 0 ? (progress / 100).clamp(0.0, 1.0) : 0.0,
                backgroundColor: Colors.grey.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent3),
                minHeight: 10,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${totalDonations.toStringAsFixed(0)} / ${targetAmount.toStringAsFixed(0)} JOD',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${progress.toStringAsFixed(1)}% of target',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Campaign Impact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildImpactChip(
                    icon: Icons.event_available,
                    label: 'Sessions supported',
                    value: sessionsSupported.toString(),
                  ),
                  _buildImpactChip(
                    icon: Icons.child_care,
                    label: 'Children supported',
                    value: childrenSupported.toString(),
                  ),
                  _buildImpactChip(
                    icon: Icons.attach_money_rounded,
                    label: 'Total allocated',
                    value: '${allocated.toStringAsFixed(0)} JOD',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _tabController.animateTo(0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View Donations Analytics'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImpactChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryDark),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${(difference.inDays / 7).floor()} weeks ago';
      }
    } catch (e) {
      return dateString;
    }
  }
}

class _PieChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  
  _PieChartPainter({required this.data});
  Color _getColorForIndex(int index) {
  final colors = [
    AppColors.primary,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.blue,
    Colors.red,
    Colors.teal,
  ];
  return colors[index % colors.length];
}

  
  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold(0.0, (sum, entry) => sum + entry.value);
    if (total == 0) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;
    
    double startAngle = -90 * (3.1415926535 / 180);
    
    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i].value / total) * 360 * (3.1415926535 / 180);
      
      final paint = Paint()
        ..color = _getColorForIndex(i)
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      startAngle += sweepAngle;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
