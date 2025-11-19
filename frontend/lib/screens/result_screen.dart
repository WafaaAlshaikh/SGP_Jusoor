// screens/questionnaire/results_screen.dart
import 'package:flutter/material.dart';
import '../models/screening_models.dart';
import 'start_screening_screen.dart';

class ResultsScreen extends StatelessWidget {
  final Map<String, dynamic> results;

  const ResultsScreen({Key? key, required this.results}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final riskLevels = results['risk_levels'] as Map<String, dynamic>;
    final scores = results['scores'] as Map<String, dynamic>;
    final recommendations = results['recommendations'] as List<dynamic>;
    final nextSteps = results['next_steps'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening Results'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 30),
            
            // Risk Levels
            _buildRiskLevelsSection(riskLevels, scores),
            const SizedBox(height: 30),
            
            // Recommendations
            _buildRecommendationsSection(recommendations),
            const SizedBox(height: 30),
            
            // Next Steps
            _buildNextStepsSection(nextSteps),
            const SizedBox(height: 40),
            
            // Action Buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_turned_in,
            size: 50,
            color: Colors.blue[700],
          ),
          const SizedBox(height: 10),
          Text(
            'Screening Completed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Based on your responses, here are the results and recommendations',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskLevelsSection(Map<String, dynamic> riskLevels, Map<String, dynamic> scores) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Risk Assessment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          
          // ASD Risk
          _buildRiskItem(
            title: 'Autism Spectrum (ASD)',
            riskLevel: riskLevels['asd'].toString(),
            score: scores['asd'],
          ),
          const SizedBox(height: 15),
          
          // ADHD Risk
          _buildRiskItem(
            title: 'ADHD',
            riskLevel: riskLevels['adhd'].toString(),
            score: scores['adhd'],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskItem({required String title, required String riskLevel, required int score}) {
    Color riskColor;
    String riskText;
    IconData riskIcon;

    switch (riskLevel) {
      case 'high':
        riskColor = Colors.red;
        riskText = 'High Risk';
        riskIcon = Icons.warning;
        break;
      case 'medium':
        riskColor = Colors.orange;
        riskText = 'Medium Risk';
        riskIcon = Icons.info;
        break;
      case 'low':
      default:
        riskColor = Colors.green;
        riskText = 'Low Risk';
        riskIcon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: riskColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(riskIcon, color: riskColor, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  riskText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Score: $score',
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
    );
  }

  Widget _buildRecommendationsSection(List<dynamic> recommendations) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
              const SizedBox(width: 10),
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
          const SizedBox(height: 15),
          ...recommendations.map((recommendation) => _buildListItem(recommendation.toString())).toList(),
        ],
      ),
    );
  }

  Widget _buildNextStepsSection(List<dynamic> nextSteps) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_walk, color: Colors.green[700]),
              const SizedBox(width: 10),
              Text(
                'Next Steps',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...nextSteps.map((step) => _buildListItem(step.toString())).toList(),
        ],
      ),
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              // Save or share results
              _showSaveDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Save Results',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(color: Colors.blue[700]!),
            ),
            child: Text(
              'Back to Dashboard',
              style: TextStyle(fontSize: 18, color: Colors.blue[700]),
            ),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: TextButton(
            onPressed: () {
              // Start new screening
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StartScreeningScreen()),
              );
            },
            child: Text(
              'Start New Screening',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Results'),
        content: const Text('Your screening results have been saved to your history. You can view them anytime in your dashboard.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Example of how to use it in the questionnaire flow:
class ResultsPreview extends StatelessWidget {
  const ResultsPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This is just for testing - remove in production
    final sampleResults = {
      'risk_levels': {'asd': 'medium', 'adhd': 'low'},
      'scores': {'asd': 5, 'adhd': 3},
      'recommendations': [
        'We recommend follow-up with pediatrician and re-evaluation in 3 months',
        'Monitor development and school performance',
        'Consider speech and language evaluation if concerns persist'
      ],
      'next_steps': [
        'Schedule appointment with pediatrician',
        'Monitor social interactions',
        'Observe classroom behavior if applicable'
      ]
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Results Preview')),
      body: ResultsScreen(results: sampleResults),
    );
  }
}