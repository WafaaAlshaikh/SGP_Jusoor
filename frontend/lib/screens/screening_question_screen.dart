import 'package:flutter/material.dart';
import '../services/screening_service.dart';
import '../models/screening_models.dart';
import 'screening_results_screen.dart';
import '../theme/app_colors.dart';

class ScreeningQuestionScreen extends StatefulWidget {
  final String sessionId;
  final List<ScreeningQuestion> initialQuestions;
  final int progress;
  final String? phase;
  final String? phaseMessage;

  const ScreeningQuestionScreen({
    Key? key,
    required this.sessionId,
    required this.initialQuestions,
    required this.progress,
    this.phase,
    this.phaseMessage,
  }) : super(key: key);

  @override
  State<ScreeningQuestionScreen> createState() => _ScreeningQuestionScreenState();
}

class _ScreeningQuestionScreenState extends State<ScreeningQuestionScreen> {
  late List<ScreeningQuestion> _questions;
  int _currentQuestionIndex = 0;
  dynamic _selectedAnswer;
  bool _isLoading = false;
  int _progress = 0;
  bool _hasError = false;
  String _currentPhase = 'initial';
  int _totalAnswered = 0;

  @override
  void initState() {
    super.initState();
    _questions = widget.initialQuestions;
    _progress = widget.progress;
    _currentPhase = widget.phase ?? 'initial';

    if (widget.phaseMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPhaseMessage(widget.phaseMessage!);
      });
    }

    if (_questions.isEmpty) {
      _hasError = true;
    }
  }

  void _showPhaseMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textWhite),
            SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: AppColors.textWhite))),
          ],
        ),
        backgroundColor: _getPhaseColor(),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ScreeningService.submitAnswer(
        sessionId: widget.sessionId,
        questionId: _questions[_currentQuestionIndex].id,
        answer: _selectedAnswer,
      );

      if (response['success'] == true) {
        if (response['completed'] == true) {
          _navigateToResults(response);
        } else {
          _handleNextQuestion(response);
        }
      } else {
        _showErrorDialog(response['message'] ?? 'Failed to submit answer');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToResults(Map<String, dynamic> response) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ScreeningResultsScreen(
          sessionId: widget.sessionId,
          results: ScreeningResults.fromJson(response['results']),
          scores: response['scores'],
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _handleNextQuestion(Map<String, dynamic> response) {
    final nextQuestionData = response['next_question'];
    final newPhase = response['phase'] ?? response['new_phase'];
    final phaseMessage = response['phase_message'];

    if (nextQuestionData != null) {
      if (newPhase != null && newPhase != _currentPhase && phaseMessage != null) {
        _showPhaseMessage(phaseMessage);
      }

      setState(() {
        _currentQuestionIndex = 0;
        _questions = [ScreeningQuestion.fromJson(nextQuestionData)];
        _selectedAnswer = null;
        _progress = response['progress'] ?? _progress + 5;
        _currentPhase = newPhase ?? _currentPhase;
        _totalAnswered = response['answered_questions'] ?? _totalAnswered + 1;
        _isLoading = false;
        _hasError = false;
      });
    } else {
      _fetchFinalResults();
    }
  }

  Future<void> _fetchFinalResults() async {
    try {
      final resultsResponse = await ScreeningService.getResults(widget.sessionId);
      if (mounted && resultsResponse['success'] == true) {
        _navigateToResults(resultsResponse);
      }
    } catch (e) {
      _showErrorDialog('Failed to get results: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.warning),
              SizedBox(height: 16),
              Text(
                'Oops!',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textGray),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.textWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Try Again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerOption(Map<String, dynamic> choice, IconData icon) {
    final isSelected = _selectedAnswer == choice['value'];
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? _getPhaseColor().withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _getPhaseColor() : AppColors.accent3,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: _getPhaseColor().withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 1),
          )
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? _getPhaseColor().withOpacity(0.1) : AppColors.accent1,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected ? _getPhaseColor() : AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          choice['text']?.toString() ?? 'No text',
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? _getPhaseColor() : AppColors.textDark,
          ),
        ),
        trailing: isSelected ? Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _getPhaseColor(),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            color: AppColors.textWhite,
            size: 16,
          ),
        ) : null,
        onTap: () {
          setState(() {
            _selectedAnswer = choice['value'];
          });
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildBinaryQuestion() {
    final choices = _questions[_currentQuestionIndex].choices;
    
    if (choices.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildAnswerOption(choices[0], Icons.check_circle_outline),
        _buildAnswerOption(choices[1], Icons.cancel_outlined),
      ],
    );
  }

  Widget _buildScaleQuestion() {
    final choices = _questions[_currentQuestionIndex].choices;
    final icons = [
      Icons.sentiment_very_satisfied,
      Icons.sentiment_satisfied,
      Icons.sentiment_neutral,
      Icons.sentiment_dissatisfied,
    ];

    if (choices.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: List.generate(choices.length, (index) {
        return _buildAnswerOption(
          choices[index],
          index < icons.length ? icons[index] : Icons.circle,
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.textLight),
          SizedBox(height: 16),
          Text(
            'No options available',
            style: TextStyle(fontSize: 18, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent() {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return _buildErrorState();
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    switch (currentQuestion.type) {
      case 'binary':
        return _buildBinaryQuestion();
      case 'scale':
        return _buildScaleQuestion();
      default:
        return _buildBinaryQuestion();
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: AppColors.error),
          SizedBox(height: 20),
          Text(
            'No questions available',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: AppColors.textDark
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Please try starting the screening again',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textGray),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back),
            label: Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseLabel() {
    switch (_currentPhase) {
      case 'initial':
        return 'Initial Screening';
      case 'detailed':
        return 'Detailed Assessment';
      case 'performance':
        return 'Performance Evaluation';
      default:
        return 'Child Development Screening';
    }
  }

  Color _getPhaseColor() {
    switch (_currentPhase) {
      case 'initial':
        return AppColors.primary;
      case 'detailed':
        return AppColors.info;
      case 'performance':
        return AppColors.primaryLight;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: 14, 
                  color: AppColors.textGray, 
                  fontWeight: FontWeight.w500
                ),
              ),
              Text(
                '$_progress%',
                style: TextStyle(
                  fontSize: 14, 
                  color: _getPhaseColor(), 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: _progress / 100,
            backgroundColor: AppColors.accent1,
            color: _getPhaseColor(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPhaseColor().withOpacity(0.9),
            _getPhaseColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getPhaseColor().withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assessment_outlined, size: 16, color: AppColors.textWhite),
          SizedBox(width: 6),
          Text(
            _getPhaseLabel(),
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionHeader() {
    final currentQuestion = _questions[_currentQuestionIndex];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${_totalAnswered + 1}',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Text(
            currentQuestion.text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),
          if (currentQuestion.isCritical)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Important question for accurate assessment',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Screening',
            style: TextStyle(color: AppColors.textWhite),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: true,
        ),
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _getPhaseLabel(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textWhite,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Section
              _buildProgressIndicator(),
              SizedBox(height: 20),
              
              // Phase Badge
              Center(child: _buildPhaseBadge()),
              SizedBox(height: 24),

              // Question Header
              _buildQuestionHeader(),
              SizedBox(height: 24),

              // Question Options
              Expanded(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: _buildQuestionContent(),
                ),
              ),

              SizedBox(height: 20),

              // Next Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedAnswer != null && !_isLoading
                      ? _submitAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getPhaseColor(),
                    foregroundColor: AppColors.textWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppColors.textLight,
                    elevation: 2,
                    shadowColor: _getPhaseColor().withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.textWhite),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}