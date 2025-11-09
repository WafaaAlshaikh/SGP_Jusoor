import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/questionnaire_model.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  List<Question> _questions = [];
  Map<String, dynamic> _responses = {};
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  String? _selectedChildId;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login again';
          _isLoading = false;
        });
        return;
      }

      final questions = await ApiService.getScreeningQuestions(
          token,
          childId: _selectedChildId,
          previousAnswers: _responses
      );

      setState(() {
        _questions = questions;
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      print('Error loading questions: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load questions: $e';
      });
    }
  }

  void _saveAnswer(String questionId, dynamic answer, String category) {
    setState(() {
      _responses[questionId] = {
        'answer': answer,
        'timestamp': DateTime.now().toIso8601String(),
        'category': category
      };
    });

    // الانتقال للسؤال التالي تلقائياً بعد ثانية
    Future.delayed(Duration(milliseconds: 500), () {
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() => _currentQuestionIndex++);
      } else {
        _submitQuestionnaire();
      }
    });
  }

  void _goToPreviousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  Future<void> _submitQuestionnaire() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        _showError('Please login again');
        return;
      }

      final result = await ApiService.submitQuestionnaire(
          token,
          responses: _responses,
          childId: _selectedChildId
      );

      _showResults(result);
    } catch (e) {
      print('Error submitting questionnaire: $e');
      _showError('Failed to submit questionnaire: $e');
    }
  }

  void _showResults(Map<String, dynamic> results) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Colors.green),
            SizedBox(width: 8),
            Text('نتائج الفحص الأولي'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // مستوى الخطورة
              if (results['risk_level'] != null)
                _buildResultItem(
                    'مستوى الخطورة',
                    results['risk_level'],
                    _getRiskColor(results['risk_level'])
                ),

              SizedBox(height: 16),

              // الحالات المقترحة
              if (results['suggested_conditions'] != null &&
                  (results['suggested_conditions'] as List).isNotEmpty)
                _buildSuggestedConditions(results['suggested_conditions']),

              SizedBox(height: 16),

              // التوصيات
              if (results['recommendations'] != null)
                _buildRecommendations(results['recommendations']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // إغلاق النتائج
              Navigator.pop(context); // العودة للداشبورد
            },
            child: Text('حسناً', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildSuggestedConditions(List<dynamic> conditions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الحالات المقترحة', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        ...conditions.map((condition) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              Icon(Icons.medical_services, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('• $condition')),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildRecommendations(Map<String, dynamic> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('التوصيات', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        if (recommendations['immediate_actions'] != null)
          ...(recommendations['immediate_actions'] as List).take(3).map((action) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('• $action')),
              ],
            ),
          )),
      ],
    );
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('الفحص الأولي')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل الأسئلة...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('الفحص الأولي')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              SizedBox(height: 16),
              Text(_errorMessage, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadQuestions,
                child: Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('الفحص الأولي'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_questions.isNotEmpty && _currentQuestionIndex == _questions.length - 1)
            IconButton(
              icon: Icon(Icons.done_all),
              onPressed: _submitQuestionnaire,
              tooltip: 'إرسال الاستبيان',
            ),
        ],
      ),
      body: Column(
        children: [
          // شريط التقدم
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _questions.isNotEmpty ?
                  (_currentQuestionIndex + 1) / _questions.length : 0,
                  backgroundColor: Colors.grey[200],
                  color: Colors.blue,
                ),
                SizedBox(height: 8),
                Text(
                  'السؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // السؤال الحالي
          Expanded(
            child: _questions.isNotEmpty ?
            _buildQuestion(_questions[_currentQuestionIndex]) :
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد أسئلة متاحة'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadQuestions,
                    child: Text('إعادة التحميل'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _questions.isNotEmpty ? _buildBottomNav() : null,
    );
  }

  Widget _buildQuestion(Question question) {
    final currentAnswer = _responses[question.questionId.toString()]?['answer'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // فئة السؤال
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getCategoryColor(question.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getCategoryColor(question.category)),
            ),
            child: Text(
              question.category,
              style: TextStyle(
                color: _getCategoryColor(question.category),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          SizedBox(height: 20),

          // نص السؤال
          Text(
            question.questionText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),

          SizedBox(height: 30),

          // خيارات الإجابة
          if (question.questionType == 'Multiple Choice')
            ...question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      option,
                      style: TextStyle(fontSize: 16),
                    ),
                    leading: Radio(
                      value: option,
                      groupValue: currentAnswer,
                      onChanged: (value) => _saveAnswer(
                          question.questionId.toString(),
                          value,
                          question.category
                      ),
                    ),
                    onTap: () => _saveAnswer(
                        question.questionId.toString(),
                        option,
                        question.category
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            }),

          if (question.questionType == 'Scale')
            Column(
              children: [
                Slider(
                  value: (currentAnswer ?? 5).toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: (value) => _saveAnswer(
                      question.questionId.toString(),
                      value.toInt(),
                      question.category
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'القيمة: ${currentAnswer ?? 5}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _goToPreviousQuestion,
                child: Text('السابق'),
              ),
            ),
          if (_currentQuestionIndex > 0) SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentQuestionIndex < _questions.length - 1
                  ? () => setState(() => _currentQuestionIndex++)
                  : _submitQuestionnaire,
              child: Text(
                _currentQuestionIndex < _questions.length - 1
                    ? 'التالي'
                    : 'إنهاء الاستبيان',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Attention & Focus':
        return Colors.blue;
      case 'Social Interaction':
        return Colors.green;
      case 'Communication':
        return Colors.orange;
      case 'Behavior Patterns':
        return Colors.purple;
      case 'Motor Skills':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}