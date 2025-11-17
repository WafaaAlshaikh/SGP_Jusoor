import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/questionnaire_model.dart';

class QuestionnaireScreen extends StatefulWidget {
  final String? childId;
  final String? childName;

  const QuestionnaireScreen({super.key, this.childId, this.childName});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  List<Question> _questions = [];
  Map<String, dynamic> _responses = {};
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  String _errorMessage = '';
  String _language = 'ar';
  double _progress = 0.0;
  String? _currentQuestionnaireId;
  String _currentStage = 'demographics';

  @override
  void initState() {
    super.initState();
    _loadQuestionsForStage('demographics');
  }

  Future<void> _loadQuestionsForStage(String stage) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _currentStage = stage;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'يرجى تسجيل الدخول مرة أخرى';
          _isLoading = false;
        });
        return;
      }

      final questions = await ApiService.getQuestionnaireQuestions(
        token,
        childId: widget.childId,
        previousAnswers: _currentStage == 'deep' ? _responses : null,
        stage: stage,
        language: _language,
      );

      setState(() {
        _questions = questions;
        _isLoading = false;
        _progress = _calculateProgress();
      });
    } catch (e) {
      print('❌ خطأ في تحميل الأسئلة: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'فشل في تحميل الأسئلة: $e';
      });
    }
  }

  void _saveAnswer(String questionId, dynamic answer, String category) {
    setState(() {
      _responses[questionId] = {
        'answer': answer,
        'category': category,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _progress = _calculateProgress();
    });

    // الانتقال التلقائي بعد حفظ الإجابة
    if (_currentQuestionIndex < _questions.length - 1) {
      Future.delayed(Duration(milliseconds: 400), () {
        setState(() => _currentQuestionIndex++);
      });
    }
  }

  void _goToPreviousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      // انتهت أسئلة هذه المرحلة
      if (_currentStage == 'demographics') {
        // انتقل إلى الأسئلة العامة المشتركة
        _currentQuestionIndex = 0;
        _loadQuestionsForStage('general');
      } else if (_currentStage == 'general') {
        // انتقل إلى الأسئلة المتخصصة (حسب النتائج)
        _currentQuestionIndex = 0;
        _loadQuestionsForStage('deep');
      } else {
        // انتهت الأسئلة المتخصصة -> إرسال الاستبيان
        _submitQuestionnaire();
      }
    }
  }

  Future<void> _submitQuestionnaire() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        _showError('يرجى تسجيل الدخول مرة أخرى');
        return;
      }

      final result = await ApiService.submitQuestionnaireResponses(
        token,
        responses: _responses,
        childId: widget.childId,
        questionnaireId: _currentQuestionnaireId,
        language: _language,
      );

      _showResults(result);
    } catch (e) {
      print('❌ خطأ في إرسال الاستبيان: $e');
      _showError('فشل في إرسال الاستبيان: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
            Text('نتائج التقييم المبدئي'),
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

              SizedBox(height: 16),

              // معلومات إضافية
              if (results['questionnaire_id'] != null)
                _buildQuestionnaireInfo(results),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // إغلاق النتائج
              Navigator.pop(context); // العودة للشاشة السابقة
            },
            child: Text('حسناً', style: TextStyle(fontSize: 16)),
          ),
          if (results['questionnaire_id'] != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _viewQuestionnaireDetails(results['questionnaire_id']);
              },
              child: Text('عرض التفاصيل', style: TextStyle(fontSize: 16)),
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
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
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

        // الإجراءات الفورية
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

        // المختصون المقترحون
        if (recommendations['specialists'] != null &&
            (recommendations['specialists'] as List).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المختصون المقترحون', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(recommendations['specialists'] as List).take(2).map((specialist) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('• $specialist'),
                    ],
                  ),
                )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionnaireInfo(Map<String, dynamic> results) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('معلومات التقييم', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('رقم التقييم: ${results['questionnaire_id']}'),
          if (results['completed_at'] != null)
            Text('تاريخ الإكمال: ${_formatDate(results['completed_at'])}'),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _viewQuestionnaireDetails(String questionnaireId) {
    // يمكنك التنقل لشاشة تفاصيل الاستبيان هنا
    print('عرض تفاصيل الاستبيان: $questionnaireId');
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

  double _calculateProgress() {
    if (_questions.isEmpty) return 0.0;
    return (_currentQuestionIndex + 1) / _questions.length;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _toggleLanguage() {
    setState(() {
      _language = _language == 'ar' ? 'en' : 'ar';
    });
    _loadQuestionsForStage(_currentStage);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _questions.isEmpty) {
      return _buildLoadingScreen();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorScreen();
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProgressSection(),
          Expanded(
            child: _questions.isNotEmpty
                ? _buildQuestion(_questions[_currentQuestionIndex])
                : _buildEmptyQuestions(),
          ),
        ],
      ),
      bottomNavigationBar: _questions.isNotEmpty ? _buildBottomNav() : null,
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(title: Text('التقييم المبدئي')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل الأسئلة...'),
            if (widget.childId != null)
              Text('لطفل: ${widget.childName ?? "غير محدد"}'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(title: Text('التقييم المبدئي')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(_errorMessage, textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadQuestionsForStage(_currentStage),
              child: Text('إعادة التحميل'),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('التقييم المبدئي'),
          if (widget.childName != null)
            Text(
              widget.childName!,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
        ],
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(_language == 'ar' ? Icons.language : Icons.translate),
          onPressed: _toggleLanguage,
          tooltip: 'تبديل اللغة',
        ),
        if (_questions.isNotEmpty && _currentQuestionIndex == _questions.length - 1)
          IconButton(
            icon: Icon(Icons.done_all),
            onPressed: _submitQuestionnaire,
            tooltip: 'إرسال الاستبيان',
          ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.blue[100]!)),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[200],
            color: Colors.blue,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'السؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
        ],
      ),
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
          _buildCategoryChip(question.category),

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

          // خيارات الإجابة حسب النوع
          _buildAnswerOptions(question, currentAnswer),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getCategoryColor(category).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getCategoryColor(category)),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: _getCategoryColor(category),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAnswerOptions(Question question, dynamic currentAnswer) {
    switch (question.questionType) {
      case 'Multiple Choice':
        return _buildMultipleChoiceOptions(question, currentAnswer);
      case 'Scale':
        return _buildScaleOptions(question, currentAnswer);
      case 'Yes/No':
        return _buildYesNoOptions(question, currentAnswer);
      default:
        return _buildMultipleChoiceOptions(question, currentAnswer);
    }
  }

  Widget _buildMultipleChoiceOptions(Question question, dynamic currentAnswer) {
    return Column(
      children: question.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: currentAnswer == option
                    ? _getCategoryColor(question.category)
                    : Colors.transparent,
                width: 2,
              ),
            ),
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
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScaleOptions(Question question, dynamic currentAnswer) {
    final initialValue = (currentAnswer ?? 5).toDouble();

    return Column(
      children: [
        Slider(
          value: initialValue,
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
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['0', '2', '4', '6', '8', '10'].map((label) =>
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey))
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildYesNoOptions(Question question, dynamic currentAnswer) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildOptionButton('نعم', currentAnswer == 'نعم', question),
        _buildOptionButton('لا', currentAnswer == 'لا', question),
      ],
    );
  }

  Widget _buildOptionButton(String text, bool isSelected, Question question) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: () => _saveAnswer(
              question.questionId.toString(),
              text,
              question.category
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? _getCategoryColor(question.category)
                : Colors.grey[200],
            foregroundColor: isSelected ? Colors.white : Colors.black87,
            padding: EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(text, style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildEmptyQuestions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('لا توجد أسئلة متاحة'),
          SizedBox(height: 8),
          Text(
            'قد يكون ذلك بسبب عدم توافق عمر الطفل مع الأسئلة المتاحة',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _loadQuestionsForStage(_currentStage),
            child: Text('إعادة التحميل'),
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
                  ? _goToNextQuestion
                  : _submitQuestionnaire,
              child: Text(
                _currentQuestionIndex < _questions.length - 1
                    ? 'التالي'
                    : 'إنهاء التقييم',
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
      case 'Academic Performance':
        return Colors.indigo;
      case 'Daily Living Skills':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}