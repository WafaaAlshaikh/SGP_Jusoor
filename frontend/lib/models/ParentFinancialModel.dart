// models/parent_financial_model.dart
import 'dart:ui';

import 'package:flutter/material.dart';

class ParentFinancialModel {
  final int parentId;
  final double? monthlyIncome;
  final String? employmentStatus;
  final int familySize;
  final int dependentsCount;
  final String? specialCircumstances;
  final bool receivesGovernmentSupport;
  final double? governmentSupportAmount;
  final double? otherMonthlyExpenses;
  final double? additionalMedicalExpenses;
  final int financialScore;
  final String financialTier;
  final DateTime? lastFinancialAssessment;
  final Map<String, dynamic>? financialDocuments;
  final String? assessmentNotes;
  final int credibilityScore;

  ParentFinancialModel({
    required this.parentId,
    this.monthlyIncome,
    this.employmentStatus,
    required this.familySize,
    required this.dependentsCount,
    this.specialCircumstances,
    required this.receivesGovernmentSupport,
    this.governmentSupportAmount,
    this.otherMonthlyExpenses,
    this.additionalMedicalExpenses,
    required this.financialScore,
    required this.financialTier,
    this.lastFinancialAssessment,
    this.financialDocuments,
    this.assessmentNotes,
    required this.credibilityScore,
  });

 // في parent_financial_model.dart - تحديث factory fromJson

factory ParentFinancialModel.fromJson(Map<String, dynamic> json) {
  // دالة مساعدة لتحويل أي قيمة إلى double
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.tryParse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // دالة مساعدة لتحويل أي قيمة إلى int
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.tryParse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  return ParentFinancialModel(
    parentId: _parseInt(json['parent_id']) ?? 0,
    monthlyIncome: _parseDouble(json['monthly_income']),
    employmentStatus: json['employment_status'],
    familySize: _parseInt(json['family_size']) ?? 1,
    dependentsCount: _parseInt(json['dependents_count']) ?? 0,
    specialCircumstances: json['special_circumstances'],
    receivesGovernmentSupport: json['receives_government_support'] ?? false,
    governmentSupportAmount: _parseDouble(json['government_support_amount']),
    otherMonthlyExpenses: _parseDouble(json['other_monthly_expenses']),
    additionalMedicalExpenses: _parseDouble(json['additional_medical_expenses']),
    financialScore: _parseInt(json['financial_score']) ?? 0,
    financialTier: json['financial_tier'] ?? 'tier_5_no_assistance',
    lastFinancialAssessment: json['last_financial_assessment'] != null
        ? DateTime.tryParse(json['last_financial_assessment'].toString())
        : null,
    financialDocuments: json['financial_documents'],
    assessmentNotes: json['assessment_notes'],
    credibilityScore: _parseInt(json['credibility_score']) ?? 50,
  );
}

  String get tierLabel {
    switch (financialTier) {
      case 'tier_1_critical':
        return 'Critical Financial Need';
      case 'tier_2_high':
        return 'High Financial Need';
      case 'tier_3_medium':
        return 'Medium Financial Need';
      case 'tier_4_low':
        return 'Low Financial Need';
      case 'tier_5_no_assistance':
        return 'No Assistance Required';
      default:
        return 'Unknown';
    }
  }

  String get tierColor {
    switch (financialTier) {
      case 'tier_1_critical':
        return '#EF4444'; // red
      case 'tier_2_high':
        return '#F97316'; // orange
      case 'tier_3_medium':
        return '#F59E0B'; // amber
      case 'tier_4_low':
        return '#10B981'; // emerald
      case 'tier_5_no_assistance':
        return '#6B7280'; // gray
      default:
        return '#6B7280';
    }
  }

  bool get needsFinancialAssessment {
    return financialScore == 0 || 
           lastFinancialAssessment == null ||
           DateTime.now().difference(lastFinancialAssessment!).inDays > 90;
  }

  // في parent_financial_model.dart

// داخل class ParentFinancialModel

// دالة للتحقق من صلاحية التقييم
bool get hasValidFinancialAssessment {
  if (lastFinancialAssessment == null) return false;
  
  final daysSinceAssessment = DateTime.now().difference(lastFinancialAssessment!).inDays;
  return daysSinceAssessment <= 30; // صلاحية 30 يوم
}

int get daysRemainingForAssessment {
  if (!hasValidFinancialAssessment) return 0;
  
  final daysSinceAssessment = DateTime.now().difference(lastFinancialAssessment!).inDays;
  return 30 - daysSinceAssessment;
}

// دالة للحصول على نطاق الخصم بناءً على المستوى
String get discountRange {
  switch (financialTier) {
    case 'tier_1_critical':
      return '80-100%';
    case 'tier_2_high':
      return '60-79%';
    case 'tier_3_medium':
      return '40-59%';
    case 'tier_4_low':
      return '20-39%';
    case 'tier_5_no_assistance':
      return '0-19%';
    default:
      return '0%';
  }
}

// دالة للحصول على توصية بناءً على المستوى
String get tierRecommendation {
  switch (financialTier) {
    case 'tier_1_critical':
      return 'You qualify for maximum financial assistance. Most institutions will offer significant discounts.';
    case 'tier_2_high':
      return 'You qualify for high financial assistance. Many institutions have programs for your situation.';
    case 'tier_3_medium':
      return 'You qualify for moderate financial assistance. Some institutions offer sliding scale fees.';
    case 'tier_4_low':
      return 'You qualify for limited financial assistance. Consider payment plans or partial assistance.';
    case 'tier_5_no_assistance':
      return 'You may not qualify for financial assistance, but payment plans may be available.';
    default:
      return 'Please complete a financial assessment.';
  }
}

// دالة لتحديد الأولوية بناءً على المستوى
String get priorityLevel {
  switch (financialTier) {
    case 'tier_1_critical':
      return 'High Priority';
    case 'tier_2_high':
      return 'Medium Priority';
    case 'tier_3_medium':
    case 'tier_4_low':
    case 'tier_5_no_assistance':
      return 'Normal Priority';
    default:
      return 'Unknown';
  }
}

Color get priorityColor {
  switch (financialTier) {
    case 'tier_1_critical':
      return Colors.red;
    case 'tier_2_high':
      return Colors.orange;
    case 'tier_3_medium':
      return Colors.yellow;
    case 'tier_4_low':
    case 'tier_5_no_assistance':
      return Colors.green;
    default:
      return Colors.grey;
  }
}
}