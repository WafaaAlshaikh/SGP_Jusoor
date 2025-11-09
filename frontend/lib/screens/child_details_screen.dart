// lib/screens/child_details_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/specialist_children_service.dart';

class ChildDetailsScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ChildDetailsScreen({
    Key? key,
    required this.childId,
    required this.childName,
  }) : super(key: key);

  @override
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen> {
  Map<String, dynamic>? childData;
  bool isLoading = true;
  String errorMessage = '';

  // Comparison System State
  List<dynamic> _selectedEvaluationsForComparison = [];
  bool _comparisonMode = false;
  Map<String, dynamic>? _comparisonResults;
  DateTime? _startDate;
  DateTime? _endDate;
  String _comparisonType = 'select_manually';
  List<dynamic> _allEvaluationsInPeriod = [];

  @override
  void initState() {
    super.initState();
    _loadChildDetails();
  }

  Future<void> _loadChildDetails() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final response = await SpecialistChildrenService.getChildDetails(widget.childId);

      if (response['success'] == true) {
        setState(() {
          childData = response['data'];
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load child details';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Helper Functions
  List<dynamic> _safeList(dynamic list) => list is List ? list : [];
  Map<String, dynamic> _safeMap(dynamic map) => map is Map<String, dynamic> ? map : {};
  String _safeString(dynamic value) => value?.toString() ?? '';

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatDate(String date) {
    try {
      if (date.isEmpty) return date;
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  // ========== COMPARISON SYSTEM ==========

  void _startComparison(String type) {
    setState(() {
      _comparisonMode = true;
      _comparisonType = type;
      _selectedEvaluationsForComparison.clear();
      _comparisonResults = null;
      _allEvaluationsInPeriod.clear();

      // Set date ranges for automatic comparisons
      final now = DateTime.now();
      switch (type) {
        case 'last_month':
          _startDate = DateTime(now.year, now.month - 1, 1);
          _endDate = DateTime(now.year, now.month, 0);
          break;
        case 'last_3_months':
          _startDate = DateTime(now.year, now.month - 3, 1);
          _endDate = now;
          break;
        case 'date_range':
        // Will be set by date picker
          break;
      }
    });

    if (type != 'select_manually') {
      _performAutoComparison();
    }
  }

  void _performAutoComparison() {
    final evaluations = _safeList(childData?['evaluations']);
    if (evaluations.isEmpty) return;

    List<dynamic> filteredEvaluations = [];

    switch (_comparisonType) {
      case 'last_month':
      case 'last_3_months':
      case 'date_range':
        if (_startDate != null && _endDate != null) {
          filteredEvaluations = evaluations.where((eval) {
            try {
              final evalDate = DateTime.parse(_safeString(eval['created_at']));
              return evalDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
                  evalDate.isBefore(_endDate!.add(Duration(days: 1)));
            } catch (e) {
              return false;
            }
          }).toList();
        }
        break;
      case 'select_manually':
        return;
    }

    if (filteredEvaluations.length >= 2) {
      // Sort evaluations chronologically
      filteredEvaluations.sort((a, b) {
        try {
          final dateA = DateTime.parse(_safeString(a['created_at']));
          final dateB = DateTime.parse(_safeString(b['created_at']));
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _selectedEvaluationsForComparison = [
          filteredEvaluations.first,
          filteredEvaluations.last
        ];
        _allEvaluationsInPeriod = filteredEvaluations;
      });

      _performComprehensiveComparison();
    }
  }

  void _toggleEvaluationSelection(dynamic evaluation) {
    setState(() {
      if (_selectedEvaluationsForComparison.contains(evaluation)) {
        _selectedEvaluationsForComparison.remove(evaluation);
      } else {
        if (_selectedEvaluationsForComparison.length < 2) {
          _selectedEvaluationsForComparison.add(evaluation);
        }
      }

      // Auto-compare when 2 evaluations are selected
      if (_selectedEvaluationsForComparison.length == 2) {
        _performComprehensiveComparison();
      } else {
        _comparisonResults = null;
      }
    });
  }

  void _performComprehensiveComparison() {
    if (_selectedEvaluationsForComparison.length != 2) return;

    // Sort evaluations chronologically
    final sortedEvaluations = List.from(_selectedEvaluationsForComparison)
      ..sort((a, b) {
        try {
          final dateA = DateTime.parse(_safeString(a['created_at']));
          final dateB = DateTime.parse(_safeString(b['created_at']));
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });

    final firstEval = _safeMap(sortedEvaluations[0]);
    final secondEval = _safeMap(sortedEvaluations[1]);

    final comparison = _createComprehensiveComparisonReport(firstEval, secondEval);
    setState(() {
      _comparisonResults = comparison;
    });
  }

  Map<String, dynamic> _createComprehensiveComparisonReport(
      Map<String, dynamic> firstEval,
      Map<String, dynamic> secondEval
      ) {
    // Basic score analysis
    final firstScore = _safeDouble(firstEval['progress_score']) ?? 0.0;
    final secondScore = _safeDouble(secondEval['progress_score']) ?? 0.0;
    final scoreDifference = secondScore - firstScore;
    final percentageChange = firstScore > 0 ? (scoreDifference / firstScore) * 100 : 0.0;

    // Date and period analysis
    final firstDate = DateTime.parse(_safeString(firstEval['created_at']));
    final secondDate = DateTime.parse(_safeString(secondEval['created_at']));
    final daysBetween = secondDate.difference(firstDate).inDays;
    final monthsBetween = daysBetween / 30.0;

    // Comprehensive analyses
    final domainAnalysis = _analyzeDomainsComprehensively(firstEval, secondEval);
    final progressMetrics = _calculateProgressMetrics(firstScore, secondScore, daysBetween);
    final overallAssessment = _createOverallAssessment(
        scoreDifference,
        domainAnalysis,
        progressMetrics,
        daysBetween
    );
    final periodAnalysis = _analyzeAllEvaluationsInPeriod(_allEvaluationsInPeriod);
    final recommendations = _generateComprehensiveRecommendations(
        overallAssessment,
        domainAnalysis,
        progressMetrics
    );

    return {
      // Basic Information
      'firstEvaluation': firstEval,
      'secondEvaluation': secondEval,
      'firstDate': _formatDate(firstDate.toString()),
      'secondDate': _formatDate(secondDate.toString()),
      'period': '$daysBetween days (${monthsBetween.toStringAsFixed(1)} months)',

      // Score Analysis
      'scoreAnalysis': {
        'firstScore': firstScore,
        'secondScore': secondScore,
        'absoluteChange': scoreDifference,
        'percentageChange': percentageChange,
        'monthlyRate': progressMetrics['monthlyImprovementRate'],
        'weeklyRate': progressMetrics['weeklyImprovementRate'],
      },

      // Domain Analysis
      'domainAnalysis': domainAnalysis,

      // Progress Metrics
      'progressMetrics': progressMetrics,

      // Overall Assessment
      'overallAssessment': overallAssessment,

      // Period Analysis
      'periodAnalysis': periodAnalysis,

      // Recommendations
      'recommendations': recommendations,

      // Detailed Insights
      'detailedInsights': _generateDetailedInsights(domainAnalysis, progressMetrics),

      // Additional Data
      'allEvaluationsCount': _allEvaluationsInPeriod.length,
      'evaluationsInPeriod': _allEvaluationsInPeriod,
    };
  }

  // ========== ANALYSIS METHODS ==========

  Map<String, dynamic> _analyzeDomainsComprehensively(
      Map<String, dynamic> firstEval,
      Map<String, dynamic> secondEval
      ) {
    final firstDomains = _safeList(firstEval['assessment_domains'] ?? firstEval['domains']);
    final secondDomains = _safeList(secondEval['assessment_domains'] ?? secondEval['domains']);

    // ✅ تحقق إذا ما في domains نهائياً
    if (firstDomains.isEmpty && secondDomains.isEmpty) {
      return _createFallbackDomainAnalysis(firstEval, secondEval);
    }

    final domainChanges = <Map<String, dynamic>>[];
    final improvedDomains = <Map<String, dynamic>>[];
    final declinedDomains = <Map<String, dynamic>>[];
    final stableDomains = <Map<String, dynamic>>[];
    final newDomains = <Map<String, dynamic>>[];
    final removedDomains = <Map<String, dynamic>>[];

    // Create domain maps for easy lookup
    final firstDomainMap = <String, Map<String, dynamic>>{};
    final secondDomainMap = <String, Map<String, dynamic>>{};

    for (final domain in firstDomains) {
      final domainMap = _safeMap(domain);
      final domainName = _safeString(domainMap['name'] ?? domainMap['domain_name'] ?? domainMap['title']);
      if (domainName.isNotEmpty) {
        firstDomainMap[domainName] = domainMap;
      }
    }

    for (final domain in secondDomains) {
      final domainMap = _safeMap(domain);
      final domainName = _safeString(domainMap['name'] ?? domainMap['domain_name'] ?? domainMap['title']);
      if (domainName.isNotEmpty) {
        secondDomainMap[domainName] = domainMap;
      }
    }

    // Compare domains that exist in both evaluations
    for (final entry in firstDomainMap.entries) {
      final domainName = entry.key;
      final firstDomain = entry.value;
      final secondDomain = secondDomainMap[domainName];

      if (secondDomain != null) {
        final firstScore = _safeDouble(firstDomain['score'] ?? firstDomain['progress_score']) ?? 0.0;
        final secondScore = _safeDouble(secondDomain['score'] ?? secondDomain['progress_score']) ?? 0.0;
        final difference = secondScore - firstScore;
        final percentageChange = firstScore > 0 ? (difference / firstScore) * 100 : 0.0;

        final domainData = {
          'name': domainName,
          'firstScore': firstScore,
          'secondScore': secondScore,
          'difference': difference,
          'percentageChange': percentageChange,
          'trend': _getDomainTrend(difference),
          'significance': _getChangeSignificance(difference.abs()),
        };

        domainChanges.add(domainData);

        // Categorize domains
        if (difference > 5) {
          improvedDomains.add(domainData);
        } else if (difference < -5) {
          declinedDomains.add(domainData);
        } else {
          stableDomains.add(domainData);
        }
      } else {
        // Domain removed in second evaluation
        removedDomains.add({
          'name': domainName,
          'score': _safeDouble(firstDomain['score'] ?? firstDomain['progress_score']) ?? 0.0,
        });
      }
    }

    // Find new domains in second evaluation
    for (final entry in secondDomainMap.entries) {
      if (!firstDomainMap.containsKey(entry.key)) {
        newDomains.add({
          'name': entry.key,
          'score': _safeDouble(entry.value['score'] ?? entry.value['progress_score']) ?? 0.0,
        });
      }
    }

    // Calculate statistics
    final totalDomains = domainChanges.length;
    final improvementRate = totalDomains > 0 ? (improvedDomains.length / totalDomains) * 100 : 0;
    final declineRate = totalDomains > 0 ? (declinedDomains.length / totalDomains) * 100 : 0;
    final stabilityRate = totalDomains > 0 ? (stableDomains.length / totalDomains) * 100 : 0;

    return {
      'domainChanges': domainChanges,
      'improvedDomains': improvedDomains,
      'declinedDomains': declinedDomains,
      'stableDomains': stableDomains,
      'newDomains': newDomains,
      'removedDomains': removedDomains,
      'statistics': {
        'totalDomains': totalDomains,
        'improvementRate': improvementRate,
        'declineRate': declineRate,
        'stabilityRate': stabilityRate,
        'improvedCount': improvedDomains.length,
        'declinedCount': declinedDomains.length,
        'stableCount': stableDomains.length,
        'newCount': newDomains.length,
        'removedCount': removedDomains.length,
      },
      'keyInsights': _generateDomainInsights(improvedDomains, declinedDomains, newDomains),
    };
  }

// ✅ دالة بديلة لما ما في domains
  Map<String, dynamic> _createFallbackDomainAnalysis(
      Map<String, dynamic> firstEval,
      Map<String, dynamic> secondEval
      ) {
    final firstScore = _safeDouble(firstEval['progress_score']) ?? 0.0;
    final secondScore = _safeDouble(secondEval['progress_score']) ?? 0.0;
    final scoreDifference = secondScore - firstScore;

    // أنشئ domains افتراضية
    final defaultDomain = {
      'name': 'Overall Progress',
      'firstScore': firstScore,
      'secondScore': secondScore,
      'difference': scoreDifference,
      'percentageChange': firstScore > 0 ? (scoreDifference / firstScore) * 100 : 0.0,
      'trend': _getDomainTrend(scoreDifference),
      'significance': _getChangeSignificance(scoreDifference.abs()),
    };

    final defaultDomains = [defaultDomain];

    // صنّف الـ domain
    final improvedDomains = scoreDifference > 5 ? defaultDomains : [];
    final declinedDomains = scoreDifference < -5 ? defaultDomains : [];
    final stableDomains = scoreDifference.abs() <= 5 ? defaultDomains : [];

    return {
      'domainChanges': defaultDomains,
      'improvedDomains': improvedDomains,
      'declinedDomains': declinedDomains,
      'stableDomains': stableDomains,
      'newDomains': [],
      'removedDomains': [],
      'statistics': {
        'totalDomains': 1,
        'improvementRate': improvedDomains.isNotEmpty ? 100 : 0,
        'declineRate': declinedDomains.isNotEmpty ? 100 : 0,
        'stabilityRate': stableDomains.isNotEmpty ? 100 : 0,
        'improvedCount': improvedDomains.length,
        'declinedCount': declinedDomains.length,
        'stableCount': stableDomains.length,
        'newCount': 0,
        'removedCount': 0,
      },
      'keyInsights': _generateDomainInsights(improvedDomains, declinedDomains, []),
    };
  }

  Map<String, dynamic> _analyzeAllEvaluationsInPeriod(List<dynamic> evaluations) {
    if (evaluations.isEmpty) {
      return {
        'totalEvaluations': 0,
        'averageScore': 0.0,
        'highestScore': 0.0,
        'lowestScore': 0.0,
        'progressTrend': 'no_data',
        'scoreChanges': [],
      };
    }

    final scores = evaluations.map((e) => _safeDouble(e['progress_score']) ?? 0.0).toList();
    final averageScore = scores.reduce((a, b) => a + b) / scores.length;
    final highestScore = scores.reduce((a, b) => a > b ? a : b);
    final lowestScore = scores.reduce((a, b) => a < b ? a : b);

    // Analyze overall trend
    String progressTrend;
    final firstScore = scores.first;
    final lastScore = scores.last;
    final overallChange = lastScore - firstScore;

    if (overallChange > 10) {
      progressTrend = 'strong_improvement';
    } else if (overallChange > 5) {
      progressTrend = 'moderate_improvement';
    } else if (overallChange > -5) {
      progressTrend = 'stable';
    } else if (overallChange > -10) {
      progressTrend = 'moderate_decline';
    } else {
      progressTrend = 'significant_decline';
    }

    // Calculate changes between consecutive evaluations
    final scoreChanges = <Map<String, dynamic>>[];
    for (int i = 1; i < evaluations.length; i++) {
      final prevScore = _safeDouble(evaluations[i-1]['progress_score']) ?? 0.0;
      final currentScore = _safeDouble(evaluations[i]['progress_score']) ?? 0.0;
      final change = currentScore - prevScore;

      scoreChanges.add({
        'fromDate': _formatDate(_safeString(evaluations[i-1]['created_at'])),
        'toDate': _formatDate(_safeString(evaluations[i]['created_at'])),
        'fromScore': prevScore,
        'toScore': currentScore,
        'change': change,
        'trend': change >= 0 ? 'improvement' : 'decline',
      });
    }

    // Find best and worst evaluations
    final bestEvaluation = evaluations[scores.indexOf(highestScore)];
    final worstEvaluation = evaluations[scores.indexOf(lowestScore)];

    return {
      'totalEvaluations': evaluations.length,
      'averageScore': averageScore,
      'highestScore': highestScore,
      'lowestScore': lowestScore,
      'overallChange': overallChange,
      'progressTrend': progressTrend,
      'scoreChanges': scoreChanges,
      'bestEvaluation': bestEvaluation,
      'worstEvaluation': worstEvaluation,
      'evaluationDates': evaluations.map((e) => _formatDate(_safeString(e['created_at']))).toList(),
      'evaluationScores': scores,
    };
  }

  Map<String, dynamic> _calculateProgressMetrics(double firstScore, double secondScore, int daysBetween) {
    final scoreDifference = secondScore - firstScore;
    final percentageChange = firstScore > 0 ? (scoreDifference / firstScore) * 100 : 0.0;

    final weeklyImprovementRate = daysBetween >= 7 ? (scoreDifference / (daysBetween / 7)) : scoreDifference;
    final monthlyImprovementRate = daysBetween >= 30 ? (scoreDifference / (daysBetween / 30)) : scoreDifference;

    String progressPace;
    if (monthlyImprovementRate > 10) {
      progressPace = 'rapid';
    } else if (monthlyImprovementRate > 5) {
      progressPace = 'moderate';
    } else if (monthlyImprovementRate > 0) {
      progressPace = 'slow';
    } else if (monthlyImprovementRate > -5) {
      progressPace = 'stable';
    } else {
      progressPace = 'declining';
    }

    return {
      'absoluteChange': scoreDifference,
      'percentageChange': percentageChange,
      'weeklyImprovementRate': weeklyImprovementRate,
      'monthlyImprovementRate': monthlyImprovementRate,
      'progressPace': progressPace,
      'expectedTimeline': _calculateExpectedTimeline(secondScore, monthlyImprovementRate),
    };
  }

  Map<String, dynamic> _createOverallAssessment(
      double scoreDifference,
      Map<String, dynamic> domainAnalysis,
      Map<String, dynamic> progressMetrics,
      int daysBetween
      ) {
    final stats = domainAnalysis['statistics'];
    final improvedCount = stats['improvedCount'];
    final declinedCount = stats['declinedCount'];

    String overallTrend;
    Color trendColor;
    IconData trendIcon;
    String summary;
    String detailedAnalysis;

    // Multi-factor assessment
    if (scoreDifference > 15 && improvedCount >= 3 && declinedCount == 0) {
      overallTrend = 'exceptional_progress';
      trendColor = Colors.green[700]!;
      trendIcon = Icons.trending_up;
      summary = 'Exceptional Progress Achieved 🎉';
      detailedAnalysis = 'Outstanding improvement across multiple domains with consistent positive trajectory.';
    }
    else if (scoreDifference > 8 && improvedCount > declinedCount) {
      overallTrend = 'significant_improvement';
      trendColor = Colors.green;
      trendIcon = Icons.trending_up;
      summary = 'Significant Improvement 📈';
      detailedAnalysis = 'Strong progress with notable improvements in key areas.';
    }
    else if (scoreDifference > 0 || improvedCount > 0) {
      overallTrend = 'moderate_improvement';
      trendColor = Colors.lightGreen;
      trendIcon = Icons.trending_up;
      summary = 'Steady Progress ↗️';
      detailedAnalysis = 'Consistent improvement with positive developments in several areas.';
    }
    else if (scoreDifference.abs() < 5 && declinedCount == 0) {
      overallTrend = 'stable_performance';
      trendColor = Colors.blue;
      trendIcon = Icons.trending_flat;
      summary = 'Stable Performance 🔄';
      detailedAnalysis = 'Consistent performance maintained across most domains.';
    }
    else if (scoreDifference < -10 || declinedCount >= 3) {
      overallTrend = 'significant_concern';
      trendColor = Colors.red;
      trendIcon = Icons.trending_down;
      summary = 'Significant Concern ⚠️';
      detailedAnalysis = 'Notable decline observed, requires immediate attention and strategy review.';
    }
    else {
      overallTrend = 'mixed_results';
      trendColor = Colors.orange;
      trendIcon = Icons.auto_graph;
      summary = 'Mixed Results 🔄';
      detailedAnalysis = 'Varied performance across different domains requiring targeted approach.';
    }

    return {
      'trend': overallTrend,
      'color': trendColor,
      'icon': trendIcon,
      'summary': summary,
      'detailedAnalysis': detailedAnalysis,
      'confidenceLevel': _calculateConfidenceLevel(daysBetween, domainAnalysis),
      'keyStrengths': _identifyKeyStrengths(domainAnalysis),
      'priorityAreas': _identifyPriorityAreas(domainAnalysis),
    };
  }

  // ========== HELPER METHODS ==========

  String _getDomainTrend(double difference) {
    if (difference > 10) return 'strong_improvement';
    if (difference > 5) return 'moderate_improvement';
    if (difference > -5) return 'stable';
    if (difference > -10) return 'moderate_decline';
    return 'significant_decline';
  }

  String _getChangeSignificance(double difference) {
    if (difference > 15) return 'high';
    if (difference > 8) return 'medium';
    if (difference > 3) return 'low';
    return 'minimal';
  }

  String _calculateExpectedTimeline(double currentScore, double monthlyRate) {
    if (monthlyRate <= 0) return 'Not applicable - review intervention strategy';

    final pointsToTarget = 100 - currentScore;
    final monthsToTarget = pointsToTarget / monthlyRate;

    if (monthsToTarget <= 3) return '3 months or less';
    if (monthsToTarget <= 6) return '3-6 months';
    if (monthsToTarget <= 12) return '6-12 months';
    return 'More than 12 months - consider strategy adjustment';
  }

  String _calculateConfidenceLevel(int daysBetween, Map<String, dynamic> domainAnalysis) {
    final stats = domainAnalysis['statistics'];
    final totalDomains = stats['totalDomains'];

    if (daysBetween >= 60 && totalDomains >= 5) return 'High';
    if (daysBetween >= 30 && totalDomains >= 3) return 'Medium';
    return 'Low';
  }

  List<String> _identifyKeyStrengths(Map<String, dynamic> domainAnalysis) {
    final improvedDomains = domainAnalysis['improvedDomains'] as List;
    final strengths = <String>[];

    for (final domain in improvedDomains) {
      if (domain['difference'] > 10) {
        strengths.add(domain['name']);
      }
    }

    return strengths.take(3).toList();
  }

  List<String> _identifyPriorityAreas(Map<String, dynamic> domainAnalysis) {
    final declinedDomains = domainAnalysis['declinedDomains'] as List;
    final priorities = <String>[];

    for (final domain in declinedDomains) {
      if (domain['difference'] < -5) {
        priorities.add(domain['name']);
      }
    }

    return priorities.take(3).toList();
  }

  List<String> _generateDomainInsights(
      List<dynamic> improvedDomains,
      List<dynamic> declinedDomains,
      List<dynamic> newDomains
      ) {
    final insights = <String>[];

    if (improvedDomains.isNotEmpty) {
      // استخدم طريقة آمنة بدل reduce
      Map<String, dynamic>? topImprovement;
      for (final domain in improvedDomains) {
        final domainMap = _safeMap(domain);
        final difference = _safeDouble(domainMap['difference']) ?? 0.0;
        if (topImprovement == null || difference > (_safeDouble(topImprovement['difference']) ?? 0.0)) {
          topImprovement = domainMap;
        }
      }

      if (topImprovement != null) {
        final domainName = _safeString(topImprovement['name']);
        final difference = _safeDouble(topImprovement['difference']) ?? 0.0;
        insights.add('Largest improvement in $domainName (+${difference.toStringAsFixed(1)}%)');
      }
    }

    if (declinedDomains.isNotEmpty) {
      // استخدم طريقة آمنة بدل reduce
      Map<String, dynamic>? topDecline;
      for (final domain in declinedDomains) {
        final domainMap = _safeMap(domain);
        final difference = _safeDouble(domainMap['difference']) ?? 0.0;
        if (topDecline == null || difference < (_safeDouble(topDecline['difference']) ?? 0.0)) {
          topDecline = domainMap;
        }
      }

      if (topDecline != null) {
        final domainName = _safeString(topDecline['name']);
        final difference = _safeDouble(topDecline['difference']) ?? 0.0;
        insights.add('Greatest challenge in $domainName (${difference.toStringAsFixed(1)}%)');
      }
    }

    if (newDomains.isNotEmpty) {
      insights.add('${newDomains.length} new assessment areas introduced');
    }

    return insights;
  }


  Map<String, dynamic> _generateDetailedInsights(
      Map<String, dynamic> domainAnalysis,
      Map<String, dynamic> progressMetrics
      ) {
    final stats = domainAnalysis['statistics'];

    return {
      'performanceConsistency': _assessConsistency(stats),
      'improvementPattern': _identifyImprovementPattern(domainAnalysis),
      'interventionEffectiveness': _assessInterventionEffectiveness(progressMetrics, stats),
      'growthPotential': _assessGrowthPotential(domainAnalysis),
    };
  }

  String _assessConsistency(Map<String, dynamic> stats) {
    final stabilityRate = stats['stabilityRate'];
    if (stabilityRate > 70) return 'Highly Consistent';
    if (stabilityRate > 50) return 'Moderately Consistent';
    return 'Variable Performance';
  }

  String _identifyImprovementPattern(Map<String, dynamic> domainAnalysis) {
    final improvedCount = domainAnalysis['statistics']['improvedCount'];
    final totalDomains = domainAnalysis['statistics']['totalDomains'];

    if (improvedCount == totalDomains) return 'Comprehensive Improvement';
    if (improvedCount >= totalDomains * 0.7) return 'Broad-Based Improvement';
    if (improvedCount >= totalDomains * 0.4) return 'Targeted Improvement';
    return 'Limited Improvement';
  }

  String _assessInterventionEffectiveness(Map<String, dynamic> progressMetrics, Map<String, dynamic> stats) {
    final monthlyRate = progressMetrics['monthlyImprovementRate'];
    final improvedCount = stats['improvedCount'];

    if (monthlyRate > 8 && improvedCount >= 3) return 'Highly Effective';
    if (monthlyRate > 4 && improvedCount >= 2) return 'Moderately Effective';
    if (monthlyRate > 0) return 'Minimally Effective';
    return 'Needs Review';
  }

  String _assessGrowthPotential(Map<String, dynamic> domainAnalysis) {
    final newDomains = domainAnalysis['newDomains'] as List;
    final improvedCount = domainAnalysis['statistics']['improvedCount'];

    if (newDomains.isNotEmpty && improvedCount > 0) return 'High Growth Potential';
    if (improvedCount >= 2) return 'Moderate Growth Potential';
    return 'Foundation Building Phase';
  }

  List<String> _generateComprehensiveRecommendations(
      Map<String, dynamic> overallAssessment,
      Map<String, dynamic> domainAnalysis,
      Map<String, dynamic> progressMetrics
      ) {
    final recommendations = <String>[];
    final trend = overallAssessment['trend'];
    final priorities = overallAssessment['priorityAreas'] as List<String>;
    final strengths = overallAssessment['keyStrengths'] as List<String>;
    final stats = domainAnalysis['statistics'];

    // Trend-based recommendations
    switch (trend) {
      case 'exceptional_progress':
        recommendations.add('Continue current intervention strategies - they are highly effective');
        recommendations.add('Consider introducing advanced challenges in strongest areas');
        recommendations.add('Document successful approaches for future reference');
        break;
      case 'significant_improvement':
        recommendations.add('Maintain current intervention intensity and frequency');
        recommendations.add('Focus on consolidating gains in improved areas');
        recommendations.add('Gradually introduce new challenges');
        break;
      case 'moderate_improvement':
        recommendations.add('Continue current approach with minor adjustments');
        recommendations.add('Identify and address barriers to faster progress');
        recommendations.add('Strengthen support in areas showing slower improvement');
        break;
      case 'stable_performance':
        recommendations.add('Maintain consistency in intervention delivery');
        recommendations.add('Consider varying techniques to stimulate progress');
        recommendations.add('Focus on quality of engagement rather than quantity');
        break;
      case 'significant_concern':
        recommendations.add('Immediate review and adjustment of intervention strategies');
        recommendations.add('Increase session frequency or intensity in priority areas');
        recommendations.add('Consider multidisciplinary assessment if decline continues');
        break;
      case 'mixed_results':
        recommendations.add('Differentiate intervention approaches based on domain performance');
        recommendations.add('Capitalize on strengths to support weaker areas');
        recommendations.add('Review environmental and contextual factors affecting performance');
        break;
    }

    // Domain-specific recommendations
    if (priorities.isNotEmpty) {
      recommendations.add('Priority focus needed on: ${priorities.join(', ')}');
    }

    if (strengths.isNotEmpty) {
      recommendations.add('Leverage strengths in: ${strengths.join(', ')} to support other areas');
    }

    // Progress pace recommendations
    final pace = progressMetrics['progressPace'];
    if (pace == 'slow') {
      recommendations.add('Consider intensifying intervention or trying alternative approaches');
    } else if (pace == 'declining') {
      recommendations.add('Urgent strategy review required - consider environmental and motivational factors');
    }

    // Statistical recommendations
    if (stats['newCount'] > 0) {
      recommendations.add('Ensure proper baseline establishment for new assessment areas');
    }

    if (stats['removedCount'] > 0) {
      recommendations.add('Review rationale for discontinued assessment areas');
    }

    return recommendations.take(8).toList();
  }

  void _toggleComparisonMode() {
    setState(() {
      _comparisonMode = !_comparisonMode;
      if (!_comparisonMode) {
        _selectedEvaluationsForComparison.clear();
        _comparisonResults = null;
        _comparisonType = 'select_manually';
        _allEvaluationsInPeriod.clear();
      }
    });
  }

  // ========== UI COMPONENTS ==========

  Widget _buildComparisonSelector() {
    return Container(
      padding: EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Evaluation Comparison',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Choose how you want to compare evaluations:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),

          _buildComparisonOption(
            Icons.compare_arrows,
            'Select Two Evaluations',
            'Manually choose any two specific evaluations to compare',
            'select_manually',
          ),

          SizedBox(height: 12),

          _buildComparisonOption(
            Icons.date_range,
            'Date Range Comparison',
            'Compare first and last evaluations within a specific time period',
            'date_range',
          ),

          SizedBox(height: 12),

          _buildComparisonOption(
            Icons.calendar_view_month,
            'Last Month Progress',
            'Analyze progress over the last 30 days',
            'last_month',
          ),

          SizedBox(height: 12),

          _buildComparisonOption(
            Icons.timeline,
            'Last 3 Months Trend',
            'Track development and trends over the last 3 months',
            'last_3_months',
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonOption(IconData icon, String title, String subtitle, String type) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF7815A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFF7815A0)),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _startComparison(type),
      ),
    );
  }

  Widget _buildComprehensiveComparisonReport() {
    if (_comparisonResults == null) return SizedBox();

    final comparison = _comparisonResults!;
    final scoreAnalysis = comparison['scoreAnalysis'];
    final overallAssessment = comparison['overallAssessment'];
    final domainAnalysis = comparison['domainAnalysis'];
    final progressMetrics = comparison['progressMetrics'];
    final periodAnalysis = comparison['periodAnalysis'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildComparisonHeader(comparison),
          SizedBox(height: 20),
          _buildOverallAssessmentCard(overallAssessment),
          SizedBox(height: 16),

          // Show period analysis when there are multiple evaluations
          if (_allEvaluationsInPeriod.length > 2)
            Column(
              children: [
                _buildPeriodAnalysisCard(periodAnalysis),
                SizedBox(height: 16),
              ],
            ),

          _buildScoreAnalysisCard(scoreAnalysis, progressMetrics),
          SizedBox(height: 16),
          _buildDomainAnalysisCard(domainAnalysis),
          SizedBox(height: 16),
          _buildProgressInsightsCard(comparison['detailedInsights']),
          SizedBox(height: 16),
          _buildRecommendationsCard(comparison['recommendations']),
          SizedBox(height: 16),
          _buildComparisonActions(),
        ],
      ),
    );
  }

  Widget _buildComparisonHeader(Map<String, dynamic> comparison) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7815A0), Color(0xFF9C27B0)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.analytics, size: 40, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'Comprehensive Progress Report',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '${comparison['firstDate']} to ${comparison['secondDate']}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Analysis Period: ${comparison['period']}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallAssessmentCard(Map<String, dynamic> assessment) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: assessment['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(assessment['icon'], color: assessment['color'], size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assessment['summary'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: assessment['color'],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Confidence: ${assessment['confidenceLevel']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              assessment['detailedAnalysis'],
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if ((assessment['keyStrengths'] as List).isNotEmpty)
                  Chip(
                    label: Text('${(assessment['keyStrengths'] as List).length} Strengths'),
                    backgroundColor: Colors.green[50],
                    side: BorderSide(color: Colors.green[100]!),
                  ),
                if ((assessment['priorityAreas'] as List).isNotEmpty)
                  Chip(
                    label: Text('${(assessment['priorityAreas'] as List).length} Focus Areas'),
                    backgroundColor: Colors.orange[50],
                    side: BorderSide(color: Colors.orange[100]!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreAnalysisCard(Map<String, dynamic> scoreAnalysis, Map<String, dynamic> progressMetrics) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.score, color: Color(0xFF7815A0), size: 24),
                SizedBox(width: 12),
                Text(
                  'Score Analysis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreMetric('Initial', '${scoreAnalysis['firstScore']?.toStringAsFixed(1)}%', Icons.flag),
                _buildScoreMetric('Current', '${scoreAnalysis['secondScore']?.toStringAsFixed(1)}%', Icons.assessment),
                _buildScoreMetric('Change', '${scoreAnalysis['absoluteChange'] >= 0 ? '+' : ''}${scoreAnalysis['absoluteChange']?.toStringAsFixed(1)}%',
                    scoreAnalysis['absoluteChange'] >= 0 ? Icons.arrow_upward : Icons.arrow_downward),
              ],
            ),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 16),
            Text(
              'Progress Metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressMetric('Monthly Rate', '${progressMetrics['monthlyImprovementRate']?.toStringAsFixed(1)}%', Icons.timeline),
                _buildProgressMetric('Progress Pace', progressMetrics['progressPace'], Icons.speed),
                _buildProgressMetric('Timeline', progressMetrics['expectedTimeline'].split(' ').first, Icons.schedule),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF7815A0).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Color(0xFF7815A0)),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPeriodAnalysisCard(Map<String, dynamic> periodAnalysis) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: Colors.purple, size: 24),
                SizedBox(width: 12),
                Text(
                  'Period Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Key Statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPeriodStat('Total', periodAnalysis['totalEvaluations'].toString(), Icons.assessment),
                _buildPeriodStat('Average', '${periodAnalysis['averageScore']?.toStringAsFixed(1)}%', Icons.bar_chart),
                _buildPeriodStat('Change', '${periodAnalysis['overallChange'] >= 0 ? '+' : ''}${periodAnalysis['overallChange']?.toStringAsFixed(1)}%',
                    periodAnalysis['overallChange'] >= 0 ? Icons.arrow_upward : Icons.arrow_downward),
              ],
            ),

            SizedBox(height: 20),

            // Performance Highlights
            Row(
              children: [

                Expanded(
                  child: _buildPerformanceCard(
                    'Best Score',
                    '${periodAnalysis['highestScore']?.toStringAsFixed(1)}%',
                    Colors.green,
                    Icons.emoji_events,
                    periodAnalysis['bestEvaluation'],
                  ),
                ),
                SizedBox(width:2),
                Expanded(
                  child: _buildPerformanceCard(
                    'Needs Attention',
                    '${periodAnalysis['lowestScore']?.toStringAsFixed(1)}%',
                    Colors.orange,
                    Icons.warning,
                    periodAnalysis['worstEvaluation'],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.purple),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(String title, String score, Color color, IconData icon, dynamic evaluation) {
    final evalDate = evaluation != null ? _formatDate(_safeString(evaluation['created_at'])) : 'N/A';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            score,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            evalDate,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainAnalysisCard(Map<String, dynamic> domainAnalysis) {
    final stats = domainAnalysis['statistics'];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: Colors.teal, size: 24),
                SizedBox(width: 12),
                Text(
                  'Domain Analysis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Domain Statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDomainStat('Improved', stats['improvedCount'], Colors.green),
                _buildDomainStat('Stable', stats['stableCount'], Colors.blue),
                _buildDomainStat('Needs Work', stats['declinedCount'], Colors.orange),
              ],
            ),

            SizedBox(height: 20),

            // Key Insights
            if (domainAnalysis['keyInsights'] != null && (domainAnalysis['keyInsights'] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Insights:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  ...(domainAnalysis['keyInsights'] as List).map((insight) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.insights, size: 16, color: Colors.purple),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            insight,
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainStat(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressInsightsCard(Map<String, dynamic> insights) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph, color: Colors.indigo, size: 24),
                SizedBox(width: 12),
                Text(
                  'Progress Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInsightRow('Performance Consistency', insights['performanceConsistency']),
            _buildInsightRow('Improvement Pattern', insights['improvementPattern']),
            _buildInsightRow('Intervention Effectiveness', insights['interventionEffectiveness']),
            _buildInsightRow('Growth Potential', insights['growthPotential']),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(List<String> recommendations) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
                SizedBox(width: 12),
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...recommendations.map((recommendation) => Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_right, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleComparisonMode,
            icon: Icon(Icons.close),
            label: Text('Exit Comparison'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Export feature coming soon!')),
              );
            },
            icon: Icon(Icons.download),
            label: Text('Export Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF7815A0),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationCard(dynamic evaluation) {
    final safeEval = _safeMap(evaluation);
    final isSelected = _selectedEvaluationsForComparison.contains(evaluation);
    final progressScore = _safeDouble(safeEval['progress_score']) ?? 0.0;
    final evalType = _safeString(safeEval['evaluation_type']);
    final createdAt = _safeString(safeEval['created_at']);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Color(0xFF7815A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isSelected ? Icons.check_circle : Icons.assessment,
            color: isSelected ? Colors.blue : Color(0xFF7815A0),
          ),
        ),
        title: Text(
          evalType.isNotEmpty ? evalType : 'General Evaluation',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDate(createdAt)),
            SizedBox(height: 2),
            Text(
              'Score: ${progressScore.toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _getScoreColor(progressScore),
              ),
            ),
          ],
        ),
        trailing: _comparisonMode ? Icon(
          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
          color: isSelected ? Colors.blue : Colors.grey,
        ) : null,
        onTap: _comparisonMode ? () => _toggleEvaluationSelection(evaluation) : null,
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  // ========== EXISTING PROGRESS ANALYSIS ==========

  Map<String, dynamic> _analyzeProgress(List<dynamic> evaluations) {
    final safeEvaluations = _safeList(evaluations);

    if (safeEvaluations.isEmpty) {
      return {
        'trend': 'no_data',
        'message': 'No evaluations available',
        'improvement': 0.0,
        'hasEnoughData': false,
        'confidence': 'low',
        'trendColor': Colors.grey,
        'trendIcon': Icons.help_outline,
      };
    }

    if (safeEvaluations.length == 1) {
      final score = _safeDouble(safeEvaluations.first['progress_score']) ?? 0.0;
      return {
        'trend': 'initial',
        'message': 'Initial evaluation completed',
        'improvement': 0.0,
        'currentScore': score,
        'hasEnoughData': false,
        'confidence': 'medium',
        'trendColor': Colors.blue,
        'trendIcon': Icons.assessment,
        'firstScore': score,
        'lastScore': score,
      };
    }

    final sortedEvaluations = List.from(safeEvaluations)
      ..sort((a, b) {
        try {
          final dateA = DateTime.parse(_safeString(a['created_at']));
          final dateB = DateTime.parse(_safeString(b['created_at']));
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });

    final analysis = _advancedProgressAnalysis(sortedEvaluations);
    return analysis;
  }

  Map<String, dynamic> _advancedProgressAnalysis(List<dynamic> evaluations) {
    final scores = evaluations.map((e) => _safeDouble(e['progress_score']) ?? 0.0).toList();
    final dates = evaluations.map((e) => DateTime.parse(_safeString(e['created_at']))).toList();

    final firstScore = scores.first;
    final lastScore = scores.last;
    final simpleImprovement = lastScore - firstScore;
    final averageScore = scores.reduce((a, b) => a + b) / scores.length;

    final trendAnalysis = _calculateTrend(scores, dates);
    final stabilityAnalysis = _calculateStability(scores);
    final recentAnalysis = _analyzeRecentProgress(scores);

    return _determineFinalClassification(
      simpleImprovement: simpleImprovement,
      trendSlope: trendAnalysis['slope'],
      stability: stabilityAnalysis['stability'],
      recentTrend: recentAnalysis['trend'],
      averageScore: averageScore,
      evaluationCount: scores.length,
      firstScore: firstScore,
      lastScore: lastScore,
    );
  }

  Map<String, dynamic> _calculateTrend(List<double> scores, List<DateTime> dates) {
    if (scores.length < 2) return {'slope': 0.0, 'rSquared': 0.0, 'trend': 'unknown'};

    final firstDate = dates.first;
    final xValues = dates.map((date) => date.difference(firstDate).inDays.toDouble()).toList();

    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    final n = scores.length.toDouble();

    for (int i = 0; i < scores.length; i++) {
      sumX += xValues[i];
      sumY += scores[i];
      sumXY += xValues[i] * scores[i];
      sumX2 += xValues[i] * xValues[i];
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    double ssTotal = 0, ssResidual = 0;
    final meanY = sumY / n;

    for (int i = 0; i < scores.length; i++) {
      final prediction = slope * xValues[i] + intercept;
      ssTotal += pow(scores[i] - meanY, 2);
      ssResidual += pow(scores[i] - prediction, 2);
    }

    final rSquared = ssTotal > 0 ? (1 - (ssResidual / ssTotal)) : 0.0;

    String trend;
    if (slope > 0.1) trend = 'strong_improvement';
    else if (slope > 0.02) trend = 'moderate_improvement';
    else if (slope > -0.02) trend = 'stable';
    else if (slope > -0.1) trend = 'moderate_decline';
    else trend = 'strong_decline';

    return {
      'slope': slope,
      'rSquared': rSquared,
      'trend': trend,
      'intercept': intercept,
    };
  }

  Map<String, dynamic> _calculateStability(List<double> scores) {
    if (scores.length < 2) return {'stability': 'unknown', 'volatility': 0.0};

    final average = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores.map((score) => pow(score - average, 2)).reduce((a, b) => a + b) / scores.length;
    final standardDeviation = sqrt(variance);
    final volatility = average > 0 ? (standardDeviation / average) * 100 : 0.0;

    String stability;
    if (volatility < 5) stability = 'very_stable';
    else if (volatility < 10) stability = 'stable';
    else if (volatility < 15) stability = 'moderate_volatility';
    else if (volatility < 20) stability = 'high_volatility';
    else stability = 'very_high_volatility';

    return {
      'stability': stability,
      'volatility': volatility,
      'standardDeviation': standardDeviation,
    };
  }

  Map<String, dynamic> _analyzeRecentProgress(List<double> scores) {
    if (scores.length < 3) return {'trend': 'insufficient_data', 'recentImprovement': 0.0};

    final recentScores = scores.sublist(scores.length - 3);
    final recentImprovement = recentScores.last - recentScores.first;

    String trend;
    if (recentImprovement > 5) trend = 'strong_recent_improvement';
    else if (recentImprovement > 2) trend = 'moderate_recent_improvement';
    else if (recentImprovement > -2) trend = 'stable_recent';
    else if (recentImprovement > -5) trend = 'moderate_recent_decline';
    else trend = 'strong_recent_decline';

    return {
      'trend': trend,
      'recentImprovement': recentImprovement,
      'recentScores': recentScores,
    };
  }

  Map<String, dynamic> _determineFinalClassification({
    required double simpleImprovement,
    required double trendSlope,
    required String stability,
    required String recentTrend,
    required double averageScore,
    required int evaluationCount,
    required double firstScore,
    required double lastScore,
  }) {
    String confidence = 'medium';
    if (evaluationCount >= 5 && trendSlope.abs() > 0.05) confidence = 'high';
    if (evaluationCount < 3) confidence = 'low';

    String primaryTrend;
    Color trendColor;
    IconData trendIcon;
    String message;
    String detailedMessage;

    final bool hasStrongImprovement = simpleImprovement > 15 || trendSlope > 0.15;
    final bool hasModerateImprovement = simpleImprovement > 5 || trendSlope > 0.05;
    final bool hasStablePerformance = simpleImprovement.abs() < 5 && trendSlope.abs() < 0.03;
    final bool hasModerateDecline = simpleImprovement < -5 || trendSlope < -0.05;
    final bool hasStrongDecline = simpleImprovement < -15 || trendSlope < -0.15;

    final bool isConsistent = stability == 'very_stable' || stability == 'stable';
    final bool hasRecentImprovement = recentTrend.contains('improvement');
    final bool hasRecentDecline = recentTrend.contains('decline');

    if (hasStrongImprovement && isConsistent) {
      primaryTrend = 'exceptional_improvement';
      trendColor = Colors.green[700]!;
      trendIcon = Icons.trending_up;
      message = 'Exceptional Progress! 🌟';
      detailedMessage = 'Outstanding consistent improvement with strong growth trajectory';
    }
    else if (hasStrongImprovement) {
      primaryTrend = 'significant_improvement';
      trendColor = Colors.green;
      trendIcon = Icons.trending_up;
      message = 'Excellent Progress! 🎉';
      detailedMessage = 'Significant improvement observed, though with some variability';
    }
    else if (hasModerateImprovement && hasRecentImprovement) {
      primaryTrend = 'accelerating_improvement';
      trendColor = Colors.green[400]!;
      trendIcon = Icons.trending_up;
      message = 'Steady Improvement 📈';
      detailedMessage = 'Consistent improvement with positive recent momentum';
    }
    else if (hasModerateImprovement) {
      primaryTrend = 'moderate_improvement';
      trendColor = Colors.lightGreen;
      trendIcon = Icons.trending_up;
      message = 'Good Progress 📈';
      detailedMessage = 'Steady improvement maintained over time';
    }
    else if (hasStablePerformance && isConsistent) {
      primaryTrend = 'very_stable';
      trendColor = Colors.blue;
      trendIcon = Icons.trending_flat;
      message = 'Very Stable Performance 🔄';
      detailedMessage = 'Highly consistent performance with minimal fluctuations';
    }
    else if (hasStablePerformance) {
      primaryTrend = 'stable';
      trendColor = Colors.orange;
      trendIcon = Icons.trending_flat;
      message = 'Stable Performance ➡️';
      detailedMessage = 'Overall stable performance with normal variations';
    }
    else if (hasModerateDecline && hasRecentDecline) {
      primaryTrend = 'accelerating_decline';
      trendColor = Colors.red[600]!;
      trendIcon = Icons.trending_down;
      message = 'Growing Concerns 📉';
      detailedMessage = 'Moderate decline with concerning recent trend';
    }
    else if (hasModerateDecline) {
      primaryTrend = 'moderate_decline';
      trendColor = Colors.orange[700]!;
      trendIcon = Icons.trending_down;
      message = 'Needs Attention 📉';
      detailedMessage = 'Moderate decline observed, requires intervention';
    }
    else if (hasStrongDecline) {
      primaryTrend = 'significant_decline';
      trendColor = Colors.red;
      trendIcon = Icons.trending_down;
      message = 'Significant Decline! ⚠️';
      detailedMessage = 'Major decline detected, immediate attention required';
    }
    else {
      primaryTrend = 'mixed_pattern';
      trendColor = Colors.purple;
      trendIcon = Icons.auto_graph;
      message = 'Mixed Pattern 🔄';
      detailedMessage = 'Complex performance pattern with varying trends';
    }

    final recommendations = _generateProgressRecommendations(
      primaryTrend: primaryTrend,
      stability: stability,
      recentTrend: recentTrend,
      averageScore: averageScore,
      evaluationCount: evaluationCount,
    );

    return {
      'trend': primaryTrend,
      'message': message,
      'detailedMessage': detailedMessage,
      'improvement': simpleImprovement,
      'trendColor': trendColor,
      'trendIcon': trendIcon,
      'firstScore': firstScore,
      'lastScore': lastScore,
      'averageScore': averageScore,
      'evaluationCount': evaluationCount,
      'confidence': confidence,
      'stability': stability,
      'recentTrend': recentTrend,
      'trendSlope': trendSlope,
      'recommendations': recommendations,
      'hasEnoughData': true,
    };
  }

  List<String> _generateProgressRecommendations({
    required String primaryTrend,
    required String stability,
    required String recentTrend,
    required double averageScore,
    required int evaluationCount,
  }) {
    final recommendations = <String>[];

    if (primaryTrend.contains('improvement')) {
      recommendations.add('Continue current intervention strategies');
      if (primaryTrend.contains('exceptional') || primaryTrend.contains('significant')) {
        recommendations.add('Consider advancing to more challenging goals');
      }
    }

    if (primaryTrend.contains('decline')) {
      recommendations.add('Review and adjust current intervention strategies');
      recommendations.add('Consider additional assessment to identify challenges');
      if (primaryTrend.contains('significant')) {
        recommendations.add('Urgent intervention recommended');
      }
    }

    if (primaryTrend.contains('stable')) {
      recommendations.add('Maintain consistent intervention approach');
      if (averageScore < 50) {
        recommendations.add('Consider intensifying support for breakthrough');
      }
    }

    if (stability.contains('high_volatility')) {
      recommendations.add('Focus on consistency and routine in sessions');
      recommendations.add('Monitor for external factors affecting performance');
    }

    if (stability.contains('very_stable')) {
      recommendations.add('Stable pattern allows for predictable progress planning');
    }

    if (recentTrend.contains('recent_improvement')) {
      recommendations.add('Recent positive trend - capitalize on current momentum');
    }

    if (recentTrend.contains('recent_decline')) {
      recommendations.add('Address recent challenges promptly');
    }

    if (evaluationCount < 4) {
      recommendations.add('More evaluations needed for comprehensive analysis');
    }

    if (averageScore < 40) {
      recommendations.add('Consider foundational skill development focus');
    } else if (averageScore > 80) {
      recommendations.add('Focus on advanced skill development and maintenance');
    }

    return recommendations;
  }

  Widget _buildAdvancedProgressChart(List<dynamic> evaluations, Map<String, dynamic> analysis) {
    final safeEvaluations = _safeList(evaluations);

    if (safeEvaluations.isEmpty) {
      return _buildEmptyChart();
    }

    return Container(
      padding: EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: analysis['trendColor'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: analysis['trendColor'].withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(analysis['trendIcon'], color: analysis['trendColor'], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        analysis['message'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: analysis['trendColor'],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  analysis['detailedMessage'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: analysis['trendColor'].withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Container(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: safeEvaluations.asMap().entries.map((entry) {
                final index = entry.key;
                final evaluation = _safeMap(entry.value);
                final score = _safeDouble(evaluation['progress_score']) ?? 0.0;
                final height = (score / 100) * 80;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message: '${_formatDate(_safeString(evaluation['created_at']))}\nScore: ${score.toInt()}%',
                          child: Container(
                            width: 20,
                            height: height.clamp(10, 80).toDouble(),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF7815A0), Color(0xFF9C27B0)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${score.toInt()}%',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.assessment, size: 40, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text(
            'No evaluations yet',
            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ========== TAB BUILD METHODS ==========

  Widget _buildEvaluationsTab() {
    final evaluations = _safeList(childData?['evaluations']);
    final progressAnalysis = _analyzeProgress(evaluations);

    if (evaluations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No evaluations available',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Comparison Mode Toggle
        if (!_comparisonMode)
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _startComparison('select_manually'),
              icon: Icon(Icons.analytics),
              label: Text('Comprehensive Comparison Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7815A0),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

        // Comparison Interface
        if (_comparisonMode && _comparisonType == 'select_manually')
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildComparisonSelector(),
          ),

        // Comparison Results or Evaluations List
        if (_comparisonResults != null)
          Expanded(child: _buildComprehensiveComparisonReport())
        else if (_comparisonMode && _comparisonType == 'select_manually')
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select 2 evaluations to compare:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: evaluations.length,
                    itemBuilder: (context, index) => _buildEvaluationCard(evaluations[index]),
                  ),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: _buildAdvancedProgressChart(evaluations, progressAnalysis),
                  ),
                  ...evaluations.map((evaluation) => _buildEvaluationCard(evaluation)).toList(),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF7815A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFF7815A0)),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
        subtitle: Text(value.isNotEmpty ? value : 'Not available', style: TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildSessionCard(dynamic session) {
    final safeSession = _safeMap(session);
    final date = _safeString(safeSession['date']);
    final time = _safeString(safeSession['time']);
    final sessionType = _safeString(safeSession['session_type']);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF7815A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.event, color: Color(0xFF7815A0)),
        ),
        title: Text('Session ${_formatDate(date)}', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Time: ${time.isNotEmpty ? time : "Not specified"} - Type: ${sessionType.isNotEmpty ? sessionType : "Not specified"}'),
      ),
    );
  }

  Widget _buildInfoTab() {
    final child = _safeMap(childData?['child']);
    final parent = _safeMap(child['parent']);
    final diagnosis = _safeMap(child['diagnosis']);
    final institution = _safeMap(child['current_institution']);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard('Full Name', _safeString(child['full_name']), Icons.person),
          _buildInfoCard('Date of Birth', _formatDate(_safeString(child['date_of_birth'])), Icons.cake),
          _buildInfoCard('Gender', _safeString(child['gender']), Icons.people),
          _buildInfoCard('Diagnosis', _safeString(diagnosis['name']), Icons.medical_services),
          _buildInfoCard('Institution', _safeString(institution['name']), Icons.school),
          _buildInfoCard('Parent', _safeString(parent['full_name']), Icons.family_restroom),
          _buildInfoCard('Email', _safeString(parent['email']), Icons.email),
          _buildInfoCard('Phone', _safeString(parent['phone']), Icons.phone),
          if (_safeString(child['medical_history']).isNotEmpty)
            _buildInfoCard('Medical History', _safeString(child['medical_history']), Icons.medical_information),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    final sessions = _safeList(childData?['sessions']);

    return sessions.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No sessions available',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    )
        : ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        return _buildSessionCard(sessions[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.childName.isNotEmpty ? widget.childName : 'Child Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF7815A0),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_comparisonMode)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: _toggleComparisonMode,
              tooltip: 'Exit Comparison',
            ),
        ],
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7815A0)),
            SizedBox(height: 16),
            Text(
              'Loading child details...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage,
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChildDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7815A0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      )
          : childData == null
          ? Center(child: Text('No data available', style: TextStyle(fontSize: 16, color: Colors.grey[600])))
          : DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF7815A0),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: TabBar(
                labelColor: Color(0xFF7815A0),
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                tabs: [
                  Tab(text: 'Information'),
                  Tab(text: 'Evaluations'),
                  Tab(text: 'Sessions'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildInfoTab(),
                  _buildEvaluationsTab(),
                  _buildSessionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}