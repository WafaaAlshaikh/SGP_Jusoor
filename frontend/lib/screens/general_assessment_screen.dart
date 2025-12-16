// screens/financial_assessment/general_assessment_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/screens/apply_assessment_screen.dart';
import 'package:frontend/screens/recommended_institutions_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/models/financial_assessment_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class GeneralFinancialAssessmentScreen extends StatefulWidget {
  const GeneralFinancialAssessmentScreen({super.key});

  @override
  State<GeneralFinancialAssessmentScreen> createState() => _GeneralFinancialAssessmentScreenState();
}

class _GeneralFinancialAssessmentScreenState extends State<GeneralFinancialAssessmentScreen> {
  GeneralFinancialAssessment? _assessment;
  Map<String, dynamic> _responses = {};
  Map<String, dynamic> _conditionalResponses = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _errorMessage = '';
  int _currentStep = 0;
  PageController _pageController = PageController();
  List<FinancialQuestion> _filteredQuestions = [];
  
  get _generalAssessment => null;

  @override
  void initState() {
    super.initState();
    _loadAssessment();
  }

  Future<void> _loadAssessment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login first';
          _isLoading = false;
        });
        return;
      }

      final response = await ApiService.initiateGeneralFinancialAssessment(token);
      
      if (response['success'] == true) {
        final assessment = GeneralFinancialAssessment.fromJson(response['assessment']);
        setState(() {
          _assessment = assessment;
          _filteredQuestions = assessment.questions.where((q) => q.type != 'info').toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load assessment';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _handleResponse(String questionId, dynamic value) {
    setState(() {
      _responses[questionId] = value;
      
      // إذا كان السؤال شرطياً، ننظف الإجابات الفرعية إذا تغيرت الإجابة
      if (questionId == 'government_support' && value != 'yes') {
        _conditionalResponses.remove('support_amount');
      }
    });
  }

  void _handleConditionalResponse(String questionId, dynamic value) {
    setState(() {
      _conditionalResponses[questionId] = value;
    });
  }

  void _nextStep() {
    if (_currentStep < _filteredQuestions.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitAssessment() async {
    try {
      setState(() => _isSubmitting = true);
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // دمج الإجابات الأساسية والشرطية
      final allResponses = {..._responses, ..._conditionalResponses};
      
      final response = await ApiService.submitGeneralFinancialAssessment(token, allResponses);

      if (response['success'] == true) {
        // عرض النتائج
        _showResults(response);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit assessment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showResults(Map<String, dynamic> response) {
  final result = GeneralAssessmentResult.fromJson(response);
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Title
            Container(
              margin: EdgeInsets.only(bottom: 20),
              child: Text(
                'Financial Assessment Results',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            
            // Main content with scrolling
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display Tier
                    Container(
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Color(int.parse(result.tierColor.replaceAll('#', '0xFF'))),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.assessment, color: Colors.white, size: 30),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.tierLabel,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  result.tierDescription,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Financial Score
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      margin: EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Financial Score:', style: TextStyle(fontSize: 16)),
                          Text(
                            '${result.financialScore}/100',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Discount Range
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      margin: EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Estimated Discount:', style: TextStyle(fontSize: 16)),
                          Text(
                            result.discountRangeText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Validity
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Valid for:', style: TextStyle(fontSize: 16)),
                          Text(
                            '${result.daysRemaining} days',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: result.daysRemaining > 7 ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Next Actions
                    Container(
                      margin: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Next Steps:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    
                    // Next Actions List
                    ...result.nextActions.map((action) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
                          title: Text(
                            action['label'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: action['description'] != null ? Text(action['description']!) : null,
                          onTap: () {
                            // Handle action based on action['id']
                            _handleNextAction(action);
                          },
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                      );
                    }).toList(),
                    
                    SizedBox(height: 20), // Extra space at bottom
                  ],
                ),
              ),
            ),
            
            // Action Buttons - Fixed at bottom
            Container(
              margin: EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close results
                        Navigator.pop(context); // Go back to previous screen
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Close'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Close results sheet and return success to the assessment screen caller
                        Navigator.pop(context);
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Apply to Child'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}


  // في _handleNextAction()، أضف:
void _handleNextAction(Map<String, dynamic> action) {
  final actionId = action['id'];
  
  switch (actionId) {
    case 'select_child':
      // تنقل لشاشة تطبيق التقييم على طفل
      _navigateToApplyAssessment(_generalAssessment!);
      break;
      
    case 'browse_institutions':
      // تنقل لشاشة المؤسسات الموصى بها
      _navigateToRecommendedInstitutions();
      break;
      
    case 'save_assessment':
      _saveAssessment();
      break;
      
    case 'download_summary':
      _downloadSummary();
      break;
  }
}

void _navigateToRecommendedInstitutions() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RecommendedInstitutionsScreen(
        financialTier: _generalAssessment!.financialTier,
        discountPercentage: _generalAssessment!.suggestedDiscountPercentage,
      ),
    ),
  );
}

// عدل _navigateToApplyAssessment:
void _navigateToApplyAssessment(GeneralAssessmentResult result) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ApplyAssessmentToChildScreen(
        assessment: result,
      ),
    ),
  );
}

  void _navigateToChildSelection() {
    // TODO: Navigate to child selection screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Child selection screen coming soon'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _navigateToInstitutions() {
    // TODO: Navigate to institutions screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Institutions screen coming soon'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _saveAssessment() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Assessment saved successfully'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _downloadSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF download coming soon'),
        backgroundColor: AppColors.info,
      ),
    );
  }


  Widget _buildQuestion(FinancialQuestion question) {
    switch (question.type) {
      case 'range':
        return _buildRangeQuestion(question);
      case 'select':
        return _buildSelectQuestion(question);
      case 'number':
        return _buildNumberQuestion(question);
      case 'multi_select':
        return _buildMultiSelectQuestion(question);
      case 'conditional':
        return _buildConditionalQuestion(question);
      default:
        return _buildInfoContent(question);
    }
  }

  Widget _buildRangeQuestion(FinancialQuestion question) {
    final options = question.options ?? [];
    final currentValue = _responses[question.id];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.question,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (question.description != null) ...[
                SizedBox(height: 8),
                Text(
                  question.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              ...options.map((option) {
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: RadioListTile(
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                    value: option.value,
                    groupValue: currentValue,
                    onChanged: (value) => _handleResponse(question.id, value),
                    selected: currentValue == option.value,
                  ),
                );
              }).toList(),
              SizedBox(height: 60), // مساحة إضافية في الأسفل
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectQuestion(FinancialQuestion question) {
    final options = question.options ?? [];
    final currentValue = _responses[question.id];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.question,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField(
                value: currentValue,
                decoration: InputDecoration(
                  labelText: 'Select an option',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: options.map((option) {
                  return DropdownMenuItem(
                    value: option.value,
                    child: Text(
                      option.label,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (value) => _handleResponse(question.id, value),
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down),
                borderRadius: BorderRadius.circular(10),
              ),
              Spacer(), // مساحة إضافية في الأسفل
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumberQuestion(FinancialQuestion question) {
    final currentValue = _responses[question.id]?.toString() ?? '';
    
    // الحصول على الحد الأدنى والأقصى من البيانات الوصفية للسؤال
    final minValue = _getMinValueFromQuestion(question);
    final maxValue = _getMaxValueFromQuestion(question);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.question,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (question.description != null) ...[
                SizedBox(height: 8),
                Text(
                  question.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                  ),
                ),
              ],
              if (minValue != null || maxValue != null) ...[
                SizedBox(height: 8),
                Text(
                  _getRangeText(minValue, maxValue),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                keyboardType: TextInputType.number,
                initialValue: currentValue,
                decoration: InputDecoration(
                  labelText: 'Enter number',
                  hintText: question.description ?? '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  suffixIcon: Icon(Icons.numbers),
                ),
                onChanged: (value) => _handleResponse(question.id, int.tryParse(value) ?? 0),
                validator: (value) {
                  if (question.required && (value == null || value.isEmpty)) {
                    return 'This field is required';
                  }
                  final intValue = int.tryParse(value ?? '');
                  if (intValue != null) {
                    if (minValue != null && intValue < minValue) {
                      return 'Minimum value is $minValue';
                    }
                    if (maxValue != null && intValue > maxValue) {
                      return 'Maximum value is $maxValue';
                    }
                  }
                  return null;
                },
              ),
              Spacer(), // مساحة إضافية في الأسفل
            ],
          ),
        ),
      ],
    );
  }

  // دالة مساعدة للحصول على الحد الأدنى
  int? _getMinValueFromQuestion(FinancialQuestion question) {
    // إذا كان السؤال عن حجم الأسرة
    if (question.id == 'family_size') return 1;
    // إذا كان السؤال عن المعالين
    if (question.id == 'dependents_count') return 0;
    return null;
  }

  // دالة مساعدة للحصول على الحد الأقصى
  int? _getMaxValueFromQuestion(FinancialQuestion question) {
    // إذا كان السؤال عن حجم الأسرة
    if (question.id == 'family_size') return 15;
    // إذا كان السؤال عن المعالين
    if (question.id == 'dependents_count') return 10;
    return null;
  }

  // دالة مساعدة للحصول على نص المدى
  String _getRangeText(int? min, int? max) {
    if (min != null && max != null) {
      return 'Range: $min to $max';
    } else if (min != null) {
      return 'Minimum: $min';
    } else if (max != null) {
      return 'Maximum: $max';
    }
    return '';
  }

  Widget _buildMultiSelectQuestion(FinancialQuestion question) {
    final options = question.options ?? [];
    final currentValues = _responses[question.id] is List 
        ? List<String>.from(_responses[question.id] ?? [])
        : [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.question,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              ...options.map((option) {
                final isSelected = currentValues.contains(option.value);
                
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                  child: CheckboxListTile(
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          // إذا اختار "none"، ننظف جميع الخيارات الأخرى
                          if (option.value == 'none') {
                            _responses[question.id] = ['none'];
                          } else {
                            // إزالة "none" إذا كان موجوداً وإضافة الخيار الجديد
                            final List<String> newValues = List<String>.from(currentValues)
                              ..remove('none')
                              ..add(option.value);
                            _responses[question.id] = newValues;
                          }
                        } else {
                          // إزالة الخيار
                          final List<String> newValues = List<String>.from(currentValues)
                            ..remove(option.value);
                          _responses[question.id] = newValues;
                        }
                      });
                    },
                    secondary: Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primary : Colors.grey,
                    ),
                  ),
                );
              }).toList(),
              if (currentValues.isNotEmpty && !currentValues.contains('none'))
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Selected: ${currentValues.length} option(s)',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              SizedBox(height: 60), // مساحة إضافية في الأسفل
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConditionalQuestion(FinancialQuestion question) {
    final currentValue = _responses[question.id];
    final showFollowUp = currentValue == 'yes';
    final followUpQuestions = question.followUp?['yes'] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.question,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              Column(
                children: [
                  Card(
                    margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: RadioListTile(
                      title: Text('Yes'),
                      value: 'yes',
                      groupValue: currentValue,
                      onChanged: (value) => _handleResponse(question.id, value),
                      selected: currentValue == 'yes',
                    ),
                  ),
                  Card(
                    margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: RadioListTile(
                      title: Text('No'),
                      value: 'no',
                      groupValue: currentValue,
                      onChanged: (value) => _handleResponse(question.id, value),
                      selected: currentValue == 'no',
                    ),
                  ),
                ],
              ),
              
              if (showFollowUp && followUpQuestions.isNotEmpty) ...[
                SizedBox(height: 30),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Follow-up Question',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 10),
                      ...followUpQuestions.map((followUp) {
                        if (followUp['type'] == 'range') {
                          final options = followUp['options'] ?? [];
                          final followUpValue = _conditionalResponses[followUp['id']];
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                followUp['question'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 10),
                              ...options.map((option) {
                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 4),
                                  child: RadioListTile(
                                    title: Text(option['label'] ?? ''),
                                    value: option['value'],
                                    groupValue: followUpValue,
                                    onChanged: (value) => _handleConditionalResponse(followUp['id'], value),
                                    selected: followUpValue == option['value'],
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        }
                        return SizedBox();
                      }).toList(),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 60), // مساحة إضافية في الأسفل
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoContent(FinancialQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 40, color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                question.content ?? '',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                  height: 1.5,
                ),
              ),
              if (question.note != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber[700]),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          question.note!,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Spacer(),
        Align(
          alignment: Alignment.center,
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Start Assessment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: 60), // مساحة إضافية في الأسفل
      ],
    );
  }

  bool _validateCurrentQuestion() {
    final currentQuestion = _filteredQuestions[_currentStep];
    
    if (currentQuestion.required && _responses[currentQuestion.id] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please answer this question'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    
    // التحقق من الأسئلة الشرطية
    if (currentQuestion.type == 'conditional' && 
        _responses[currentQuestion.id] == 'yes') {
      final followUpId = 'support_amount'; // Assuming this is the follow-up ID
      if (_conditionalResponses[followUpId] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please answer the follow-up question'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }
    
    return true;
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.assessment, size: 20, color: AppColors.primary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Assessment',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _filteredQuestions.length,
                  backgroundColor: Colors.grey[200],
                  color: AppColors.primary,
                  minHeight: 4,
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Text(
            '${_currentStep + 1}/${_filteredQuestions.length}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Assessment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              _previousStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Loading assessment...',
                    style: TextStyle(
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadAssessment,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _assessment == null
                  ? Center(
                      child: Text(
                        'No assessment available',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                    )
                  : Column(
                      children: [
                        // Step Indicator
                        _buildStepIndicator(),
                        
                        // Questions
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _filteredQuestions.length,
                            itemBuilder: (context, index) {
                              final question = _filteredQuestions[index];
                              return Padding(
                                padding: EdgeInsets.all(16),
                                child: _buildQuestion(question),
                              );
                            },
                          ),
                        ),
                        
                        // Navigation Buttons
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Colors.grey[200]!)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _previousStep,
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    _currentStep == 0 ? 'Cancel' : 'Back',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _currentStep < _filteredQuestions.length - 1
                                    ? ElevatedButton(
                                        onPressed: () {
                                          if (_validateCurrentQuestion()) {
                                            _nextStep();
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: EdgeInsets.symmetric(vertical: 15),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          'Next',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _isSubmitting ? null : _submitAssessment,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: EdgeInsets.symmetric(vertical: 15),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: _isSubmitting
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(
                                                'Submit Assessment',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
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
}