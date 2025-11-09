import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../theme/app_colors.dart';

class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({Key? key}) : super(key: key);

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data storage
  Map<String, dynamic>? adviceData;
  Map<String, dynamic>? dailyTipData;
  Map<String, dynamic>? exerciseData;

  // Loading states
  bool isLoadingAdvice = false;
  bool isLoadingTip = false;
  bool isLoadingExercise = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadAdvice(),
      _loadDailyTip(),
      _loadExercise(),
    ]);
  }

  Future<void> _loadAdvice() async {
    setState(() => isLoadingAdvice = true);
    final result = await AIService.getSpecialistAdvice();
    setState(() {
      adviceData = result['success'] ? result['data'] : null;
      isLoadingAdvice = false;
    });
  }

  Future<void> _loadDailyTip() async {
    setState(() => isLoadingTip = true);
    final result = await AIService.getDailyTip();
    setState(() {
      dailyTipData = result['success'] ? result['data'] : null;
      isLoadingTip = false;
    });
  }

  Future<void> _loadExercise() async {
    setState(() => isLoadingExercise = true);
    final result = await AIService.getSpecializedExercise();
    setState(() {
      exerciseData = result['success'] ? result['data'] : null;
      isLoadingExercise = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'AI Insights',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.lightbulb_outline), text: 'Daily Tip'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Expert Advice'),
            Tab(icon: Icon(Icons.fitness_center), text: 'Exercises'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyTipTab(),
          _buildAdviceTab(),
          _buildExerciseTab(),
        ],
      ),
    );
  }

  // ==================== Daily Tip Tab ====================
  Widget _buildDailyTipTab() {
    if (isLoadingTip) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dailyTipData == null) {
      return _buildErrorState('Failed to load daily tip', _loadDailyTip);
    }

    final tip = dailyTipData!['tip'] ?? 'No tip available';
    final specialization = dailyTipData!['specialization'] ?? 'General';

    return RefreshIndicator(
      onRefresh: _loadDailyTip,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Today\'s Professional Tip',
              Icons.wb_sunny,
              Colors.orange,
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.1), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'For $specialization Specialists',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tip,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildRefreshButton(_loadDailyTip),
          ],
        ),
      ),
    );
  }

  // ==================== Advice Tab ====================
  Widget _buildAdviceTab() {
    if (isLoadingAdvice) {
      return const Center(child: CircularProgressIndicator());
    }

    if (adviceData == null) {
      return _buildErrorState('Failed to load advice', _loadAdvice);
    }

    final advice = List<Map<String, dynamic>>.from(adviceData!['advice'] ?? []);
    final specialist = adviceData!['specialist'] ?? {};

    if (advice.isEmpty) {
      return _buildEmptyState('No advice available');
    }

    return RefreshIndicator(
      onRefresh: _loadAdvice,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: advice.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSectionHeader(
                'Evidence-Based Professional Advice',
                Icons.school,
                AppColors.primary,
              ),
            );
          }

          if (index == advice.length + 1) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildRefreshButton(_loadAdvice),
            );
          }

          final tip = advice[index - 1];
          return _buildAdviceCard(tip, index);
        },
      ),
    );
  }

  Widget _buildAdviceCard(Map<String, dynamic> tip, int index) {
    final title = tip['title'] ?? 'No title';
    final description = tip['description'] ?? 'No description';
    final priority = tip['priority'] ?? 'medium';
    final researchBasis = tip['research_basis'] ?? '';
    final practicalExercise = tip['practical_exercise'] ?? '';

    Color priorityColor;
    IconData priorityIcon;

    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red;
        priorityIcon = Icons.priority_high;
        break;
      case 'low':
        priorityColor = Colors.green;
        priorityIcon = Icons.low_priority;
        break;
      default:
        priorityColor = Colors.orange;
        priorityIcon = Icons.remove;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$index',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Icon(priorityIcon, color: priorityColor, size: 20),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              description,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textDark,
              ),
            ),

            if (researchBasis.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        researchBasis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (practicalExercise.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.play_circle_outline, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Try This:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            practicalExercise,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== Exercise Tab ====================
  Widget _buildExerciseTab() {
    if (isLoadingExercise) {
      return const Center(child: CircularProgressIndicator());
    }

    if (exerciseData == null) {
      return _buildErrorState('Failed to load exercise', _loadExercise);
    }

    final exercise = exerciseData!['exercise'] ?? {};

    if (exercise.isEmpty) {
      return _buildEmptyState('No exercise available');
    }

    return RefreshIndicator(
      onRefresh: _loadExercise,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Therapeutic Exercise',
              Icons.fitness_center,
              Colors.purple,
            ),
            const SizedBox(height: 16),

            _buildExerciseCard(exercise),

            const SizedBox(height: 16),
            _buildRefreshButton(_loadExercise),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise Name
            Text(
              exercise['exercise_name'] ?? 'Exercise',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),

            // Target Skills
            if (exercise['target_skills'] != null) ...[
              _buildExerciseSection(
                'Target Skills',
                Icons.track_changes,
                Colors.blue,
                (exercise['target_skills'] as List).join(', '),
              ),
            ],

            // Age Range
            if (exercise['age_range'] != null) ...[
              _buildExerciseSection(
                'Age Range',
                Icons.child_care,
                Colors.orange,
                exercise['age_range'],
              ),
            ],

            // Duration & Frequency
            Row(
              children: [
                if (exercise['duration'] != null)
                  Expanded(
                    child: _buildInfoChip(
                      Icons.timer,
                      exercise['duration'],
                      Colors.green,
                    ),
                  ),
                const SizedBox(width: 8),
                if (exercise['frequency'] != null)
                  Expanded(
                    child: _buildInfoChip(
                      Icons.repeat,
                      exercise['frequency'],
                      Colors.purple,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Materials Needed
            if (exercise['materials_needed'] != null) ...[
              _buildExerciseSection(
                'Materials Needed',
                Icons.inventory_2,
                Colors.brown,
                (exercise['materials_needed'] as List).join(', '),
              ),
            ],

            // Step by Step
            if (exercise['step_by_step'] != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Step-by-Step Instructions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ...(exercise['step_by_step'] as List).asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],

            // Expected Outcomes
            if (exercise['expected_outcomes'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.check_circle_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Expected Outcomes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise['expected_outcomes'],
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],

            // Research Basis
            if (exercise['research_basis'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        exercise['research_basis'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tips for Success
            if (exercise['tips_for_success'] != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Tips for Success',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ...(exercise['tips_for_success'] as List).map((tip) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tip, style: const TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSection(String title, IconData icon, Color color, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Helper Widgets ====================
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshButton(VoidCallback onPressed) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: const Text('Generate New', style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16, color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}