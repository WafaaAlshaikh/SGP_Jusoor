// screens/screening_question_screen.dart
import 'package:flutter/material.dart';
import '../services/screening_service.dart';
import '../models/screening_models.dart';
import 'screening_results_screen.dart';

class ScreeningQuestionScreen extends StatefulWidget {
  final String sessionId;
  final List<ScreeningQuestion> initialQuestions;
  final int progress;

  const ScreeningQuestionScreen({
    Key? key,
    required this.sessionId,
    required this.initialQuestions,
    required this.progress,
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

  @override
  void initState() {
    super.initState();
    _questions = widget.initialQuestions;
    _progress = widget.progress;

    // Check if questions are empty
    if (_questions.isEmpty) {
      _hasError = true;
    }
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
          // Screening completed, show results
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ScreeningResultsScreen(
                  sessionId: widget.sessionId,
                  results: ScreeningResults.fromJson(response['results']),
                ),
              ),
            );
          }
        } else {
          // Continue with next question
          final nextQuestionData = response['next_question'];
          if (nextQuestionData != null) {
            setState(() {
              _currentQuestionIndex = 0;
              _questions = [ScreeningQuestion.fromJson(nextQuestionData)];
              _selectedAnswer = null;
              _progress = response['progress'] ?? _progress + 10;
              _isLoading = false;
              _hasError = false;
            });
          } else {
            // No more questions, show results
            final resultsResponse = await ScreeningService.getResults(widget.sessionId);
            if (mounted && resultsResponse['success'] == true) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ScreeningResultsScreen(
                    sessionId: widget.sessionId,
                    results: ScreeningResults.fromJson(resultsResponse['results']),
                  ),
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          _showErrorDialog(response['message'] ?? 'Failed to submit answer');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Network error: $e');
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
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

  Widget _buildBinaryQuestion() {
    final choices = _questions[_currentQuestionIndex].choices;

    // Check if choices is empty
    if (choices.isEmpty) {
      return const Center(
        child: Text('No answer options available'),
      );
    }

    return Column(
      children: [
        for (final choice in choices)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              title: Text(choice['text']?.toString() ?? 'No text'),
              leading: Radio<dynamic>(
                value: choice['value'],
                groupValue: _selectedAnswer,
                onChanged: (value) {
                  setState(() {
                    _selectedAnswer = value;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  _selectedAnswer = choice['value'];
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildScaleQuestion() {
    final choices = _questions[_currentQuestionIndex].choices;

    // Check if choices is empty
    if (choices.isEmpty) {
      return const Center(
        child: Text('No answer options available'),
      );
    }

    return Column(
      children: [
        for (final choice in choices)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              title: Text(choice['text']?.toString() ?? 'No text'),
              leading: Radio<dynamic>(
                value: choice['value'],
                groupValue: _selectedAnswer,
                onChanged: (value) {
                  setState(() {
                    _selectedAnswer = value;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  _selectedAnswer = choice['value'];
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionContent() {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'No questions available',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text(
              'Please try starting the screening again',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    // If no questions available, show error
    if (_hasError || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Screening Questions'),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'No questions available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'There are no questions available for this age group.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening Questions'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('$_progress%'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: Colors.grey[300],
              color: Colors.blue[700],
            ),
            const SizedBox(height: 20),

            // Question Number
            Text(
              'Question ${_currentQuestionIndex + 1}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Question Text
            Text(
              currentQuestion.text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            if (currentQuestion.isCritical)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 5),
                    Text(
                      'Critical question for assessment',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // Question Options
            Expanded(
              child: _buildQuestionContent(),
            ),

            const SizedBox(height: 20),

            // Next Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedAnswer != null && !_isLoading
                    ? _submitAnswer
                    : null,
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
                  'Next Question',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}