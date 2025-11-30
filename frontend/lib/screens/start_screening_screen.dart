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
                  content: Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
        title: Text(
          'Error',
          style: TextStyle(
            color: AppColors.error,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.textDark,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColors.primary,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
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
        title: Text(
          'Initial Screening',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textWhite,
            fontFamily: 'Inter',
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Child Information',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'Inter',
                        height: 1.2,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please provide basic information about your child to start the developmental screening.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textGray,
                        height: 1.5,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Age Input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Child Age (in months)',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g., 24 for 2 years old',
                        hintStyle: TextStyle(
                          color: AppColors.textLight,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        prefixIcon: Icon(Icons.cake_rounded, color: AppColors.primary, size: 24),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                  const SizedBox(height: 8),
                  Text(
                    'Enter age between 16-180 months',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              // Age Group Info
              if (_ageController.text.isNotEmpty)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(top: 12.0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getAgeGroupInfo(_ageController.text),
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Gender Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Child Gender (Optional)',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      ),
                      dropdownColor: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 28),
                      items: _genders.map((gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              gender == 'male' ? 'Male' : 'Female',
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
                ],
              ),
              const SizedBox(height: 36),

              // Information Cards Section
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'What We Screen For:',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    fontFamily: 'Inter',
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              _buildInfoCard(
                icon: Icons.psychology_rounded,
                title: 'Autism Screening',
                description: 'M-CHAT for ages 16-30 months\nEarly detection of autism spectrum signs',
                color: AppColors.accent1,
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.record_voice_over_rounded,
                title: 'Speech Development',
                description: 'Language milestones for ages 2.5-5 years\nExpressive and receptive language skills',
                color: AppColors.accent2,
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.directions_run_rounded,
                title: 'ADHD Screening',
                description: 'Vanderbilt scale for children 6+ years\nInattention and hyperactivity assessment',
                color: AppColors.accent3,
              ),
              const SizedBox(height: 36),

              // Important Note
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_rounded, color: AppColors.warning, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'This screening adapts to your answers. You may be asked 5-30 questions depending on the results. The assessment takes 5-15 minutes.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 14,
                          height: 1.5,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Start Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startScreening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    disabledBackgroundColor: AppColors.textLight,
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation(AppColors.textWhite),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start Screening',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded, size: 22),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: AppColors.primary),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      fontFamily: 'Inter',
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                      height: 1.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
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