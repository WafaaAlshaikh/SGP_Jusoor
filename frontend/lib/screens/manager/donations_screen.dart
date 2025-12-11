import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

class DonationsScreen extends StatefulWidget {
  @override
  _DonationsScreenState createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  int _selectedTab = 0; // 0: Donors, 1: Campaigns
  String _selectedFilter = 'All';

  // Sample Campaigns Data
  final List<Map<String, dynamic>> _campaigns = [
    {
      'campaign_id': 1,
      'title': 'Special Needs Equipment',
      'description': 'Provide specialized equipment for children with special needs',
      'goal_amount': 20000.00,
      'collected_amount': 15200.00,
      'start_date': '2024-01-01',
      'end_date': '2024-03-31',
      'status': 'Active',
      'donor_count': 45,
      'category': 'Equipment',
    },
    {
      'campaign_id': 2,
      'title': 'Summer Therapy Program',
      'description': 'Fund summer therapy sessions for underprivileged children',
      'goal_amount': 15000.00,
      'collected_amount': 9800.00,
      'start_date': '2024-03-01',
      'end_date': '2024-06-30',
      'status': 'Active',
      'donor_count': 32,
      'category': 'Program',
    },
    {
      'campaign_id': 3,
      'title': 'Building Renovation',
      'description': 'Renovate therapy rooms and facilities',
      'goal_amount': 50000.00,
      'collected_amount': 32500.00,
      'start_date': '2023-11-01',
      'end_date': '2024-04-30',
      'status': 'Active',
      'donor_count': 67,
      'category': 'Infrastructure',
    },
    {
      'campaign_id': 4,
      'title': 'Emergency Medical Fund',
      'description': 'Emergency medical assistance for children',
      'goal_amount': 10000.00,
      'collected_amount': 10000.00,
      'start_date': '2023-09-01',
      'end_date': '2023-12-31',
      'status': 'Completed',
      'donor_count': 28,
      'category': 'Medical',
    },
    {
      'campaign_id': 5,
      'title': 'Staff Training Program',
      'description': 'Advanced training for specialists and therapists',
      'goal_amount': 12000.00,
      'collected_amount': 8500.00,
      'start_date': '2024-02-01',
      'end_date': '2024-05-31',
      'status': 'Active',
      'donor_count': 19,
      'category': 'Training',
    },
  ];

  // Sample Donors Data
  final List<Map<String, dynamic>> _donors = [
    {
      'donor_id': 1,
      'name': 'ABC Corporation',
      'type': 'Corporate',
      'email': 'corporate@abccorp.com',
      'phone': '+962 7 9999 8888',
      'total_donations': 12500.00,
      'donation_count': 8,
      'first_donation': '2023-05-15',
      'last_donation': '2024-01-15',
      'status': 'Active',
      'city': 'Amman',
      'notes': 'Major corporate partner',
    },
    {
      'donor_id': 2,
      'name': 'Mohammed Ali',
      'type': 'Individual',
      'email': 'mohammed.ali@email.com',
      'phone': '+962 7 8888 7777',
      'total_donations': 8500.00,
      'donation_count': 12,
      'first_donation': '2022-08-10',
      'last_donation': '2024-01-10',
      'status': 'Active',
      'city': 'Irbid',
      'notes': 'Monthly recurring donor',
    },
    {
      'donor_id': 3,
      'name': 'Al-Noor Foundation',
      'type': 'Foundation',
      'email': 'info@alnoor.org',
      'phone': '+962 6 4444 3333',
      'total_donations': 6200.00,
      'donation_count': 3,
      'first_donation': '2023-11-05',
      'last_donation': '2024-01-05',
      'status': 'Active',
      'city': 'Amman',
      'notes': 'Focus on special needs',
    },
    {
      'donor_id': 4,
      'name': 'Tech Solutions Co.',
      'type': 'Corporate',
      'email': 'donations@techsolutions.com',
      'phone': '+962 6 5555 4444',
      'total_donations': 18500.00,
      'donation_count': 5,
      'first_donation': '2022-12-01',
      'last_donation': '2023-12-28',
      'status': 'Active',
      'city': 'Amman',
      'notes': 'Annual corporate sponsor',
    },
    {
      'donor_id': 5,
      'name': 'Sara Ahmed',
      'type': 'Individual',
      'email': 'sara.ahmed@email.com',
      'phone': '+962 7 7777 6666',
      'total_donations': 3200.00,
      'donation_count': 7,
      'first_donation': '2023-03-20',
      'last_donation': '2024-01-02',
      'status': 'Active',
      'city': 'Zarqa',
      'notes': 'In memory donations',
    },
    {
      'donor_id': 6,
      'name': 'Future Builders Inc.',
      'type': 'Corporate',
      'email': 'contact@futurebuilders.com',
      'phone': '+962 6 3333 2222',
      'total_donations': 7500.00,
      'donation_count': 4,
      'first_donation': '2023-09-15',
      'last_donation': '2023-12-15',
      'status': 'Inactive',
      'city': 'Amman',
      'notes': 'Contact renewal needed',
    },
    {
      'donor_id': 7,
      'name': 'Omar Hassan',
      'type': 'Individual',
      'email': 'omar.hassan@email.com',
      'phone': '+962 7 6666 5555',
      'total_donations': 2100.00,
      'donation_count': 9,
      'first_donation': '2023-01-10',
      'last_donation': '2023-12-20',
      'status': 'Active',
      'city': 'Aqaba',
      'notes': 'Monthly small donor',
    },
    {
      'donor_id': 8,
      'name': 'Medical Equipment Ltd.',
      'type': 'Corporate',
      'email': 'donate@medequip.com',
      'phone': '+962 6 7777 8888',
      'total_donations': 15000.00,
      'donation_count': 2,
      'first_donation': '2023-07-01',
      'last_donation': '2024-01-20',
      'status': 'Active',
      'city': 'Amman',
      'notes': 'In-kind equipment donations',
    },
  ];

