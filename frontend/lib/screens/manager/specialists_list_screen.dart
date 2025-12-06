import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SpecialistsListScreen extends StatefulWidget {
  @override
  _SpecialistsListScreenState createState() => _SpecialistsListScreenState();
}

class _SpecialistsListScreenState extends State<SpecialistsListScreen> {
  List<Map<String, dynamic>> _specialists = [];
  List<Map<String, dynamic>> _filteredSpecialists = [];
  TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadSpecialists();
  }

  void _loadSpecialists() {
    // بيانات تجريبية
    setState(() {
      _specialists = [
        {
          'id': 'SP001',
          'name': 'Dr. Sarah Ahmed',
          'specialty': 'Speech Therapy',
          'status': 'Active',
          'sessionsThisMonth': 56,
          'salary': 8500,
          'rating': 4.8,
          'childrenAssigned': 12,
          'nextVacation': '2025-12-20',
          'schedule': 'Mon-Fri, 9AM-5PM',
          'email': 'sarah.ahmed@therapy.com',
          'phone': '+1234567890',
          'joinDate': '2023-01-15',
          'performance': 'Excellent',
          'notes': 'Very dedicated specialist',
        },
        {
          'id': 'SP002',
          'name': 'Dr. Michael Chen',
          'specialty': 'Behavioral Therapy',
          'status': 'Active',
          'sessionsThisMonth': 48,
          'salary': 9200,
          'rating': 4.9,
          'childrenAssigned': 8,
          'nextVacation': '2025-12-15',
          'schedule': 'Sun-Thu, 8AM-4PM',
          'email': 'michael.chen@therapy.com',
          'phone': '+1234567891',
          'joinDate': '2022-11-20',
          'performance': 'Outstanding',
          'notes': 'Excellent with behavioral cases',
        },
        {
          'id': 'SP003',
          'name': 'Dr. Lisa Johnson',
          'specialty': 'Occupational Therapy',
          'status': 'Absent',
          'sessionsThisMonth': 32,
          'salary': 7800,
          'rating': 4.7,
          'childrenAssigned': 10,
          'nextVacation': 'On Leave',
          'schedule': 'Mon-Sat, 10AM-6PM',
          'email': 'lisa.johnson@therapy.com',
          'phone': '+1234567892',
          'joinDate': '2023-03-10',
          'performance': 'Good',
          'notes': 'Currently on medical leave',
        },
        {
          'id': 'SP004',
          'name': 'Dr. James Wilson',
          'specialty': 'Educational Therapy',
          'status': 'Active',
          'sessionsThisMonth': 61,
          'salary': 8800,
          'rating': 4.6,
          'childrenAssigned': 15,
          'nextVacation': '2026-01-10',
          'schedule': 'Tue-Sat, 9AM-5PM',
          'email': 'james.wilson@therapy.com',
          'phone': '+1234567893',
          'joinDate': '2022-08-05',
          'performance': 'Excellent',
          'notes': 'Highly experienced with educational therapy',
        },
        {
          'id': 'SP005',
          'name': 'Dr. Fatima Al-Masri',
          'specialty': 'Play Therapy',
          'status': 'Inactive',
          'sessionsThisMonth': 0,
          'salary': 0,
          'rating': 4.5,
          'childrenAssigned': 0,
          'nextVacation': '-',
          'schedule': 'Not Available',
          'email': 'fatima.almasri@therapy.com',
          'phone': '+1234567894',
          'joinDate': '2023-06-20',
          'performance': 'N/A',
          'notes': 'On extended leave',
        },
        {
          'id': 'SP006',
          'name': 'Dr. Robert Garcia',
          'specialty': 'Speech Therapy',
          'status': 'Active',
          'sessionsThisMonth': 52,
          'salary': 8200,
          'rating': 4.7,
          'childrenAssigned': 9,
          'nextVacation': '2026-02-15',
          'schedule': 'Mon-Fri, 8AM-4PM',
          'email': 'robert.garcia@therapy.com',
          'phone': '+1234567895',
          'joinDate': '2023-04-12',
          'performance': 'Very Good',
          'notes': 'Specialized in speech disorders',
        },
        {
          'id': 'SP007',
          'name': 'Dr. Amina Hassan',
          'specialty': 'Music Therapy',
          'status': 'Active',
          'sessionsThisMonth': 45,
          'salary': 7900,
          'rating': 4.8,
          'childrenAssigned': 7,
          'nextVacation': '2025-12-25',
          'schedule': 'Sun-Wed, 9AM-5PM',
          'email': 'amina.hassan@therapy.com',
          'phone': '+1234567896',
          'joinDate': '2023-02-28',
          'performance': 'Excellent',
          'notes': 'Creative approach with music therapy',
        },
        {
          'id': 'SP008',
          'name': 'Dr. David Miller',
          'specialty': 'Art Therapy',
          'status': 'Active',
          'sessionsThisMonth': 38,
          'salary': 8100,
          'rating': 4.6,
          'childrenAssigned': 6,
          'nextVacation': '2026-03-01',
          'schedule': 'Thu-Sun, 10AM-6PM',
          'email': 'david.miller@therapy.com',
          'phone': '+1234567897',
          'joinDate': '2023-05-15',
          'performance': 'Good',
          'notes': 'Great with artistic children',
        },
      ];
      _filteredSpecialists = _specialists;
    });
  }

  void _filterSpecialists() {
    String searchText = _searchController.text.toLowerCase();

    setState(() {
      _filteredSpecialists = _specialists.where((specialist) {
        bool matchesSearch = specialist['name'].toLowerCase().contains(searchText) ||
            specialist['specialty'].toLowerCase().contains(searchText) ||
            specialist['email'].toLowerCase().contains(searchText);

        bool matchesFilter = _selectedFilter == 'All' ||
            specialist['status'] == _selectedFilter ||
            specialist['specialty'] == _selectedFilter;

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _showSpecialistDetails(Map<String, dynamic> specialist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  specialist['name'],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    _buildDetailSection(
                      title: 'Basic Information',
                      children: [
                        _buildDetailItem('ID', specialist['id']),
                        _buildDetailItem('Specialty', specialist['specialty']),
                        _buildDetailItem('Status', specialist['status']),
                        _buildDetailItem('Rating', '${specialist['rating']}/5'),
                        _buildDetailItem('Join Date', specialist['joinDate']),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Contact Information
                    _buildDetailSection(
                      title: 'Contact Information',
                      children: [
                        _buildDetailItem('Email', specialist['email']),
                        _buildDetailItem('Phone', specialist['phone']),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Work Information
                    _buildDetailSection(
                      title: 'Work Information',
                      children: [
                        _buildDetailItem('Schedule', specialist['schedule']),
                        _buildDetailItem('Sessions This Month', specialist['sessionsThisMonth'].toString()),
                        _buildDetailItem('Children Assigned', specialist['childrenAssigned'].toString()),
                        _buildDetailItem('Monthly Salary', '\$${specialist['salary']}'),
                        _buildDetailItem('Performance', specialist['performance']),
                        _buildDetailItem('Next Vacation', specialist['nextVacation']),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Notes
                    _buildDetailSection(
                      title: 'Notes',
                      children: [
                        Text(
                          specialist['notes'],
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 30),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _editSpecialist(specialist),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 15),
                            ),
                            icon: Icon(Icons.edit),
                            label: Text('Edit Specialist'),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _viewSchedule(specialist),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.primary),
                              padding: EdgeInsets.symmetric(vertical: 15),
                            ),
                            icon: Icon(Icons.schedule),
                            label: Text('View Schedule'),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _adjustSalary(specialist),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.green),
                              padding: EdgeInsets.symmetric(vertical: 15),
                            ),
                            icon: Icon(Icons.attach_money, color: Colors.green),
                            label: Text('Adjust Salary', style: TextStyle(color: Colors.green)),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deactivateSpecialist(specialist),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red),
                              padding: EdgeInsets.symmetric(vertical: 15),
                            ),
                            icon: Icon(Icons.block, color: Colors.red),
                            label: Text(
                              specialist['status'] == 'Active' ? 'Deactivate' : 'Activate',
                              style: TextStyle(color: Colors.red),
                            ),
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
      ),
    );
  }

  Widget _buildDetailSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.accent1,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textGray,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  void _editSpecialist(Map<String, dynamic> specialist) {
    Navigator.pop(context); // Close details sheet first

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Specialist'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: specialist['name']),
                decoration: InputDecoration(labelText: 'Full Name'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: TextEditingController(text: specialist['specialty']),
                decoration: InputDecoration(labelText: 'Specialty'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: TextEditingController(text: specialist['email']),
                decoration: InputDecoration(labelText: 'Email'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: TextEditingController(text: specialist['phone']),
                decoration: InputDecoration(labelText: 'Phone'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: TextEditingController(text: specialist['salary'].toString()),
                decoration: InputDecoration(labelText: 'Monthly Salary'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Specialist updated successfully'),
                  backgroundColor: AppColors.ment,
                ),
              );
            },
            child: Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _viewSchedule(Map<String, dynamic> specialist) {
    Navigator.pop(context); // Close details sheet

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('${specialist['name']} - Schedule'),
          ),
          body: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(Icons.schedule, color: AppColors.primary),
                    title: Text('Working Schedule'),
                    subtitle: Text(specialist['schedule']),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Weekly Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      _buildScheduleDay('Monday', '9:00 AM - 5:00 PM'),
                      _buildScheduleDay('Tuesday', '9:00 AM - 5:00 PM'),
                      _buildScheduleDay('Wednesday', '9:00 AM - 5:00 PM'),
                      _buildScheduleDay('Thursday', '9:00 AM - 5:00 PM'),
                      _buildScheduleDay('Friday', '9:00 AM - 5:00 PM'),
                      _buildScheduleDay('Saturday', '10:00 AM - 2:00 PM'),
                      _buildScheduleDay('Sunday', 'Off'),
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

  Widget _buildScheduleDay(String day, String hours) {
    return Card(
      child: ListTile(
        title: Text(day),
        trailing: Text(hours),
      ),
    );
  }

  void _adjustSalary(Map<String, dynamic> specialist) {
    Navigator.pop(context); // Close details sheet

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Salary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Salary: \$${specialist['salary']}'),
            SizedBox(height: 20),
            TextField(
              controller: TextEditingController(text: specialist['salary'].toString()),
              decoration: InputDecoration(
                labelText: 'New Salary',
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Salary updated successfully'),
                  backgroundColor: AppColors.ment,
                ),
              );
            },
            child: Text('Update Salary'),
          ),
        ],
      ),
    );
  }

  void _deactivateSpecialist(Map<String, dynamic> specialist) {
    Navigator.pop(context); // Close details sheet

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(specialist['status'] == 'Active' ? 'Deactivate Specialist' : 'Activate Specialist'),
        content: Text('Are you sure you want to ${specialist['status'] == 'Active' ? 'deactivate' : 'activate'} ${specialist['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                int index = _specialists.indexWhere((s) => s['id'] == specialist['id']);
                if (index != -1) {
                  _specialists[index]['status'] = specialist['status'] == 'Active' ? 'Inactive' : 'Active';
                  if (_specialists[index]['status'] == 'Inactive') {
                    _specialists[index]['salary'] = 0;
                  } else {
                    _specialists[index]['salary'] = 7800;
                  }
                  _filterSpecialists();
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Specialist ${specialist['status'] == 'Active' ? 'deactivated' : 'activated'} successfully'),
                  backgroundColor: specialist['status'] == 'Active' ? Colors.orange : AppColors.ment,
                ),
              );
            },
            child: Text(specialist['status'] == 'Active' ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }

  void _addNewSpecialist() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Specialist'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Full Name'),
              ),
              SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(labelText: 'Email'),
              ),
              SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(labelText: 'Phone'),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField(
                decoration: InputDecoration(labelText: 'Specialty'),
                items: [
                  'Speech Therapy',
                  'Behavioral Therapy',
                  'Occupational Therapy',
                  'Educational Therapy',
                  'Play Therapy',
                  'Music Therapy',
                  'Art Therapy',
                ].map((specialty) {
                  return DropdownMenuItem(
                    value: specialty,
                    child: Text(specialty),
                  );
                }).toList(),
                onChanged: (value) {},
              ),
              SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Monthly Salary',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Specialist added successfully'),
                  backgroundColor: AppColors.ment,
                ),
              );
            },
            child: Text('Add Specialist'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Specialists'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: _addNewSpecialist,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search specialists...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) => _filterSpecialists(),
                ),

                SizedBox(height: 16),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('All'),
                        selected: _selectedFilter == 'All',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = 'All';
                            _filterSpecialists();
                          });
                        },
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text('Active'),
                        selected: _selectedFilter == 'Active',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = 'Active';
                            _filterSpecialists();
                          });
                        },
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text('Speech Therapy'),
                        selected: _selectedFilter == 'Speech Therapy',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = 'Speech Therapy';
                            _filterSpecialists();
                          });
                        },
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text('Behavioral'),
                        selected: _selectedFilter == 'Behavioral Therapy',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = 'Behavioral Therapy';
                            _filterSpecialists();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Results Count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredSpecialists.length} Specialists Found',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.download, size: 16),
                  label: Text('Export'),
                ),
              ],
            ),
          ),

          // Specialists List
          Expanded(
            child: _filteredSpecialists.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: AppColors.textLight),
                  SizedBox(height: 16),
                  Text(
                    'No specialists found',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _filteredSpecialists.length,
              itemBuilder: (context, index) {
                final specialist = _filteredSpecialists[index];
                Color statusColor = _getStatusColor(specialist['status']);

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          specialist['name'].split(' ').map((n) => n[0]).take(2).join(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      specialist['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(specialist['specialty']),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                specialist['status'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            Text(
                              ' ${specialist['rating']}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => _showSpecialistDetails(specialist),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return AppColors.primary;
      case 'absent': return AppColors.warning;
      case 'inactive': return AppColors.textGray;
      default: return AppColors.textGray;
    }
  }
}