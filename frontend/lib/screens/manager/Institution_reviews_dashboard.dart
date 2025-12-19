import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/institution_service.dart';

class InstitutionReviewsDashboard extends StatefulWidget {
  @override
  _InstitutionReviewsDashboardState createState() => _InstitutionReviewsDashboardState();
}

class _InstitutionReviewsDashboardState extends State<InstitutionReviewsDashboard> {
  Map<String, dynamic>? _reviewsData;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _selectedTab = 0;
  String _searchQuery = '';
  int _selectedFilter = 0; // 0: All, 1: 5 Stars, 2: 4 Stars, 3: 1-3 Stars

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final reviewsData = await InstitutionService.getInstitutionReviews();
      setState(() {
        _reviewsData = _convertToMap<String, dynamic>(reviewsData);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  // Helper method to convert dynamic maps to typed maps
  Map<K, V> _convertToMap<K, V>(dynamic data) {
    if (data is Map) {
      return Map<K, V>.from(data);
    }
    return <K, V>{};
  }

  List<dynamic> _convertToList(dynamic data) {
    if (data is List) {
      return List<dynamic>.from(data);
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _hasError
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 60,
            ),
            SizedBox(height: 20),
            Text(
              'Failed to load reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final statistics = _convertToMap<String, dynamic>(_reviewsData?['statistics']);
    final performanceSummary = _convertToMap<String, dynamic>(statistics['performance_summary']);
    final aiAnalysis = _convertToMap<String, dynamic>(_reviewsData?['ai_analysis']);

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 50,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              'Review Analytics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadData,
            ),
          ],
        ),

        // Main Content
        SliverToBoxAdapter(
          child: Column(
            children: [
              SizedBox(height: 16),

              // Overview Card
              _buildOverviewCard(statistics),

              SizedBox(height: 16),

              // Tabs
              _buildTabBar(),

              SizedBox(height: 16),

              // Tab Content
              _buildTabContent(statistics, performanceSummary, aiAnalysis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(Map<String, dynamic> statistics) {
    final totalReviews = _parseInt(statistics['total_reviews']);
    final averageRatings = _convertToMap<String, dynamic>(statistics['average_ratings']);
    final overallRating = _parseDouble(averageRatings['overall']);
    final recommendationRate = statistics['recommendation_rate']?.toString() ?? '0%';
    final starDistribution = _convertToMap<String, dynamic>(statistics['star_distribution']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Overall Rating
              Row(
                children: [
                  // Rating Circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            overallRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          RatingBarIndicator(
                            rating: overallRating,
                            itemBuilder: (context, index) => Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            itemCount: 5,
                            itemSize: 14,
                            direction: Axis.horizontal,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Rating',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Based on $totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}',
                          style: TextStyle(
                            color: AppColors.textGray,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatItem(recommendationRate, 'Recommend', AppColors.success),
                            SizedBox(width: 16),
                            _buildStatItem('$totalReviews', 'Reviews', AppColors.info),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Star Distribution
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Star Distribution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  Column(
                    children: [5, 4, 3, 2, 1].map((stars) {
                      final count = _parseInt(starDistribution[stars.toString()]);
                      final percentage = totalReviews > 0 ? (count / totalReviews * 100).round() : 0;
                      return _buildStarDistributionRow(stars, count, percentage);
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textGray,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStarDistributionRow(int stars, int count, int percentage) {
    Color getBarColor(int stars) {
      switch (stars) {
        case 5:
          return AppColors.success;
        case 4:
          return Colors.lightGreen;
        case 3:
          return Colors.amber;
        case 2:
          return Colors.orange;
        case 1:
          return AppColors.error;
        default:
          return AppColors.textGray;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(width: 8),
          Text('$stars', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Icon(Icons.star, color: Colors.amber, size: 16),
          SizedBox(width: 12),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: (percentage / 100) * (MediaQuery.of(context).size.width - 160),
                  decoration: BoxDecoration(
                    color: getBarColor(stars),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Performance', Icons.assessment),
          _buildTabButton(1, 'AI Insights', Icons.psychology),
          _buildTabButton(2, 'Reviews', Icons.reviews),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textGray,
                size: 20,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : AppColors.textGray,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(
      Map<String, dynamic> statistics,
      Map<String, dynamic> performanceSummary,
      Map<String, dynamic> aiAnalysis,
      ) {
    switch (_selectedTab) {
      case 0:
        return _buildPerformanceTab(statistics, performanceSummary);
      case 1:
        return _buildAIAnalysisTab(aiAnalysis);
      case 2:
        return _buildReviewsTab();
      default:
        return Container();
    }
  }

  Widget _buildPerformanceTab(Map<String, dynamic> statistics, Map<String, dynamic> performanceSummary) {
    final averageRatings = _convertToMap<String, dynamic>(statistics['average_ratings']);
    final strengths = _convertToList(performanceSummary['strength']);
    final good = _convertToList(performanceSummary['good']);
    final needImprove = _convertToList(performanceSummary['need_improve']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Category Ratings
          _buildSectionCard(
            'Category Ratings',
            Icons.bar_chart,
            Column(
              children: [
                _buildCategoryRating('Staff & Service', _parseDouble(averageRatings['staff'])),
                _buildCategoryRating('Facilities & Equipment', _parseDouble(averageRatings['facilities'])),
                _buildCategoryRating('Cleanliness & Hygiene', _parseDouble(averageRatings['cleanliness'])),
                _buildCategoryRating('Accessibility & Location', _parseDouble(averageRatings['accessibility'])),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Performance Summary
          if (strengths.isNotEmpty || good.isNotEmpty || needImprove.isNotEmpty)
            _buildSectionCard(
              'Performance Summary',
              Icons.insights,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Strengths
                  if (strengths.isNotEmpty) ...[
                    _buildPerformanceSection('Strengths', strengths, AppColors.success, Icons.thumb_up),
                    if (good.isNotEmpty || needImprove.isNotEmpty) SizedBox(height: 16),
                  ],

                  // Good Areas
                  if (good.isNotEmpty) ...[
                    _buildPerformanceSection('Good Areas', good, AppColors.warning, Icons.check_circle),
                    if (needImprove.isNotEmpty) SizedBox(height: 16),
                  ],

                  // Areas Needing Improvement
                  if (needImprove.isNotEmpty)
                    _buildPerformanceSection('Need Improvement', needImprove, AppColors.error, Icons.warning),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryRating(String category, double rating) {
    Color getRatingColor(double rating) {
      if (rating >= 4.0) return AppColors.success;
      if (rating >= 3.0) return Colors.orange;
      return AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category,
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: 12),
          RatingBarIndicator(
            rating: rating,
            itemBuilder: (context, index) => Icon(
              Icons.star,
              color: getRatingColor(rating),
            ),
            itemCount: 5,
            itemSize: 18,
            direction: Axis.horizontal,
          ),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: getRatingColor(rating).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: getRatingColor(rating),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection(
      String title,
      List<dynamic> items,
      Color color,
      IconData icon,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Column(
          children: items.map<Widget>((item) {
            final itemMap = _convertToMap<String, dynamic>(item);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(width: 28),
                  Expanded(
                    child: Text(
                      itemMap['label']?.toString() ?? '',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${itemMap['score']?.toString() ?? "0.0"}/5',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAIAnalysisTab(Map<String, dynamic> aiAnalysis) {
    final summary = aiAnalysis['summary']?.toString() ?? '';
    final whatToMaintain = _convertToList(aiAnalysis['what_to_maintain']);
    final whatToImprove = _convertToList(aiAnalysis['what_to_improve']);
    final urgentActions = _convertToList(aiAnalysis['urgent_actions']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Summary
          if (summary.isNotEmpty)
            _buildSectionCard(
              'AI Summary',
              Icons.summarize,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Text(
                      summary,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (summary.isNotEmpty) SizedBox(height: 16),

          // What to Maintain
          if (whatToMaintain.isNotEmpty)
            _buildSectionCard(
              'What to Maintain',
              Icons.thumb_up,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: whatToMaintain
                        .map<Widget>((item) => _buildPill(item.toString(), AppColors.success))
                        .toList(),
                  ),
                ],
              ),
            ),

          if (whatToMaintain.isNotEmpty) SizedBox(height: 16),

          // What to Improve
          if (whatToImprove.isNotEmpty)
            _buildSectionCard(
              'What to Improve',
              Icons.thumb_down,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: whatToImprove
                        .map<Widget>((item) => _buildPill(item.toString(), AppColors.warning))
                        .toList(),
                  ),
                ],
              ),
            ),

          if (whatToImprove.isNotEmpty) SizedBox(height: 16),

          // Urgent Actions
          if (urgentActions.isNotEmpty)
            _buildSectionCard(
              'Urgent Actions',
              Icons.warning,
              Column(
                children: urgentActions.map<Widget>((action) {
                  final actionMap = _convertToMap<String, dynamic>(action);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildActionItem(actionMap),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            color == AppColors.success ? Icons.check_circle : Icons.info,
            color: color,
            size: 14,
          ),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(Map<String, dynamic> action) {
    final priority = action['priority']?.toString() ?? '';
    Color getPriorityColor(String priority) {
      switch (priority.toLowerCase()) {
        case 'high':
          return AppColors.error;
        case 'medium':
          return Colors.orange;
        default:
          return AppColors.warning;
      }
    }

    final color = getPriorityColor(priority);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  action['category']?.toString() ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Problem: ${action['problem'] ?? ''}',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Action: ${action['action'] ?? ''}',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    final allReviews = _convertToList(_reviewsData?['all_reviews']);

    // Filter reviews based on search and filter
    List<dynamic> filteredReviews = allReviews.where((review) {
      final reviewMap = _convertToMap<String, dynamic>(review);
      final ratings = _convertToMap<String, dynamic>(reviewMap['ratings']);
      final overallRating = _parseDouble(ratings['overall']);
      final reviewText = reviewMap['review_text']?.toString().toLowerCase() ?? '';
      final parent = _convertToMap<String, dynamic>(reviewMap['parent']);
      final parentName = parent['full_name']?.toString().toLowerCase() ?? '';

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        if (!reviewText.contains(_searchQuery.toLowerCase()) &&
            !parentName.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // Apply star filter
      switch (_selectedFilter) {
        case 1: // 5 Stars
          return overallRating >= 4.5;
        case 2: // 4 Stars
          return overallRating >= 3.5 && overallRating < 4.5;
        case 3: // 1-3 Stars
          return overallRating < 3.5;
        default: // All
          return true;
      }
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Review Filters
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by review or parent name...',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: AppColors.textGray),
                    hintStyle: TextStyle(color: AppColors.textLight),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                SizedBox(height: 8),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(0, 'All Reviews'),
                      SizedBox(width: 8),
                      _buildFilterChip(1, '5 Stars'),
                      SizedBox(width: 8),
                      _buildFilterChip(2, '4 Stars'),
                      SizedBox(width: 8),
                      _buildFilterChip(3, '1-3 Stars'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Review Count
          Row(
            children: [
              Text(
                '${filteredReviews.length} ${filteredReviews.length == 1 ? 'Review' : 'Reviews'}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  fontSize: 16,
                ),
              ),
              Spacer(),
              if (_searchQuery.isNotEmpty || _selectedFilter != 0)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedFilter = 0;
                    });
                  },
                  child: Text(
                    'Clear filters',
                    style: TextStyle(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 12),

          // Reviews List
          if (filteredReviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    color: AppColors.textLight,
                    size: 60,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty || _selectedFilter != 0
                        ? 'No reviews match your search'
                        : 'No reviews yet',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: filteredReviews.map<Widget>((review) {
                final reviewMap = _convertToMap<String, dynamic>(review);
                return _buildReviewCard(reviewMap);
              }).toList(),
            ),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int value, String label) {
    bool isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 0;
        });
      },
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textGray,
      ),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final parent = _convertToMap<String, dynamic>(review['parent']);
    final ratings = _convertToMap<String, dynamic>(review['ratings']);
    final overallRating = _parseDouble(ratings['overall']);
    final reviewText = review['review_text']?.toString() ?? '';
    final createdAt = review['created_at']?.toString() ?? '';
    //final wouldRecommend = review['would_recommend'] ?? false;
    final basedOnVisits = _parseInt(review['based_on_visits']);

    String getVisitText(int visits) {
      return '$visits ${visits == 1 ? 'visit' : 'visits'}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: parent['profile_picture']?.toString().isNotEmpty == true
                        ? NetworkImage(parent['profile_picture'].toString())
                        : null,
                    child: parent['profile_picture']?.toString().isNotEmpty != true
                        ? Text(
                      parent['full_name']?.toString().substring(0, 1).toUpperCase() ?? 'A',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parent['full_name']?.toString() ?? 'Anonymous',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${_formatDate(createdAt)} • ${getVisitText(basedOnVisits)}',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Rating
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRatingColor(overallRating).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          overallRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getRatingColor(overallRating),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.star, color: _getRatingColor(overallRating), size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Review Text
              Text(
                reviewText,
                style: TextStyle(
                  color: AppColors.textGray,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12),

              // Category Ratings
              _buildCategoryRatings(ratings),
              SizedBox(height: 12),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRatings(Map<String, dynamic> ratings) {
    final categories = [
      {'key': 'staff', 'label': 'Staff'},
      {'key': 'facilities', 'label': 'Facilities'},
      {'key': 'cleanliness', 'label': 'Cleanliness'},
      {'key': 'accessibility', 'label': 'Accessibility'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map<Widget>((category) {
        final rating = _parseDouble(ratings[category['key']]);
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category['label']!,
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.star, color: Colors.amber, size: 12),
              Text(
                rating.toStringAsFixed(0),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return AppColors.success;
    if (rating >= 3.0) return Colors.orange;
    return AppColors.error;
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
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      } else {
        return DateFormat('MMM d, yyyy').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildSectionCard(String title, IconData icon, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }
}