  // Statistics
  double get _totalCampaignsAmount {
    return _campaigns.fold(0.0, (sum, campaign) => sum + campaign['collected_amount']);
  }

  double get _totalCampaignsGoal {
    return _campaigns.fold(0.0, (sum, campaign) => sum + campaign['goal_amount']);
  }

  double get _totalDonations {
    return _donors.fold(0.0, (sum, donor) => sum + donor['total_donations']);
  }

  int get _activeCampaigns {
    return _campaigns.where((campaign) => campaign['status'] == 'Active').length;
  }

  int get _totalDonors => _donors.length;

  int get _activeDonors {
    return _donors.where((donor) => donor['status'] == 'Active').length;
  }

  List<Map<String, dynamic>> get _filteredDonors {
    List<Map<String, dynamic>> filtered = List.from(_donors);

    if (_selectedFilter == 'Active') {
      filtered = filtered.where((d) => d['status'] == 'Active').toList();
    } else if (_selectedFilter == 'Corporate') {
      filtered = filtered.where((d) => d['type'] == 'Corporate').toList();
    } else if (_selectedFilter == 'Individual') {
      filtered = filtered.where((d) => d['type'] == 'Individual').toList();
    }

    // Sort by total donations (highest first)
    filtered.sort((a, b) => b['total_donations'].compareTo(a['total_donations']));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _selectedTab == 0 ? 'Donors Management' : 'Campaigns Management',
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textWhite),
        actions: [
          if (_selectedTab == 0)
            IconButton(
              icon: Icon(Icons.download),
              onPressed: _exportDonorsReport,
              tooltip: 'Export Donors Report',
            ),
          if (_selectedTab == 1)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: _addNewCampaign,
              tooltip: 'Add New Campaign',
            ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(0, 'Donors', Icons.group),
                ),
                Expanded(
                  child: _buildTabButton(1, 'Campaigns', Icons.campaign),
                ),
              ],
            ),
          ),

          // Statistics Cards
          _buildStatisticsCards(),

          // Filters (for donors tab)
          if (_selectedTab == 0) _buildDonorFilters(),

          // Content
          Expanded(
            child: _selectedTab == 0
                ? _buildDonorsList()
                : _buildCampaignsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int tabIndex, String label, IconData icon) {
    final isSelected = _selectedTab == tabIndex;
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tabIndex;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.textWhite : AppColors.primary,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.textWhite : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Container(
      padding: EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: _selectedTab == 0
            ? [
          _buildStatCard(
            title: 'Total Donations',
            value: '\$${_totalDonations.toStringAsFixed(0)}',
            icon: Icons.attach_money,
            color: AppColors.success,
            subtitle: 'All time',
          ),
          _buildStatCard(
            title: 'Total Donors',
            value: '$_totalDonors',
            icon: Icons.group,
            color: AppColors.primary,
            subtitle: '$_activeDonors active',
          ),
          _buildStatCard(
            title: 'Top Donor',
            value: _getTopDonorName(),
            icon: Icons.star,
            color: AppColors.warning,
            subtitle: '\$${_getTopDonorAmount().toStringAsFixed(0)}',
          ),
          _buildStatCard(
            title: 'Avg Donation',
            value: '\$${(_totalDonations / _totalDonors).toStringAsFixed(0)}',
            icon: Icons.trending_up,
            color: AppColors.info,
            subtitle: 'Per donor',
          ),
        ]
            : [
          _buildStatCard(
            title: 'Total Collected',
            value: '\$${_totalCampaignsAmount.toStringAsFixed(0)}',
            icon: Icons.attach_money,
            color: AppColors.success,
            subtitle: 'From campaigns',
          ),
          _buildStatCard(
            title: 'Campaigns Goal',
            value: '\$${_totalCampaignsGoal.toStringAsFixed(0)}',
            icon: Icons.flag,
            color: AppColors.primary,
            subtitle: 'Total target',
          ),
          _buildStatCard(
            title: 'Active Campaigns',
            value: '$_activeCampaigns',
            icon: Icons.campaign,
            color: AppColors.warning,
            subtitle: '${_campaigns.length} total',
          ),
          _buildStatCard(
            title: 'Completion Rate',
            value: '${((_totalCampaignsAmount / _totalCampaignsGoal) * 100).toStringAsFixed(1)}%',
            icon: Icons.percent,
            color: AppColors.info,
            subtitle: 'Overall progress',
          ),
        ],
      ),
    );
  }

  String _getTopDonorName() {
    if (_donors.isEmpty) return 'None';
    _donors.sort((a, b) => b['total_donations'].compareTo(a['total_donations']));
    return _donors.first['name'];
  }

  double _getTopDonorAmount() {
    if (_donors.isEmpty) return 0;
    _donors.sort((a, b) => b['total_donations'].compareTo(a['total_donations']));
    return _donors.first['total_donations'];
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              Icon(Icons.more_vert, color: AppColors.textLight, size: 20),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonorFilters() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: Row(
        children: [
          Text(
            'Filter by:',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 14,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  SizedBox(width: 8),
                  _buildFilterChip('Active'),
                  SizedBox(width: 8),
                  _buildFilterChip('Corporate'),
                  SizedBox(width: 8),
                  _buildFilterChip('Individual'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(filter),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? filter : 'All';
        });
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.textWhite : AppColors.textDark,
      ),
    );
  }

  Widget _buildDonorsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredDonors.length,
      itemBuilder: (context, index) {
        final donor = _filteredDonors[index];
        return _buildDonorCard(donor);
      },
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> donor) {
    final firstDate = DateTime.parse(donor['first_donation']);
    final lastDate = DateTime.parse(donor['last_donation']);
    final formattedFirstDate = DateFormat('MMM yyyy').format(firstDate);
    final formattedLastDate = DateFormat('MMM yyyy').format(lastDate);
    final isTopDonor = donor['total_donations'] == _getTopDonorAmount();

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status and rank
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getDonorStatusColor(donor['status']).withOpacity(0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isTopDonor)
                      Icon(Icons.star, size: 18, color: AppColors.warning),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getDonorStatusColor(donor['status']),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        donor['status'],
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getDonorTypeColor(donor['type']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        donor['type'],
                        style: TextStyle(
                          color: _getDonorTypeColor(donor['type']),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${donor['total_donations'].toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          // Donor Details
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Donor Info Row
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getDonorTypeColor(donor['type']),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          donor['name'].substring(0, 1),
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            donor['name'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: AppColors.textGray),
                              SizedBox(width: 4),
                              Text(
                                donor['city'],
                                style: TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Donation Stats
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDonorStat(
                        label: 'Total Donations',
                        value: '\$${donor['total_donations'].toStringAsFixed(0)}',
                        icon: Icons.attach_money,
                      ),
                      _buildDonorStat(
                        label: 'Donation Count',
                        value: '${donor['donation_count']}',
                        icon: Icons.receipt,
                      ),
                      _buildDonorStat(
                        label: 'Avg Donation',
                        value: '\$${(donor['total_donations'] / donor['donation_count']).toStringAsFixed(0)}',
                        icon: Icons.trending_up,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // Contact Info
                Row(
                  children: [
                    Expanded(
                      child: _buildContactInfo(
                        icon: Icons.email,
                        label: 'Email',
                        value: donor['email'],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildContactInfo(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: donor['phone'],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Donation Timeline
                Row(
                  children: [
                    Expanded(
                      child: _buildTimelineInfo(
                        label: 'First Donation',
                        value: formattedFirstDate,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildTimelineInfo(
                        label: 'Last Donation',
                        value: formattedLastDate,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Notes (if any)
                if (donor['notes'] != null && donor['notes'].isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            donor['notes'],
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewDonorDetails(donor),
                        icon: Icon(Icons.visibility, size: 18),
                        label: Text('View Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _contactDonor(donor),
                        icon: Icon(Icons.message, size: 18),
                        label: Text('Contact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textWhite,
                        ),
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

  Widget _buildDonorStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textGray,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textGray,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineInfo({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _campaigns.length,
      itemBuilder: (context, index) {
        final campaign = _campaigns[index];
        return _buildCampaignCard(campaign);
      },
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> campaign) {
    final progress = campaign['collected_amount'] / campaign['goal_amount'];
    final percentage = (progress * 100).toInt();
    final startDate = DateTime.parse(campaign['start_date']);
    final endDate = DateTime.parse(campaign['end_date']);
    final formattedStartDate = DateFormat('MMM d, yyyy').format(startDate);
    final formattedEndDate = DateFormat('MMM d, yyyy').format(endDate);
    final daysRemaining = endDate.difference(DateTime.now()).inDays;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campaign Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getCampaignStatusColor(campaign['status']).withOpacity(0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getCampaignStatusColor(campaign['status']),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    campaign['status'],
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCampaignCategoryColor(campaign['category']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    campaign['category'],
                    style: TextStyle(
                      color: _getCampaignCategoryColor(campaign['category']),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campaign Title and Description
                Text(
                  campaign['title'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  campaign['description'],
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 14,
                  ),
                ),

                SizedBox(height: 16),

                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.accent2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 100 ? AppColors.success : AppColors.primary,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${campaign['collected_amount'].toStringAsFixed(0)} collected',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                        ),
                        Text(
                          'Goal: \$${campaign['goal_amount'].toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Campaign Stats
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCampaignStat(
                        label: 'Donors',
                        value: '${campaign['donor_count']}',
                        icon: Icons.group,
                      ),
                      _buildCampaignStat(
                        label: 'Remaining',
                        value: '\$${(campaign['goal_amount'] - campaign['collected_amount']).toStringAsFixed(0)}',
                        icon: Icons.flag,
                      ),
                      _buildCampaignStat(
                        label: 'Days Left',
                        value: '${daysRemaining > 0 ? daysRemaining : 0}',
                        icon: Icons.calendar_today,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // Timeline
                Row(
                  children: [
                    Expanded(
                      child: _buildCampaignTimeline(
                        label: 'Start Date',
                        value: formattedStartDate,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildCampaignTimeline(
                        label: 'End Date',
                        value: formattedEndDate,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewCampaignDetails(campaign),
                        icon: Icon(Icons.bar_chart, size: 18),
                        label: Text('View Analytics'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _manageCampaign(campaign),
                        icon: Icon(Icons.edit, size: 18),
                        label: Text('Manage'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textWhite,
                        ),
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

  Widget _buildCampaignStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textGray,
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignTimeline({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  Color _getDonorStatusColor(String status) {
    switch (status) {
      case 'Active':
        return AppColors.success;
      case 'Inactive':
        return AppColors.warning;
      default:
        return AppColors.textGray;
    }
  }

  Color _getDonorTypeColor(String type) {
    switch (type) {
      case 'Corporate':
        return AppColors.primary;
      case 'Foundation':
        return AppColors.info;
      case 'Individual':
        return AppColors.success;
      default:
        return AppColors.textGray;
    }
  }

  Color _getCampaignStatusColor(String status) {
    switch (status) {
      case 'Active':
        return AppColors.primary;
      case 'Completed':
        return AppColors.success;
      case 'Upcoming':
        return AppColors.info;
      case 'Canceled':
        return AppColors.error;
      default:
        return AppColors.textGray;
    }
  }

  Color _getCampaignCategoryColor(String category) {
    switch (category) {
      case 'Equipment':
        return AppColors.primary;
      case 'Program':
        return AppColors.success;
      case 'Infrastructure':
        return AppColors.info;
      case 'Medical':
        return AppColors.error;
      case 'Training':
        return AppColors.warning;
      default:
        return AppColors.textGray;
    }
  }

  // Action Methods
  void _exportDonorsReport() {
    _showSnackBar('Donors report exported successfully');
  }

  void _addNewCampaign() {
    _showSnackBar('Opening new campaign form...');
  }

  void _viewDonorDetails(Map<String, dynamic> donor) {
    _showSnackBar('Viewing details for ${donor['name']}');
  }

  void _contactDonor(Map<String, dynamic> donor) {
    _showSnackBar('Contacting ${donor['name']}...');
  }

  void _viewCampaignDetails(Map<String, dynamic> campaign) {
    _showSnackBar('Viewing analytics for "${campaign['title']}"');
  }

  void _manageCampaign(Map<String, dynamic> campaign) {
    _showSnackBar('Managing campaign "${campaign['title']}"');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}