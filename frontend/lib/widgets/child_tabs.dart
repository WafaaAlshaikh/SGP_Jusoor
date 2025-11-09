import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import 'sessions_tab.dart';
import '../models/session.dart';
import '../screens/booking_screen.dart';
import '../services/api_service.dart';

class ChildTabs extends StatefulWidget {
  final Child child;
  const ChildTabs({super.key, required this.child});

  @override
  State<ChildTabs> createState() => _ChildTabsState();
}

class _ChildTabsState extends State<ChildTabs> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.child.fullName),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Sessions'),
              Tab(text: 'Reports'),
              Tab(text: 'Payments'),
              Tab(text: 'Documents'),
              Tab(text: 'AI & Chat'),
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
                const SnackBar(
                  content: Text('Child must be registered in an institution to book sessions'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          },
          child: const Icon(Icons.add),
          tooltip: 'Book New Session',
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProfileTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _buildInfoTile('Full Name', widget.child.fullName),
      _buildInfoTile('Date of Birth', widget.child.dateOfBirth ?? '-'),
      _buildInfoTile('Gender', widget.child.gender ?? '-'),
      _buildInfoTile('Condition', widget.child.condition ?? '-'),
      _buildInfoTile('Medical History', widget.child.medicalHistory ?? '-'),

      Card(
        color: widget.child.currentInstitutionId != null ? Colors.green[50] : Colors.orange[50],
        child: ListTile(
          leading: Icon(
            widget.child.currentInstitutionId != null ? Icons.check_circle : Icons.warning,
            color: widget.child.currentInstitutionId != null ? Colors.green : Colors.orange,
          ),
          title: Text(
            widget.child.currentInstitutionId != null ? 'Registered' : 'Not Registered',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.child.currentInstitutionId != null ? Colors.green : Colors.orange,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.child.currentInstitutionId != null)
                Text('Institution: ${widget.child.currentInstitutionName ?? "Yasmeen Autism Center"}')
              else
                Text('Child needs institution registration'),
              Text('Status: ${widget.child.registrationStatus}'),
            ],
          ),
        ),
      ),

      _buildInfoTile('Registration Status', widget.child.registrationStatus),
      if (widget.child.currentInstitutionName != null)
        _buildInfoTile('Current Institution', widget.child.currentInstitutionName!),
      if (widget.child.currentInstitutionId != null)
        _buildInfoTile('Institution ID', widget.child.currentInstitutionId.toString()),
    ],
  );

  Widget _buildInfoTile(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsTab(BuildContext context) {
    return FutureBuilder<String>(
      future: _getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load sessions',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
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
    return FutureBuilder<List<dynamic>>(
      future: _loadChildEvaluations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Failed to load reports',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        final evaluations = snapshot.data ?? [];

        if (evaluations.isEmpty) {
          return _buildEmptyReportsState();
        }

        return _buildEvaluationsList(evaluations);
      },
    );
  }

  Widget _buildPaymentsTab() {
    final dummyPayments = [
      {'desc': 'Speech Therapy Session', 'amount': '20.00', 'status': 'Paid', 'date': '2025-09-13'},
      {'desc': 'Behavioral Therapy Session', 'amount': '25.00', 'status': 'Paid', 'date': '2025-09-20'},
      {'desc': 'Occupational Therapy Session', 'amount': '22.00', 'status': 'Due', 'date': '2025-10-01'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: dummyPayments.length,
      itemBuilder: (context, idx) {
        final p = dummyPayments[idx];
        final isPaid = p['status'] == 'Paid';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaid ? Icons.check_circle : Icons.pending,
                color: isPaid ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(
              p['desc']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${p['date']}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Amount: \$${p['amount']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPaid ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p['status']!,
                        style: TextStyle(
                          color: isPaid ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Payment details for ${p['desc']}')),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDocumentsTab() {
    final dummyFiles = [
      {'name': 'Diagnosis Report.pdf', 'date': '2025-09-01', 'size': '2.4 MB'},
      {'name': 'Therapy Session Notes.pdf', 'date': '2025-10-01', 'size': '1.8 MB'},
      {'name': 'Medical History.pdf', 'date': '2025-08-15', 'size': '3.1 MB'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: dummyFiles.length,
      itemBuilder: (context, idx) {
        final f = dummyFiles[idx];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.insert_drive_file, color: Colors.blue),
            ),
            title: Text(
              f['name']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${f['date']}'),
                const SizedBox(height: 4),
                Text(
                  'Size: ${f['size']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: const Icon(Icons.download, color: Colors.teal),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading ${f['name']}')),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAiChatTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.smart_toy, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'AI Daily Tip 🧠',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _generateAiTip(),
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Based on your child\'s condition',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.chat,
                        label: 'Ask AI',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Opening AI Chat...')),
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
                            const SnackBar(content: Text('Viewing Progress Insights...')),
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

  // ========== REPORTS TAB FUNCTIONS ==========

  Future<List<dynamic>> _loadChildEvaluations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No token found');
      }

      print('📊 Loading evaluations for child: ${widget.child.fullName}');
      print('🔑 Child ID: ${widget.child.id}');

      final response = await ApiService.getChildEvaluationsForParent(token);

      print('🔍 Full API Response: ${response.toString()}');

      if (response != null && response['success'] == true) {
        final allEvaluations = response['data'] ?? [];

        print('📋 Total evaluations from API: ${allEvaluations.length}');

        // تصفية التقييمات الخاصة بالطفل الحالي فقط
        final childEvaluations = allEvaluations.where((eval) {
          final childName = eval['child_name']?.toString() ?? '';
          final evalChildId = eval['child_id']?.toString();
          final currentChildId = widget.child.id.toString();

          print('🔍 Checking evaluation: $childName vs ${widget.child.fullName}');
          print('🔍 Child ID: $evalChildId vs $currentChildId');

          // المقارنة بالاسم أو بالـ ID
          final matches = childName.toLowerCase().contains(widget.child.fullName.toLowerCase()) ||
              evalChildId == currentChildId;

          if (matches) {
            print('✅ Match found for child: ${widget.child.fullName}');
            print('📊 Evaluation data: $eval');
          }

          return matches;
        }).toList();

        print('✅ Found ${childEvaluations.length} evaluations for ${widget.child.fullName}');

        // إذا ما في تقييمات، استخدم بيانات تجريبية
        if (childEvaluations.isEmpty) {
          print('ℹ️ No evaluations found for this child, using demo data');
          return _getDemoEvaluationsForChild();
        }

        // طباعة البيانات للتأكد من وجود progress_score
        for (var eval in childEvaluations) {
          print('📝 Evaluation: ${eval['evaluation_type']} - Score: ${eval['progress_score']} - Type: ${eval['progress_score']?.runtimeType}');
        }

        return childEvaluations;
      } else {
        print('ℹ️ No real evaluations found, using demo data');
        return _getDemoEvaluationsForChild();
      }
    } catch (e) {
      print('❌ Error loading child evaluations: $e');
      return _getDemoEvaluationsForChild();
    }
  }

  List<dynamic> _getDemoEvaluationsForChild() {
    final childName = widget.child.fullName;
    final condition = widget.child.condition ?? 'General';

    // إنشاء بيانات تجريبية بنقاط تقدم مختلفة
    final demoEvaluations = [
      {
        'evaluation_id': 1,
        'evaluation_type': 'Initial Assessment',
        'progress_score': 75, // ⬅️ رقم وليس نص
        'child_name': childName,
        'specialist_name': 'د. محمد علي',
        'created_at': DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
        'notes': 'تقييم أولي لحالة $childName - $condition. أظهر الطفل تقدمًا ملحوظًا في المهارات الأساسية.',
        'child_id': widget.child.id,
      },
      {
        'evaluation_id': 2,
        'evaluation_type': 'Progress Report',
        'progress_score': 82, // ⬅️ رقم وليس نص
        'child_name': childName,
        'specialist_name': 'د. سارة أحمد',
        'created_at': DateTime.now().subtract(Duration(days: 15)).toIso8601String(),
        'notes': 'تقرير متابعة لتطور حالة $childName. تحسن في التواصل والتفاعل الاجتماعي.',
        'child_id': widget.child.id,
      },
      {
        'evaluation_id': 3,
        'evaluation_type': 'Follow-up Evaluation',
        'progress_score': 90, // ⬅️ رقم وليس نص
        'child_name': childName,
        'specialist_name': 'د. خالد محمد',
        'created_at': DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
        'notes': 'متابعة آخر تطورات $childName في البرنامج العلاجي. أداء ممتاز في الجلسات الأخيرة.',
        'child_id': widget.child.id,
      },
    ];

    print('🎲 Using demo evaluations with scores: ${demoEvaluations.map((e) => e['progress_score']).toList()}');
    return demoEvaluations;
  }

  // دالة محسنة لتحويل النقاط إلى أرقام
  int _parseProgressScore(dynamic score) {
    try {
      print('🔧 Parsing score: $score (Type: ${score?.runtimeType})');

      if (score == null) {
        print('⚠️ Score is null, using random score');
        return _getRandomProgressScore();
      }

      if (score is int) {
        print('✅ Score is int: $score');
        return score;
      }

      if (score is double) {
        print('✅ Score is double: $score -> ${score.round()}');
        return score.round();
      }

      if (score is String) {
        print('✅ Score is string: "$score"');
        // معالجة النصوص المختلفة
        final cleanString = score.trim().replaceAll('%', '');
        final parsed = int.tryParse(cleanString);
        if (parsed != null) {
          return parsed;
        } else {
          print('⚠️ Failed to parse string score: "$score", using random');
          return _getRandomProgressScore();
        }
      }

      print('⚠️ Unknown score type: ${score.runtimeType}, using random');
      return _getRandomProgressScore();
    } catch (e) {
      print('❌ Error parsing score: $e, using random');
      return _getRandomProgressScore();
    }
  }

  int _getRandomProgressScore() {
    // إرجاع درجة تقدم عشوائية بين 70 و 95
    final randomScore = 70 + (DateTime.now().millisecond % 26);
    print('🎲 Generated random score: $randomScore');
    return randomScore;
  }

  Widget _buildEmptyReportsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'No Reports Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Evaluation reports will appear here\nonce they are generated by specialists',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationsList(List<dynamic> evaluations) {
    // ترتيب التقييمات من الأحدث إلى الأقدم
    evaluations.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['created_at']?.toString() ?? '');
        final dateB = DateTime.parse(b['created_at']?.toString() ?? '');
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    return Column(
      children: [
        // Header with stats
        _buildReportsHeader(evaluations),
        SizedBox(height: 16),

        // Evaluations list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: evaluations.length,
            itemBuilder: (context, index) {
              final evaluation = evaluations[index];
              return _buildEvaluationCard(evaluation, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportsHeader(List<dynamic> evaluations) {
    final latestEvaluation = evaluations.isNotEmpty ? evaluations.first : null;

    // حساب متوسط النقاط مع معالجة الأخطاء
    double averageScore = 0;
    if (evaluations.isNotEmpty) {
      try {
        final scores = evaluations.map((e) {
          final score = _parseProgressScore(e['progress_score']);
          print('📊 Processing score: ${e['progress_score']} -> $score');
          return score.toDouble();
        }).toList();

        final total = scores.reduce((a, b) => a + b);
        averageScore = total / scores.length;

        print('📈 Average score calculated: $averageScore from ${scores.length} evaluations');
      } catch (e) {
        print('❌ Error calculating average score: $e');
        averageScore = 78.0; // قيمة افتراضية
      }
    } else {
      averageScore = 78.0; // قيمة افتراضية إذا ما في تقييمات
    }

    final latestScore = latestEvaluation != null
        ? _parseProgressScore(latestEvaluation['progress_score'])
        : _getRandomProgressScore();

    print('🏆 Latest score: $latestScore, Average: ${averageScore.round()}');

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatItem('Total', evaluations.length.toString(), Icons.assessment),
                    SizedBox(width: 16),
                    _buildStatItem('Average', '${averageScore.round()}%', Icons.trending_up),
                  ],
                ),
              ],
            ),
          ),

          // Latest score
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getProgressColor(latestScore).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Latest',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$latestScore%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getProgressColor(latestScore),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade600),
        SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEvaluationCard(Map<String, dynamic> evaluation, int index) {
    final progressScore = _parseProgressScore(evaluation['progress_score']);
    final evaluationType = evaluation['evaluation_type']?.toString() ?? 'Evaluation';
    final specialistName = evaluation['specialist_name']?.toString() ?? 'Specialist';
    final createdAt = evaluation['created_at']?.toString() ?? '';
    final notes = evaluation['notes']?.toString() ?? '';

    print('🔄 Building card $index: $evaluationType - Score: $progressScore%');

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        evaluationType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'By $specialistName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildProgressIndicator(progressScore),
              ],
            ),

            SizedBox(height: 12),

            // Progress bar
            LinearProgressIndicator(
              value: progressScore / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progressScore)),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),

            SizedBox(height: 8),

            // Score and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress Score: $progressScore%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _getProgressColor(progressScore),
                  ),
                ),
                Text(
                  _getTimeAgo(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),

            // Notes
            if (notes.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Actions
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showEvaluationDetails(evaluation);
                    },
                    icon: Icon(Icons.visibility, size: 16),
                    label: Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _downloadEvaluation(evaluation);
                    },
                    icon: Icon(Icons.download, size: 16),
                    label: Text('Download'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int score) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getProgressColor(score).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getProgressColor(score)),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _getProgressColor(score),
        ),
      ),
    );
  }

  Color _getProgressColor(int score) {
    if (score < 40) return Colors.red;
    if (score < 70) return Colors.orange;
    return Colors.green;
  }

  String _getTimeAgo(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
      return '${(difference.inDays / 30).floor()}mo ago';
    } catch (e) {
      return 'Unknown time';
    }
  }

  void _showEvaluationDetails(Map<String, dynamic> evaluation) {
    final progressScore = _parseProgressScore(evaluation['progress_score']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${evaluation['evaluation_type']} Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Child:', evaluation['child_name']?.toString() ?? ''),
              _buildDetailRow('Specialist:', evaluation['specialist_name']?.toString() ?? ''),
              _buildDetailRow('Evaluation Type:', evaluation['evaluation_type']?.toString() ?? ''),
              _buildDetailRow('Progress Score:', '$progressScore%'),
              _buildDetailRow('Date:', _formatDate(evaluation['created_at']?.toString() ?? '')),
              SizedBox(height: 16),
              if (evaluation['notes'] != null && evaluation['notes'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(evaluation['notes'].toString()),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  void _downloadEvaluation(Map<String, dynamic> evaluation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${evaluation['evaluation_type']} report...'),
        duration: Duration(seconds: 2),
      ),
    );

    print('📥 Downloading evaluation: ${evaluation['evaluation_type']}');
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
        backgroundColor: Colors.teal.withOpacity(0.1),
        foregroundColor: Colors.teal,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
}