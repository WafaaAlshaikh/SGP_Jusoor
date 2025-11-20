// screens/start_screening_screen.dart
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

// screens/start_screening_screen.dart - تحديث _startScreening
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

        if (response['success'] == true) {
          final questionsData = response['questions'];
          print('📋 Questions data type: ${questionsData.runtimeType}');
          print('📋 Questions data: $questionsData');

          if (questionsData is List && questionsData.isNotEmpty) {
            final questions = questionsData
                .map((q) => ScreeningQuestion.fromJson(q))
                .toList();

            print('✅ Parsed ${questions.length} questions');

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ScreeningQuestionScreen(
                  sessionId: response['session_id'],
                  initialQuestions: questions,
                  progress: response['progress'] ?? 0,
                ),
              ),
            );
          } else {
            print('❌ No questions in response');
            _showErrorDialog('No questions available for this age group. Please try a different age.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Screening'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter child age';
                  }
                  final age = int.tryParse(value);
                  if (age == null || age < 1 || age > 180) {
                    return 'Please enter a valid age (1-180 months)';
                  }
                  return null;
                },
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
              _buildInfoCard(
                icon: Icons.psychology,
                title: 'Autism Screening',
                description: 'M-CHAT for ages 16-30 months',
                color: Colors.orange[100]!,
              ),
              const SizedBox(height: 10),
              _buildInfoCard(
                icon: Icons.record_voice_over,
                title: 'Speech Development',
                description: 'Language milestones for ages 2.5-5 years',
                color: Colors.green[100]!,
              ),
              const SizedBox(height: 10),
              _buildInfoCard(
                icon: Icons.directions_run,
                title: 'ADHD Screening',
                description: 'For children 6 years and older',
                color: Colors.purple[100]!,
              ),
              const SizedBox(height: 40),

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
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
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
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14),
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