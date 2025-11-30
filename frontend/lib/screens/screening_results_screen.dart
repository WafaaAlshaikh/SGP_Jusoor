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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Screening Results',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textWhite,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Risk Card - Most Important First
            _buildOverallRiskCard(),
            const SizedBox(height: 24),

            // Primary Concern
            if (widget.results.primaryConcern != null)
              _buildPrimaryConcernCard(),

            const SizedBox(height: 24),

            // Enhanced Analysis Toggle Section
            if (_showEnhancedAnalysis &&
                widget.results.enhancedAnalysis != null &&
                widget.results.enhancedAnalysis!.success)
              _buildEnhancedAnalysisSection(),

            // Detailed Results by Category
            _buildDetailedResultsSection(),

            const SizedBox(height: 24),

            // Red Flags
            if (widget.results.redFlags.isNotEmpty)
              _buildRedFlagsCard(),

            const SizedBox(height: 24),

            // Positive Indicators
            if (widget.results.positiveIndicators.isNotEmpty)
              _buildPositiveIndicatorsCard(),

            const SizedBox(height: 24),

            // Smart Next Steps
            if (widget.results.enhancedAnalysis?.nextSteps != null &&
                widget.results.enhancedAnalysis!.nextSteps.isNotEmpty)
              _buildSmartNextStepsCard(),

            const SizedBox(height: 24),

            // Scores Summary
            if (widget.scores != null)
              _buildScoresCard(),

            const SizedBox(height: 24),

            // AI Recommendations
            if (_hasAIRecommendations())
              _buildAIRecommendationsCard(),

            const SizedBox(height: 32),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallRiskCard() {
    final overallRisk = widget.results.overallRisk;
    final color = _getRiskColor(overallRisk);
    final message = _getOverallRiskMessage(overallRisk);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.9),
            color.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.textWhite.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getRiskIcon(overallRisk),
              size: 40,
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _getRiskTitle(overallRisk),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textWhite,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textWhite,
                height: 1.5,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.textWhite.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              'Confidence: ${widget.results.confidenceLevel.toUpperCase()}',
              style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPrimaryConcernCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Primary Concern',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.results.primaryConcernLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
                fontFamily: 'Inter',
              ),
            ),
          ),
          if (widget.results.secondaryConcern != null) ...[
            const SizedBox(height: 12),
            Text(
              'Secondary Concern: ${_formatConcernName(widget.results.secondaryConcern!)}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textGray,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Detailed Assessment',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              fontFamily: 'Inter',
            ),
          ),
        ),
        ...widget.results.riskLevels.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
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

  Widget _buildCategoryResultCard({
    required String title,
    required String riskLevel,
    required Color color,
    required String category,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: AppColors.accent2,
          width: 1,
        ),
      ),
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
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontFamily: 'Inter',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Text(
                  _getRiskDescription(riskLevel),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                    fontFamily: 'Inter',
                  ),
                ),
                if (widget.scores != null && widget.scores![category] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      _getScoreText(category, widget.scores![category]),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontFamily: 'Inter',
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
                fontWeight: FontWeight.w700,
                fontSize: 11,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedAnalysisSection() {
    final enhanced = widget.results.enhancedAnalysis!;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: AppColors.accent1,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.info,
                          AppColors.primaryLight,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: AppColors.textWhite,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AI Analysis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getUrgencyColor(enhanced.urgencyLevel),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      enhanced.urgencyLevel.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // AI Suggested Conditions
              if (enhanced.aiAnalysis != null &&
                  enhanced.aiAnalysis!.suggestedConditions.isNotEmpty)
                _buildAISuggestedConditions(enhanced.aiAnalysis!),

              const SizedBox(height: 20),

              // Recommended Institutions
              if (enhanced.recommendedInstitutions.isNotEmpty)
                _buildRecommendedInstitutions(enhanced.recommendedInstitutions),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAISuggestedConditions(AIAnalysis aiAnalysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Suggested Conditions:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 12),
        ...aiAnalysis.suggestedConditions.map((condition) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4, right: 12),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Confidence: ${condition.confidence}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textGray,
                          fontFamily: 'Inter',
                        ),
                      ),
                      if (condition.matchingKeywords.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            'Keywords: ${condition.matchingKeywords.join(', ')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                              fontFamily: 'Inter',
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
        )),
      ],
    );
  }

  Widget _buildRecommendedInstitutions(List<dynamic> institutions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended Centers:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 12),
        ...institutions.take(3).map((institution) {
          final inst = Map<String, dynamic>.from(institution);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent3),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inst['name'] ?? 'Unknown Center',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${inst['city'] ?? ''} • Match: ${inst['match_score'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                            fontFamily: 'Inter',
                          ),
                        ),
                        if (inst['matching_specialties'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Specialties: ${(inst['matching_specialties'] as List).join(', ')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (institutions.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '+ ${institutions.length - 3} more centers available',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontFamily: 'Inter',
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRedFlagsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Red Flags',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.results.redFlags.map((flag) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    flag,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPositiveIndicatorsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.success.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.thumb_up_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Positive Indicators',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.results.positiveIndicators.map((indicator) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    indicator,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSmartNextStepsCard() {
    final nextSteps = widget.results.enhancedAnalysis!.nextSteps;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.accent1,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryLight,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.textWhite,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Next Steps',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...nextSteps.map((step) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildScoresCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.accent2,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.assessment_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Score Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.scores!.entries.map((entry) {
            if (entry.value is Map) {
              return _buildScoreRow(entry.key, entry.value);
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String category, Map<String, dynamic> scoreData) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getCategoryTitle(category),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textDark,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _formatScoreData(scoreData),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.primaryDark,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendationsCard() {
    final recommendations = _getAIRecommendations();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.accent3,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.info,
                      AppColors.primaryLight,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.recommend_rounded,
                  color: AppColors.textWhite,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recommendations.asMap().entries.map((entry) {
            final recommendation = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.normal,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Main Next Steps Button
        Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primaryLight,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              _handleNextStepsAction(widget.results);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1_rounded, size: 24,color:AppColors.accent2),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Add Child for Follow-up',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: AppColors.textWhite,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Home Button
        SizedBox(
          width: double.infinity,
          height: 58,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              side: const BorderSide(color: AppColors.primary, width: 2),
              backgroundColor: AppColors.surface,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_rounded, size: 22),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Back to Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  // Helper Methods (keep the same as before)
  bool _hasAIRecommendations() {
    final enhanced = widget.results.enhancedAnalysis;
    if (enhanced == null || !enhanced.success) return false;
    if (enhanced.recommendations != null && enhanced.recommendations!.isNotEmpty) return true;
    if (enhanced.aiAnalysis?.recommendations != null && enhanced.aiAnalysis!.recommendations!.isNotEmpty) return true;
    return false;
  }

  List<String> _getAIRecommendations() {
    final enhanced = widget.results.enhancedAnalysis;
    if (enhanced == null) return [];
    if (enhanced.recommendations != null && enhanced.recommendations!.isNotEmpty) return enhanced.recommendations!;
    if (enhanced.aiAnalysis?.recommendations != null && enhanced.aiAnalysis!.recommendations!.isNotEmpty) return enhanced.aiAnalysis!.recommendations!;
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
      case 'high': return Icons.warning_amber_rounded;
      case 'medium': return Icons.monitor_heart_rounded;
      default: return Icons.thumb_up_rounded;
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
    if (step.contains('URGENT') || step.contains('🚨')) return Icons.warning_amber_rounded;
    if (step.contains('Recommended') || step.contains('🏫')) return Icons.recommend_rounded;
    if (step.contains('Contact') || step.contains('📞')) return Icons.phone_rounded;
    return Icons.arrow_forward_ios_rounded;
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
      case 'autism': return 'Autism Spectrum';
      case 'adhd': return 'ADHD - Inattention';
      case 'adhd_hyperactive': return 'ADHD - Hyperactivity';
      case 'speech': return 'Speech/Language';
      default: return category.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  String _formatConcernName(String concern) {
    return concern.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  String _getScoreText(String category, Map<String, dynamic> scoreData) {
    if (category == 'autism') return 'Total: ${scoreData['total']}, Critical: ${scoreData['critical']}';
    if (category == 'adhd') return 'Inattention: ${scoreData['inattention']}, Hyperactive: ${scoreData['hyperactive']}';
    if (category == 'speech') return 'Score: ${scoreData['total']}';
    return '';
  }

  String _formatScoreData(Map<String, dynamic> scoreData) {
    return scoreData.entries.where((e) => e.value != null).map((e) => '${e.key}: ${e.value}').join(', ');
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return AppColors.error;
      case 'medium': return AppColors.warning;
      case 'significant': return AppColors.error;
      case 'mild': return Colors.yellow[700]!;
      case 'low': return AppColors.success;
      default: return AppColors.textLight;
    }
  }

  IconData _getRiskIcon(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return Icons.warning_amber_rounded;
      case 'medium': return Icons.info_outline_rounded;
      default: return Icons.check_circle_rounded;
    }
  }

  String _getRiskTitle(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return 'High Risk Detected';
      case 'medium': return 'Moderate Risk';
      default: return 'Low Risk';
    }
  }

  String _getOverallRiskMessage(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return 'Professional evaluation is recommended. Please consult healthcare providers.';
      case 'medium':
        return 'Follow-up monitoring is recommended. Discuss with pediatrician.';
      default:
        return 'Continue with routine check-ups.';
    }
  }

  String _getRiskDescription(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return 'Professional evaluation recommended';
      case 'medium': return 'Monitor and follow up';
      case 'significant': return 'Immediate evaluation needed';
      case 'mild': return 'Continue monitoring';
      case 'none': return 'No concerns detected';
      case 'low': return 'Low risk - typical development';
      default: return risk;
    }
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
    if (results.primaryConcern != null) symptoms += '• Primary indicator: ${results.primaryConcernLabel}\n';
    if (results.riskLevels.isNotEmpty) {
      symptoms += '• Risk levels:\n';
      results.riskLevels.forEach((key, value) {
        symptoms += '   - ${_getCategoryTitle(key)}: $value\n';
      });
    }
    if (results.redFlags.isNotEmpty) {
      symptoms += '• Warning signs:\n';
      for (var flag in results.redFlags) symptoms += '   - $flag\n';
    }
    if (results.scores.isNotEmpty) {
      symptoms += '\n• Detailed results:\n';
      results.scores.forEach((key, value) {
        if (value is Map) symptoms += '   - ${_getCategoryTitle(key)}: ${value.toString()}\n';
      });
    }
    return symptoms;
  }

  String _generateScreeningNotes(ScreeningResults results) {
    return 'This data was automatically generated from the initial screening. Please review the information and verify its accuracy before submitting.';
  }
}