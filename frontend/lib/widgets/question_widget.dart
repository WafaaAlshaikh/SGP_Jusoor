// screens/questionnaire/question_widget.dart
import 'package:flutter/material.dart';
import '../models/screening_models.dart';

class QuestionWidget extends StatelessWidget {
  final ScreeningQuestion question;
  final Function(dynamic) onAnswer;

  const QuestionWidget({
    super.key, // استخدم super.key هنا أيضاً
    required this.question,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.questionText,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 30),
        
        if (question.questionType == 'yes_no') _buildYesNoButtons(),
        if (question.questionType == 'scale') _buildScaleButtons(),
        if (question.questionType == 'performance') _buildPerformanceButtons(),
      ],
    );
  }

  Widget _buildYesNoButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ElevatedButton(
              onPressed: () => onAnswer(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                'YES',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ElevatedButton(
              onPressed: () => onAnswer(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                'NO',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScaleButtons() {
    final choices = question.options?['choices'] as List? ?? ['Never', 'Occasionally', 'Often', 'Very Often'];
    
    return Column(
      children: choices.map((choice) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onAnswer(choice),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                choice.toString(),
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPerformanceButtons() {
    return _buildScaleButtons();
  }
}