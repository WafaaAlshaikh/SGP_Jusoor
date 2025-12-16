// screens/financial_assessment/apply_assessment_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financial_assessment_models.dart';
import '../models/child_model.dart';
import '../models/recommended_institution_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ApplyAssessmentToChildScreen extends StatefulWidget {
  final GeneralAssessmentResult assessment;

  const ApplyAssessmentToChildScreen({
    super.key,
    required this.assessment,
  });

  @override
  State<ApplyAssessmentToChildScreen> createState() => _ApplyAssessmentToChildScreenState();
}

class _ApplyAssessmentToChildScreenState extends State<ApplyAssessmentToChildScreen> {
  List<Child> _children = [];
  List<RecommendedInstitution> _recommendedInstitutions = [];
  Child? _selectedChild;
  RecommendedInstitution? _selectedInstitution;
  bool _isLoading = true;
  bool _isApplying = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // 1. تحميل الأطفال
      final childrenResponse = await ApiService.getChildren(token:token);
      if (childrenResponse['success'] == true) {
        final List<dynamic> childrenData = childrenResponse['data'] ?? [];
        _children = childrenData.map((c) => Child.fromJson(c)).toList();
        
        // اختيار أول طفل افتراضيًا
        if (_children.isNotEmpty) {
          _selectedChild = _children.first;
        }
      }

      // 2. تحميل المؤسسات الموصى بها
      final institutionsResponse = await ApiService.getRecommendedInstitutionsByTier(
        token,
        widget.assessment.financialTier,
        widget.assessment.suggestedDiscountPercentage,
      );
      
      if (institutionsResponse['success'] == true) {
        final List<dynamic> institutionsData = institutionsResponse['data'] ?? [];
        _recommendedInstitutions = institutionsData
            .map((i) => RecommendedInstitution.fromJson(i))
            .toList();
        
        // اختيار أول مؤسسة افتراضيًا
        if (_recommendedInstitutions.isNotEmpty) {
          _selectedInstitution = _recommendedInstitutions.first;
        }
      }

      setState(() { _isLoading = false; });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  Future<void> _applyAssessment() async {
    if (_selectedChild == null || _selectedInstitution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a child and institution'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() { _isApplying = true; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await ApiService.applyFinancialAssessmentToChild(
        token,
        _selectedChild!.id,
        _selectedInstitution!.institutionId,
        useExistingAssessment: true,
      );

      if (response['success'] == true) {
        // عرض النتائج
        _showApplicationResult(response);
      } else {
        throw Exception(response['message'] ?? 'Application failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() { _isApplying = false; });
    }
  }

  void _showApplicationResult(Map<String, dynamic> response) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final childName = _selectedChild?.fullName ?? '';
        final institutionName = _selectedInstitution?.name ?? '';
        final discount = response['financial_analysis']?['suggested_discount_percentage'] ?? 0;
        final monthlySavings = response['financial_analysis']?['monthly_savings'] ?? '0';
        
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              
              Icon(Icons.check_circle, size: 60, color: AppColors.success),
              SizedBox(height: 16),
              
              Text(
                'Assessment Applied Successfully!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 12),
              
              Text(
                'Financial assessment has been applied to $childName at $institutionName',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGray,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 24),
              
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimated Discount:', style: TextStyle(fontSize: 14)),
                        Text(
                          '$discount%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monthly Savings:', style: TextStyle(fontSize: 14)),
                        Text(
                          '\$$monthlySavings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        // يمكن التنقل لطلب المساعدة المالية
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: Text('Request Assistance'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssessmentSummary() {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(int.parse(widget.assessment.tierColor.replaceAll('#', '0xFF'))),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.assessment, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.assessment.tierLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Valid for ${widget.assessment.daysRemaining} days',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financial Score', style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                    Text('${widget.assessment.financialScore}/100', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Discount Range', style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                    Text(widget.assessment.discountRangeText, 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSelector() {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Child',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            
            if (_children.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.child_care, size: 40, color: AppColors.textLight),
                    SizedBox(height: 8),
                    Text(
                      'No children found',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please add a child first',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _children.map((child) {
                  final isSelected = _selectedChild?.id == child.id;
                  
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                    child: RadioListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          // Text(
                          //   child.condition,
                          //   style: TextStyle(
                          //     fontSize: 12,
                          //     color: AppColors.textGray,
                          //   ),
                          // ),
                          if (child.currentInstitutionId != null) ...[
                            SizedBox(height: 2),
                            Text(
                              'Registered at: ${child.currentInstitutionId}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      value: child,
                      groupValue: _selectedChild,
                      onChanged: (Child? value) {
                        setState(() {
                          _selectedChild = value;
                        });
                      },
                      secondary: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          child.fullName[0],
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionSelector() {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recommended Institutions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_recommendedInstitutions.length} options',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            
            if (_recommendedInstitutions.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.business, size: 40, color: AppColors.textLight),
                    SizedBox(height: 8),
                    Text(
                      'No institutions available',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try completing a financial assessment first',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _recommendedInstitutions.map((institution) {
                  final isSelected = _selectedInstitution?.institutionId == institution.institutionId;
                  
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                    child: RadioListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            institution.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 12, color: AppColors.textGray),
                              SizedBox(width: 4),
                              Text(
                                institution.city,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                ),
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: institution.compatibilityColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  institution.compatibilityText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: institution.compatibilityColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            institution.specializationsText,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.attach_money, size: 12, color: AppColors.textGray),
                              SizedBox(width: 4),
                              Text(
                                institution.priceText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textGray,
                                ),
                              ),
                              Spacer(),
                              Text(
                                '${institution.estimatedDiscount.averageText} discount',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      value: institution,
                      groupValue: _selectedInstitution,
                      onChanged: (RecommendedInstitution? value) {
                        setState(() {
                          _selectedInstitution = value;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apply Financial Assessment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                          style: TextStyle(color: AppColors.textGray),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Assessment Summary
                      _buildAssessmentSummary(),
                      
                      // Child Selector
                      _buildChildSelector(),
                      
                      // Institution Selector
                      _buildInstitutionSelector(),
                      
                      SizedBox(height: 24),
                      
                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isApplying || _selectedChild == null || _selectedInstitution == null 
                              ? null 
                              : _applyAssessment,
                          icon: _isApplying
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.send),
                          label: Text(
                            _isApplying ? 'Applying...' : 'Apply Assessment',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: (_selectedChild == null || _selectedInstitution == null)
                                ? AppColors.textLight
                                : AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Info Card
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 20, color: AppColors.info),
                                SizedBox(width: 8),
                                Text(
                                  'What happens next?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '1. Assessment will be applied to the selected child\n'
                              '2. You\'ll see estimated discount and savings\n'
                              '3. You can then request formal financial assistance\n'
                              '4. Institution will review and approve/decline',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textGray,
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