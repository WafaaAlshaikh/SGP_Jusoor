// screens/screening_results_screen.dart
import 'package:flutter/material.dart';
import '../services/screening_service.dart';
import '../models/screening_models.dart';

class ScreeningResultsScreen extends StatefulWidget {
  final String sessionId;
  final ScreeningResults results;

  const ScreeningResultsScreen({
    Key? key,
    required this.sessionId,
    required this.results,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Risk Card
            _buildOverallRiskCard(),
            const SizedBox(height: 20),

            // Detailed Results
            _buildResultCard(
              title: 'Autism Screening',
              riskLevel: widget.results.autismRisk,
              color: _getRiskColor(widget.results.autismRisk),
            ),
            const SizedBox(height: 15),

            _buildResultCard(
              title: 'ADHD Screening',
              riskLevel: widget.results.adhdRisk,
              color: _getRiskColor(widget.results.adhdRisk),
            ),
            const SizedBox(height: 15),

            _buildResultCard(
              title: 'Speech Development',
              riskLevel: widget.results.speechDelay,
              color: _getSpeechDelayColor(widget.results.speechDelay),
            ),
            const SizedBox(height: 20),

            // Recommendations
            _buildRecommendationsCard(),
            const SizedBox(height: 20),

            // Next Steps
            _buildNextStepsCard(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String riskLevel,
    required Color color,
  }) {
    return Card(
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    return Card(
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
                  Expanded(child: Text(recommendation)),
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
                  Expanded(child: Text(step)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Back to Home'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              // Share results functionality
            },
            child: const Text('Share Results'),
          ),
        ),
      ],
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'significant':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.yellow[700]!;
      default:
        return Colors.green;
    }
  }

  Color _getSpeechDelayColor(String delay) {
    switch (delay) {
      case 'significant':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.yellow[700]!;
      default:
        return Colors.green;
    }
  }

  IconData _getRiskIcon(String risk) {
    switch (risk) {
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  String _getRiskTitle(String risk) {
    switch (risk) {
      case 'high':
        return 'High Risk Detected';
      case 'medium':
        return 'Moderate Risk';
      default:
        return 'Low Risk';
    }
  }

  String _getOverallRiskMessage(String risk) {
    switch (risk) {
      case 'high':
        return 'Professional evaluation is strongly recommended. Please consult with healthcare providers.';
      case 'medium':
        return 'Follow-up monitoring is recommended. Consider discussing results with your pediatrician.';
      default:
        return 'Your child appears to be developing typically. Continue with routine check-ups.';
    }
  }

  String _getRiskDescription(String risk) {
    switch (risk) {
      case 'high':
        return 'Professional evaluation recommended';
      case 'medium':
        return 'Monitor and follow up';
      case 'significant':
        return 'Immediate evaluation needed';
      case 'moderate':
        return 'Assessment recommended';
      case 'mild':
        return 'Continue monitoring';
      case 'none':
        return 'No concerns detected';
      default:
        return 'Low risk';
    }
  }
}