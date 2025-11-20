// screens/screening_results_screen.dart
import 'package:flutter/material.dart';
import '../models/screening_models.dart';

class ScreeningResultsScreen extends StatefulWidget {
  final String sessionId;
  final ScreeningResults results;
  final Map<String, dynamic>? scores;

  const ScreeningResultsScreen({
    Key? key,
    required this.sessionId,
    required this.results,
    this.scores,
  }) : super(key: key);

  @override
  State<ScreeningResultsScreen> createState() => _ScreeningResultsScreenState();
}

class _ScreeningResultsScreenState extends State<ScreeningResultsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening Results'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Risk Card
            _buildOverallRiskCard(),
            const SizedBox(height: 20),

            // Primary Concern (NEW)
            if (widget.results.primaryConcern != null)
              _buildPrimaryConcernCard(),

            const SizedBox(height: 20),

            // Detailed Results by Category
            const Text(
              'Detailed Results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),

            ...widget.results.riskLevels.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: _buildResultCard(
                  title: _getCategoryTitle(entry.key),
                  riskLevel: entry.value,
                  color: _getRiskColor(entry.value),
                  category: entry.key,
                ),
              );
            }).toList(),

            const SizedBox(height: 20),

            // Red Flags (NEW)
            if (widget.results.redFlags.isNotEmpty)
              _buildRedFlagsCard(),

            const SizedBox(height: 20),

            // Positive Indicators (NEW)
            if (widget.results.positiveIndicators.isNotEmpty)
              _buildPositiveIndicatorsCard(),

            const SizedBox(height: 20),

            // Recommendations
            _buildRecommendationsCard(),
            const SizedBox(height: 20),

            // Next Steps
            _buildNextStepsCard(),

            const SizedBox(height: 20),

            // Scores Summary (NEW)
            if (widget.scores != null)
              _buildScoresCard(),

            const SizedBox(height: 30),

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

    return Card(
      color: color.withOpacity(0.1),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              _getRiskIcon(overallRisk),
              size: 60,
              color: color,
            ),
            const SizedBox(height: 10),
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
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
      color: Colors.orange[50],
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Primary Concern',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.results.primaryConcernLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.results.secondaryConcern != null) ...[
              const SizedBox(height: 10),
              Text(
                'Secondary Concern: ${_formatConcernName(widget.results.secondaryConcern!)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String riskLevel,
    required Color color,
    required String category,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _getRiskDescription(riskLevel),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  // Show scores if available
                  if (widget.scores != null && widget.scores![category] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: Text(
                        _getScoreText(category, widget.scores![category]),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Chip(
              backgroundColor: color.withOpacity(0.2),
              label: Text(
                riskLevel.toUpperCase(),
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

  Widget _buildRedFlagsCard() {
    return Card(
      color: Colors.red[50],
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text(
                  'Red Flags',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...widget.results.redFlags.map((flag) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(flag)),
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
      color: Colors.green[50],
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.thumb_up, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Positive Indicators',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...widget.results.positiveIndicators.map((indicator) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(indicator)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommendations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.results.recommendations.isEmpty)
              const Text('No specific recommendations at this time.'),
            ...widget.results.recommendations.map((recommendation) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: const TextStyle(fontSize: 15),
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

  Widget _buildNextStepsCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next Steps',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.results.nextSteps.isEmpty)
              const Text('Continue with routine developmental monitoring.'),
            ...widget.results.nextSteps.map((step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_forward, color: Colors.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(fontSize: 15),
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
      color: Colors.grey[100],
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Score Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...widget.scores!.entries.map((entry) {
              if (entry.value is Map) {
                return _buildScoreRow(entry.key, entry.value);
              }
              return const SizedBox.shrink();
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String category, Map<String, dynamic> scoreData) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getCategoryTitle(category),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatScoreData(scoreData),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.home),
            label: const Text(
              'Back to Home',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Share results functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share functionality coming soon'),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.share),
            label: const Text(
              'Share Results',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  // Helper Methods

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
        return category.toUpperCase();
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
        return Colors.red;
      case 'medium':
      case 'moderate':
        return Colors.orange;
      case 'significant':
        return Colors.red;
      case 'mild':
        return Colors.yellow[700]!;
      case 'low':
      case 'none':
        return Colors.green;
      default:
        return Colors.grey;
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