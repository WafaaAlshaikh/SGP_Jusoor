// screens/start_screening_screen.dart - التحديث الكامل
import 'package:flutter/material.dart';
import '../services/screening_service.dart';
import '../models/screening_models.dart';
import 'screening_question_screen.dart';

class StartScreeningScreen extends StatefulWidget {
  const StartScreeningScreen({Key? key}) : super(key: key);

  @override
  State<StartScreeningScreen> createState() => _StartScreeningScreenState();
}

class _StartScreeningScreenState extends State<StartScreeningScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;

  final List<String> _genders = ['male', 'female'];

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _startScreening() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('🎯 Starting screening process...');
        final response = await ScreeningService.startScreening(
          childAgeMonths: int.parse(_ageController.text),
          childGender: _selectedGender,
        );

        print('✅ Screening started successfully');
        print('📊 Response data: $response');

        if (response['success'] == true) {
          final questionsData = response['questions'];
          final sessionId = response['session_id'];
          final progress = response['progress'] ?? 0;
          final phase = response['phase']; // NEW
          final message = response['message']; // NEW

          print('📋 Session: $sessionId');
          print('📋 Phase: $phase');
          print('📋 Questions count: ${(questionsData as List).length}');

          if (questionsData is List && questionsData.isNotEmpty) {
            final questions = questionsData
                .map((q) => ScreeningQuestion.fromJson(q))
                .toList();

            print('✅ Parsed ${questions.length} questions');

            // Show welcome message
            if (message != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            // Navigate to questions
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ScreeningQuestionScreen(
                    sessionId: sessionId,
                    initialQuestions: questions,
                    progress: progress,
                    phase: phase,
                  ),
                ),
              );
            }
          } else {
            print('❌ No questions in response');
            _showErrorDialog('No questions available for this age group (${_ageController.text} months). Please try a different age.');
          }
        } else {
          print('❌ API returned error: ${response['message']}');
          _showErrorDialog(response['message'] ?? 'Failed to start screening');
        }
      } catch (e) {
        print('💥 Error in _startScreening: $e');
        _showErrorDialog('Error: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getAgeGroupInfo(String ageText) {
    final age = int.tryParse(ageText);
    if (age == null) return '';

    if (age >= 16 && age <= 30) {
      return 'M-CHAT Autism Screening (16-30 months)';
    } else if (age >= 31 && age <= 60) {
      return 'Mixed Developmental Screening (2.5-5 years)';
    } else if (age >= 61) {
      return 'Vanderbilt ADHD Assessment (6+ years)';
    }
    return 'Age must be at least 16 months';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Screening'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Child Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please provide basic information about your child to start the developmental screening.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),

              // Age Input
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Child Age (in months)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                  hintText: 'e.g., 24 for 2 years old',
                  helperText: 'Enter age between 16-180 months',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter child age';
                  }
                  final age = int.tryParse(value);
                  if (age == null || age < 16 || age > 180) {
                    return 'Please enter a valid age (16-180 months)';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // Refresh to show age group info
                },
              ),

              // Age Group Info
              if (_ageController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getAgeGroupInfo(_ageController.text),
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Gender Dropdown
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Child Gender (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: _genders.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(
                      gender == 'male' ? 'Male' : 'Female',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
              const SizedBox(height: 30),

              // Information Cards
              const Text(
                'What We Screen For:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              _buildInfoCard(
                icon: Icons.psychology,
                title: 'Autism Screening',
                description: 'M-CHAT for ages 16-30 months\nEarly detection of autism spectrum signs',
                color: Colors.orange[100]!,
              ),
              const SizedBox(height: 10),
              _buildInfoCard(
                icon: Icons.record_voice_over,
                title: 'Speech Development',
                description: 'Language milestones for ages 2.5-5 years\nExpressive and receptive language skills',
                color: Colors.green[100]!,
              ),
              const SizedBox(height: 10),
              _buildInfoCard(
                icon: Icons.directions_run,
                title: 'ADHD Screening',
                description: 'Vanderbilt scale for children 6+ years\nInattention and hyperactivity assessment',
                color: Colors.purple[100]!,
              ),
              const SizedBox(height: 30),

              // Important Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: Colors.amber[800]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This screening adapts to your answers. You may be asked 5-30 questions depending on the results. The assessment takes 5-15 minutes.',
                        style: TextStyle(
                          color: Colors.amber[900],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Start Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startScreening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : const Text(
                    'Start Screening',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      color: color,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: Colors.blue[700]),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}