import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import 'sessions_tab.dart';
import '../models/session.dart';
import '../screens/booking_screen.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';
import 'reports_tab.dart';

class ChildTabs extends StatefulWidget {
  final Child child;
  const ChildTabs({super.key, required this.child});

  @override
  State<ChildTabs> createState() => _ChildTabsState();
}

class _ChildTabsState extends State<ChildTabs> {
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
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(
            widget.child.fullName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
            tabs: const [
              Tab(icon: Icon(Icons.person_outline), text: 'Profile'),
              Tab(icon: Icon(Icons.calendar_today), text: 'Sessions'),
              Tab(icon: Icon(Icons.assessment), text: 'Reports'),
              Tab(icon: Icon(Icons.payment), text: 'Payments'),
              Tab(icon: Icon(Icons.folder_open), text: 'Documents'),
              Tab(icon: Icon(Icons.smart_toy), text: 'AI & Chat'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(),
            _buildSessionsTab(context),
            _buildReportsTab(),
            _buildPaymentsTab(),
            _buildDocumentsTab(),
            _buildAiChatTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            print('🎯 FAB Pressed - Child: ${widget.child.fullName}');
            print('   - Registration Status: ${widget.child.registrationStatus}');
            print('   - Current Institution ID: ${widget.child.currentInstitutionId}');
            print('   - Current Institution Name: ${widget.child.currentInstitutionName}');

            if (widget.child.currentInstitutionId != null) {
              print('✅ Opening Booking Screen with real Institution ID: ${widget.child.currentInstitutionId}');

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookingScreen(
                    child: widget.child,
                    institutionId: widget.child.currentInstitutionId!,
                  ),
                ),
              );
            } else {
              print('❌ Child has no institution');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Child must be registered in an institution to book sessions'),
                  backgroundColor: _warningColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
          child: const Icon(Icons.add),
          tooltip: 'Book New Session',
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProfileTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // Header Card
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor.withOpacity(0.8), _primaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  radius: 30,
                  child: Text(
                    widget.child.fullName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.child.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.child.condition != null)
                  Text(
                    widget.child.condition!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      const SizedBox(height: 16),

      // Registration Status Card
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            color: widget.child.currentInstitutionId != null
                ? _successColor.withOpacity(0.1)
                : _warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.child.currentInstitutionId != null
                  ? _successColor.withOpacity(0.3)
                  : _warningColor.withOpacity(0.3),
            ),
          ),
          child: ListTile(
            leading: Icon(
              widget.child.currentInstitutionId != null
                  ? Icons.check_circle
                  : Icons.warning,
              color: widget.child.currentInstitutionId != null
                  ? _successColor
                  : _warningColor,
            ),
            title: Text(
              widget.child.currentInstitutionId != null ? 'Registered' : 'Not Registered',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.child.currentInstitutionId != null
                    ? _successColor
                    : _warningColor,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.child.currentInstitutionId != null)
                  Text(
                    'Institution: ${widget.child.currentInstitutionName ?? "Yasmeen Autism Center"}',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  const Text('Child needs institution registration'),
                Text(
                  'Status: ${widget.child.registrationStatus}',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),

      const SizedBox(height: 16),

      // Personal Information
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Date of Birth', widget.child.dateOfBirth ?? '-'),
              _buildInfoRow('Gender', widget.child.gender ?? '-'),
              _buildInfoRow('Condition', widget.child.condition ?? '-'),
              _buildInfoRow('Medical History', widget.child.medicalHistory ?? '-'),
              if (widget.child.currentInstitutionName != null)
                _buildInfoRow('Current Institution', widget.child.currentInstitutionName!),
              if (widget.child.currentInstitutionId != null)
                _buildInfoRow('Institution ID', widget.child.currentInstitutionId.toString()),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(BuildContext context) {
    return FutureBuilder<String>(
      future: _getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(color: _primaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading Sessions...',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, size: 48, color: _errorColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load sessions',
                  style: TextStyle(fontSize: 16, color: _errorColor),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final token = snapshot.data!;
        return SessionsTab(child: widget.child, token: token);
      },
    );
  }

  Widget _buildReportsTab() {
    return ReportsTab(child: widget.child);
  }

  Widget _buildPaymentsTab() {
    return FutureBuilder<String>(
      future: _getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(color: _primaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading Payments...',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, size: 48, color: _errorColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load payments',
                  style: TextStyle(fontSize: 16, color: _errorColor),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final token = snapshot.data!;
        return FutureBuilder<List<dynamic>>(
          future: _loadChildInvoices(token),
          builder: (context, invoiceSnapshot) {
            if (invoiceSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: CircularProgressIndicator(color: _primaryColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Invoices...',
                      style: TextStyle(color: _textSecondary),
                    ),
                  ],
                ),
              );
            }

            if (invoiceSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _errorColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.error_outline, size: 48, color: _errorColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load invoices',
                      style: TextStyle(fontSize: 16, color: _errorColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final invoices = invoiceSnapshot.data ?? [];

            if (invoices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.receipt_long, size: 64, color: _textSecondary.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Payments Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payment invoices will appear here\nonce sessions are completed',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invoices.length,
              itemBuilder: (context, idx) {
                final invoice = invoices[idx];
                final session = invoice['Session'];
                final sessionTypeName = session?['SessionType']?['name'] ??
                    session?['session_type'] ??
                    'Session';
                final amount = invoice['total_amount']?.toString() ??
                    invoice['amount']?.toString() ??
                    '0.00';
                final status = invoice['status']?.toString() ?? 'Pending';
                final isPaid = status.toLowerCase() == 'paid';
                final date = invoice['issued_date']?.toString() ??
                    invoice['due_date']?.toString() ??
                    'N/A';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPaid ? _successColor.withOpacity(0.1) : _warningColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPaid ? Icons.check_circle : Icons.pending,
                          color: isPaid ? _successColor : _warningColor,
                        ),
                      ),
                      title: Text(
                        sessionTypeName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date: ${date.split('T')[0]}', style: TextStyle(color: _textSecondary)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${amount} JOD',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPaid ? _successColor.withOpacity(0.1) : _warningColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPaid ? _successColor.withOpacity(0.3) : _warningColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: isPaid ? _successColor : _warningColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: _textSecondary),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invoice: ${invoice['invoice_number'] ?? 'N/A'}'),
                            backgroundColor: _primaryColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>> _loadChildInvoices(String token) async {
    try {
      final invoices = await PaymentService.getChildInvoices(token, widget.child.id);
      return invoices.map((invoice) => invoice.toJson()).toList();
    } catch (e) {
      print('❌ Error loading child invoices: $e');
      return [];
    }
  }

  Widget _buildDocumentsTab() {
    final dummyFiles = [
      {'name': 'Diagnosis Report.pdf', 'date': '2025-09-01', 'size': '2.4 MB'},
      {'name': 'Therapy Session Notes.pdf', 'date': '2025-10-01', 'size': '1.8 MB'},
      {'name': 'Medical History.pdf', 'date': '2025-08-15', 'size': '3.1 MB'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dummyFiles.length,
      itemBuilder: (context, idx) {
        final f = dummyFiles[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.insert_drive_file, color: _primaryColor),
              ),
              title: Text(
                f['name']!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${f['date']}', style: TextStyle(color: _textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${f['size']}',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
              trailing: Icon(Icons.download, color: _primaryColor),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloading ${f['name']}'),
                    backgroundColor: _primaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiChatTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AI Daily Tip Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_secondaryColor.withOpacity(0.1), _accentColor.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _secondaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.smart_toy, color: _secondaryColor),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'AI Daily Tip 🧠',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _generateAiTip(),
                    style: TextStyle(fontSize: 16, height: 1.5, color: _textPrimary),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Based on your child\'s condition',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Quick Actions Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.chat,
                        label: 'Ask AI',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Opening AI Chat...'),
                              backgroundColor: _primaryColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.insights,
                        label: 'Progress',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Viewing Progress Insights...'),
                              backgroundColor: _primaryColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor.withOpacity(0.1),
        foregroundColor: _primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  String _generateAiTip() {
    final condition = (widget.child.condition ?? '').toLowerCase();

    if (condition.contains('autism') || condition.contains('asd')) {
      return 'Use short visual schedules with pictures to help your child understand daily routines. This reduces anxiety during transitions between activities.';
    } else if (condition.contains('adhd')) {
      return 'Break tasks into small, manageable steps with immediate rewards. Use timers to help your child understand time concepts and stay focused.';
    } else if (condition.contains('down')) {
      return 'Incorporate music and repetition into learning activities. Celebrate small achievements to build confidence and motivation.';
    } else if (condition.contains('speech')) {
      return 'Practice 5-10 minutes of focused speech exercises daily. Use mirrors to help your child see mouth movements and encourage imitation.';
    } else {
      return 'Maintain a consistent daily routine and track small wins weekly. Visual schedules and positive reinforcement can help build independence.';
    }
  }

  // ========== HELPER FUNCTIONS ==========

  Future<String> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token') ?? '';
    } catch (e) {
      return '';
    }
  }
}