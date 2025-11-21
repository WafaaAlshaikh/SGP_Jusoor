// screens/screening_results_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/widgets/child_form_dialog.dart';
import '../models/screening_models.dart';
import '../theme/app_colors.dart';

class ScreeningResultsScreen extends StatefulWidget {
  final String sessionId;
  final ScreeningResults results;
  final Map<String, dynamic>? scores;

  const ScreeningResultsScreen({
    super.key,
    required this.sessionId,
    required this.results,
    this.scores,
  });

  @override
  State<ScreeningResultsScreen> createState() => _ScreeningResultsScreenState();
}

class _ScreeningResultsScreenState extends State<ScreeningResultsScreen> {
  bool _showEnhancedAnalysis = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening Results'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
          tooltip: 'Back to Dashboard',
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (widget.results.enhancedAnalysis != null &&
              widget.results.enhancedAnalysis!.success)
            IconButton(
              icon: Icon(_showEnhancedAnalysis ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _showEnhancedAnalysis = !_showEnhancedAnalysis;
                });
              },
              tooltip: _showEnhancedAnalysis ? 'Hide AI Analysis' : 'Show AI Analysis',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Risk Card - Most Important First
            _buildOverallRiskCard(),
            const SizedBox(height: 20),

            // Primary Concern
            if (widget.results.primaryConcern != null)
              _buildPrimaryConcernCard(),

            const SizedBox(height: 20),

            // Enhanced Analysis Toggle Section
            if (_showEnhancedAnalysis &&
                widget.results.enhancedAnalysis != null &&
                widget.results.enhancedAnalysis!.success)
              _buildEnhancedAnalysisSection(),

            // Detailed Results by Category
            _buildDetailedResultsSection(),

            const SizedBox(height: 20),

            // Red Flags
            if (widget.results.redFlags.isNotEmpty)
              _buildRedFlagsCard(),

            const SizedBox(height: 20),

            // Positive Indicators
            if (widget.results.positiveIndicators.isNotEmpty)
              _buildPositiveIndicatorsCard(),

            const SizedBox(height: 20),

            // Smart Next Steps
            if (widget.results.enhancedAnalysis?.nextSteps != null &&
                widget.results.enhancedAnalysis!.nextSteps.isNotEmpty)
              _buildSmartNextStepsCard(),

            const SizedBox(height: 20),

            // Scores Summary
            if (widget.scores != null)
              _buildScoresCard(),

            const SizedBox(height: 20),

            // AI Recommendations - MOVED TO BOTTOM
            if (_hasAIRecommendations())
              _buildAIRecommendationsCard(),

            const SizedBox(height: 30),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // Sections organized for better visual flow

  Widget _buildDetailedResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detailed Results',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 15),
        ...widget.results.riskLevels.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: _buildCategoryResultCard(
              title: _getCategoryTitle(entry.key),
              riskLevel: entry.value,
              color: _getRiskColor(entry.value),
              category: entry.key,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEnhancedAnalysisSection() {
    final enhanced = widget.results.enhancedAnalysis!;

    return Column(
      children: [
        Card(
          color: AppColors.accent1.withOpacity(0.05),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.accent1.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: AppColors.accent1),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Enhanced Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    Chip(
                      backgroundColor: _getUrgencyColor(enhanced.urgencyLevel),
                      label: Text(
                        enhanced.urgencyLevel.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // AI Suggested Conditions
                if (enhanced.aiAnalysis != null &&
                    enhanced.aiAnalysis!.suggestedConditions.isNotEmpty)
                  _buildAISuggestedConditions(enhanced.aiAnalysis!),

                const SizedBox(height: 15),

                // Recommended Institutions
                if (enhanced.recommendedInstitutions.isNotEmpty)
                  _buildRecommendedInstitutions(enhanced.recommendedInstitutions),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildOverallRiskCard() {
    final overallRisk = widget.results.overallRisk;
    final color = _getRiskColor(overallRisk);
    final message = _getOverallRiskMessage(overallRisk);

    return Card(
      color: color.withOpacity(0.1),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getRiskIcon(overallRisk),
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              _getRiskTitle(overallRisk),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                'Confidence: ${widget.results.confidenceLevel.toUpperCase()}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryConcernCard() {
    return Card(
      color: AppColors.warning.withOpacity(0.05),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.priority_high, color: AppColors.warning, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Primary Concern',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.results.primaryConcernLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (widget.results.secondaryConcern != null) ...[
              const SizedBox(height: 10),
              Text(
                'Secondary Concern: ${_formatConcernName(widget.results.secondaryConcern!)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryResultCard({
    required String title,
    required String riskLevel,
    required Color color,
    required String category,
  }) {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getRiskDescription(riskLevel),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                  if (widget.scores != null && widget.scores![category] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        _getScoreText(category, widget.scores![category]),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                riskLevel.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendationsCard() {
    final recommendations = _getAIRecommendations();

    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.recommend, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AI Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.asMap().entries.map((entry) {
              final index = entry.key;
              final recommendation = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: index == 0 ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: index == 0 ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      color: index == 0 ? AppColors.primary : AppColors.textGray,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                          fontWeight: index == 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRedFlagsCard() {
    return Card(
      color: AppColors.error.withOpacity(0.05),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flag, color: AppColors.error, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Red Flags',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.results.redFlags.map((flag) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      flag,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPositiveIndicatorsCard() {
    return Card(
      color: AppColors.success.withOpacity(0.05),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.thumb_up, color: AppColors.success, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Positive Indicators',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.results.positiveIndicators.map((indicator) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      indicator,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartNextStepsCard() {
    final nextSteps = widget.results.enhancedAnalysis!.nextSteps;

    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accent1.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome, color: AppColors.accent1, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Smart Next Steps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...nextSteps.map((step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _getStepIcon(step),
                    color: _getStepColor(step),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: TextStyle(
                        fontSize: 14,
                        color: _getStepColor(step),
                        fontWeight: _getStepFontWeight(step),
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildScoresCard() {
    return Card(
      color: AppColors.accent1.withOpacity(0.05),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.accent1.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accent1.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.assessment, color: AppColors.accent1, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Score Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.scores!.entries.map((entry) {
              if (entry.value is Map) {
                return _buildScoreRow(entry.key, entry.value);
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String category, Map<String, dynamic> scoreData) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getCategoryTitle(category),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatScoreData(scoreData),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Main Next Steps Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              _handleNextStepsAction(widget.results);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getNextStepsButtonColor(widget.results),
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            icon: Icon(_getNextStepsIcon(widget.results)),
            label: Text(
              _getNextStepsButtonText(widget.results),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Home Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: AppColors.primary),
            ),
            icon: const Icon(Icons.home),
            label: const Text(
              'Back to Home',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  // AI Suggested Conditions
  Widget _buildAISuggestedConditions(AIAnalysis aiAnalysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Suggested Conditions:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        ...aiAnalysis.suggestedConditions.map((condition) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 1,
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(condition.confidence),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          condition.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Confidence: ${condition.confidence}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                        ),
                        if (condition.matchingKeywords.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Keywords: ${condition.matchingKeywords.join(', ')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
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
          ),
        )),
      ],
    );
  }

  // Recommended Institutions
  Widget _buildRecommendedInstitutions(List<dynamic> institutions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended Centers:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        ...institutions.take(3).map((institution) {
          final inst = Map<String, dynamic>.from(institution);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.primary, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inst['name'] ?? 'Unknown Center',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${inst['city'] ?? ''} • Match: ${inst['match_score'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGray,
                            ),
                          ),
                          if (inst['matching_specialties'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Specialties: ${(inst['matching_specialties'] as List).join(', ')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (institutions.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              '+ ${institutions.length - 3} more centers available',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  void _handleNextStepsAction(ScreeningResults results) {
    _navigateToAddChildWithScreeningData(results);
  }

  void _navigateToAddChildWithScreeningData(ScreeningResults results) {
    final enhancedAnalysis = results.enhancedAnalysis;

    final Map<String, dynamic> prefilledData = {
      'from_screening': true,
      'screening_session_id': widget.sessionId,
      'screening_results': results.toJson(),
      'suspected_condition': results.primaryConcernLabel,
      'symptoms_description': _generateSymptomsFromScreening(results),
      'ai_analysis': enhancedAnalysis?.aiAnalysis?.toJson(),
      'recommended_institutions': enhancedAnalysis?.recommendedInstitutions ?? [],
      'screening_notes': _generateScreeningNotes(results),
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChildFormDialog(
          screeningData: prefilledData,
        ),
      ),
    );
  }

  String _generateSymptomsFromScreening(ScreeningResults results) {
    String symptoms = 'Initial screening results indicate:\n\n';

    if (results.primaryConcern != null) {
      symptoms += '• Primary indicator: ${results.primaryConcernLabel}\n';
    }

    if (results.riskLevels.isNotEmpty) {
      symptoms += '• Risk levels:\n';
      results.riskLevels.forEach((key, value) {
        symptoms += '   - ${_getCategoryTitle(key)}: $value\n';
      });
    }

    if (results.redFlags.isNotEmpty) {
      symptoms += '• Warning signs:\n';
      for (var flag in results.redFlags) {
        symptoms += '   - $flag\n';
      }
    }

    if (results.scores.isNotEmpty) {
      symptoms += '\n• Detailed results:\n';
      results.scores.forEach((key, value) {
        if (value is Map) {
          symptoms += '   - ${_getCategoryTitle(key)}: ${value.toString()}\n';
        }
      });
    }

    return symptoms;
  }

  String _generateScreeningNotes(ScreeningResults results) {
    return 'This data was automatically generated from the initial screening. '
        'Please review the information and verify its accuracy before submitting.';
  }

  // Helper Methods

  bool _hasAIRecommendations() {
    final enhanced = widget.results.enhancedAnalysis;
    if (enhanced == null || !enhanced.success) return false;

    if (enhanced.recommendations != null && enhanced.recommendations!.isNotEmpty) {
      return true;
    }

    if (enhanced.aiAnalysis?.recommendations != null &&
        enhanced.aiAnalysis!.recommendations!.isNotEmpty) {
      return true;
    }

    return false;
  }

  List<String> _getAIRecommendations() {
    final enhanced = widget.results.enhancedAnalysis;
    if (enhanced == null) return [];

    if (enhanced.recommendations != null && enhanced.recommendations!.isNotEmpty) {
      return enhanced.recommendations!;
    }

    if (enhanced.aiAnalysis?.recommendations != null &&
        enhanced.aiAnalysis!.recommendations!.isNotEmpty) {
      return enhanced.aiAnalysis!.recommendations!;
    }

    return [];
  }

  Color _getNextStepsButtonColor(ScreeningResults results) {
    switch (results.overallRisk) {
      case 'high': return AppColors.error;
      case 'medium': return AppColors.warning;
      default: return AppColors.success;
    }
  }

  IconData _getNextStepsIcon(ScreeningResults results) {
    switch (results.overallRisk) {
      case 'high': return Icons.warning;
      case 'medium': return Icons.monitor_heart;
      default: return Icons.thumb_up;
    }
  }

  String _getNextStepsButtonText(ScreeningResults results) {
    return 'Next Steps: Add Child for Follow-up';
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high': return AppColors.error;
      case 'medium': return AppColors.warning;
      case 'low': return AppColors.success;
      default: return AppColors.info;
    }
  }

  Color _getConfidenceColor(String confidence) {
    final percent = double.tryParse(confidence.replaceAll('%', '')) ?? 0;
    if (percent >= 70) return AppColors.success;
    if (percent >= 40) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getStepIcon(String step) {
    if (step.contains('URGENT') || step.contains('🚨')) return Icons.warning;
    if (step.contains('Recommended') || step.contains('🏫')) return Icons.recommend;
    if (step.contains('Contact') || step.contains('📞')) return Icons.phone;
    return Icons.arrow_forward;
  }

  Color _getStepColor(String step) {
    if (step.contains('URGENT') || step.contains('🚨')) return AppColors.error;
    if (step.contains('Recommended') || step.contains('🏫')) return AppColors.info;
    if (step.contains('Contact') || step.contains('📞')) return AppColors.success;
    return AppColors.textDark;
  }

  FontWeight _getStepFontWeight(String step) {
    if (step.contains('URGENT') || step.contains('🚨')) return FontWeight.bold;
    return FontWeight.normal;
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'autism':
        return 'Autism Spectrum';
      case 'adhd':
      case 'adhd_inattention':
        return 'ADHD - Inattention';
      case 'adhd_hyperactive':
        return 'ADHD - Hyperactivity';
      case 'speech':
        return 'Speech/Language';
      default:
        return category.split('_').map((word) =>
        word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  String _formatConcernName(String concern) {
    return concern.split('_').map((word) =>
    word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _getScoreText(String category, Map<String, dynamic> scoreData) {
    if (category == 'autism') {
      return 'Total: ${scoreData['total']}, Critical: ${scoreData['critical']}';
    } else if (category == 'adhd') {
      return 'Inattention: ${scoreData['inattention']}, Hyperactive: ${scoreData['hyperactive']}';
    } else if (category == 'speech') {
      return 'Score: ${scoreData['total']}';
    }
    return '';
  }

  String _formatScoreData(Map<String, dynamic> scoreData) {
    return scoreData.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'medium':
      case 'moderate':
        return AppColors.warning;
      case 'significant':
        return AppColors.error;
      case 'mild':
        return Colors.yellow[700]!;
      case 'low':
      case 'none':
        return AppColors.success;
      default:
        return AppColors.textLight;
    }
  }

  IconData _getRiskIcon(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  String _getRiskTitle(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return 'High Risk Detected';
      case 'medium':
        return 'Moderate Risk';
      default:
        return 'Low Risk';
    }
  }

  String _getOverallRiskMessage(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return 'Professional evaluation is strongly recommended. Please consult with healthcare providers as soon as possible.';
      case 'medium':
        return 'Follow-up monitoring is recommended. Consider discussing these results with your pediatrician.';
      default:
        return 'Your child appears to be developing typically for their age. Continue with routine developmental check-ups.';
    }
  }

  String _getRiskDescription(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return 'Professional evaluation recommended';
      case 'medium':
      case 'moderate':
        return 'Monitor and follow up';
      case 'significant':
        return 'Immediate evaluation needed';
      case 'mild':
        return 'Continue monitoring';
      case 'none':
        return 'No concerns detected';
      case 'low':
        return 'Low risk - typical development';
      default:
        return risk;
    }
  }
}