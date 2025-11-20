import 'package:flutter/material.dart';
import '../services/screening_service.dart';
import '../models/screening_models.dart';
import 'screening_results_screen.dart';

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
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Oops!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
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
        color: isSelected ? _getPhaseColor().withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _getPhaseColor() : Colors.grey[300]!,
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
        leading: Icon(
          icon,
          color: isSelected ? _getPhaseColor() : Colors.grey[600],
          size: 24,
        ),
        title: Text(
          choice['text']?.toString() ?? 'No text',
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? _getPhaseColor() : Colors.grey[800],
          ),
        ),
        trailing: isSelected ? Icon(
          Icons.check_circle,
          color: _getPhaseColor(),
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
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No options available',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
          Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
          SizedBox(height: 20),
          Text(
            'No questions available',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          SizedBox(height: 12),
          Text(
            'Please try starting the screening again',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back),
            label: Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
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
        return Color(0xFF4F6BED);
      case 'detailed':
        return Color(0xFFFF6B35);
      case 'performance':
        return Color(0xFF9C27B0);
      default:
        return Color(0xFF4F6BED);
    }
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _progress / 100,
          backgroundColor: Colors.grey[200],
          color: _getPhaseColor(),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            Text(
              '$_progress%',
              style: TextStyle(fontSize: 14, color: _getPhaseColor(), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhaseBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPhaseColor().withOpacity(0.8),
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
          Icon(Icons.assessment_outlined, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text(
            _getPhaseLabel(),
            style: TextStyle(
              color: Colors.white,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question ${_totalAnswered + 1}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Text(
          currentQuestion.text,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
            height: 1.3,
          ),
        ),
        SizedBox(height: 12),
        if (currentQuestion.isCritical)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Important question for accurate assessment',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('Screening'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey[800],
          elevation: 0,
          centerTitle: true,
        ),
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _getPhaseLabel(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 2,
        centerTitle: true,
        shadowColor: Colors.black12,
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
              _buildPhaseBadge(),
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
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 2,
                    shadowColor: _getPhaseColor().withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
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