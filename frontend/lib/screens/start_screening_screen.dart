// screens/start_screening_screen.dart - التحديث الكامل
import 'package:flutter/material.dart';
import '../services/screening_service.dart';
import '../models/screening_models.dart';
import 'screening_question_screen.dart';
import '../theme/app_colors.dart';

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
          final phase = response['phase'];
          final message = response['message'];

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
                  backgroundColor: AppColors.success,
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
        title: const Text('Error', style: TextStyle(color: AppColors.error)),
        content: Text(message, style: const TextStyle(color: AppColors.textDark)),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Initial Screening',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Child Information',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please provide basic information about your child to start the developmental screening.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textGray,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Age Input
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Child Age (in months)',
                    labelStyle: TextStyle(color: AppColors.textDark),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    prefixIcon: Icon(Icons.cake, color: AppColors.primary),
                    hintText: 'e.g., 24 for 2 years old',
                    helperText: 'Enter age between 16-180 months',
                    helperStyle: TextStyle(color: AppColors.textGray),
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
                    setState(() {});
                  },
                ),
              ),

              // Age Group Info
              if (_ageController.text.isNotEmpty)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(top: 8.0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryLight),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getAgeGroupInfo(_ageController.text),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Gender Dropdown
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Child Gender (Optional)',
                    labelStyle: TextStyle(color: AppColors.textDark),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    prefixIcon: Icon(Icons.person, color: AppColors.primary),
                  ),
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textDark, fontSize: 16),
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
              ),
              const SizedBox(height: 30),

              // Information Cards Section
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'What We Screen For:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),

              _buildInfoCard(
                icon: Icons.psychology,
                title: 'Autism Screening',
                description: 'M-CHAT for ages 16-30 months\nEarly detection of autism spectrum signs',
                color: AppColors.accent1,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.record_voice_over,
                title: 'Speech Development',
                description: 'Language milestones for ages 2.5-5 years\nExpressive and receptive language skills',
                color: AppColors.accent2,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.directions_run,
                title: 'ADHD Screening',
                description: 'Vanderbilt scale for children 6+ years\nInattention and hyperactivity assessment',
                color: AppColors.accent3,
              ),
              const SizedBox(height: 30),

              // Important Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This screening adapts to your answers. You may be asked 5-30 questions depending on the results. The assessment takes 5-15 minutes.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 14,
                          height: 1.4,
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
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startScreening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.primary.withOpacity(0.3),
                    disabledBackgroundColor: AppColors.textLight,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.textWhite),
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start Screening',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
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
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 24, color: AppColors.primary),
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
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                      height: 1.4,
                    ),
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