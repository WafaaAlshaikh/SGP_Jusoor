// models/child_model.dart - النسخة المصححة
import 'dart:ui';

import 'package:flutter/material.dart';

class Child {
  final int id;
  final String fullName;
  final String dateOfBirth;
  final String gender;
  final int? diagnosisId;
  final String photo;
  final String medicalHistory;
  final String? condition;
  final int age;
  final DateTime? lastSessionDate;
  final String? status;
  final int? institutionId;
  final DateTime? deletedAt;
  final bool isArchived;
  final String registrationStatus;
  final int? currentInstitutionId;
  final String? currentInstitutionName;

  // الحقول الجديدة للـ AI
  final String? suspectedCondition;
  final String? symptomsDescription;
  final dynamic aiSuggestedDiagnosis;
  final double? aiConfidenceScore;
  final String? riskLevel;
  final dynamic recommendedInstitutions;

  // الحقول الجديدة من الباك إند
  final String? childIdentifier;
  final String? address;
  final String? parentPhone;
  final String? schoolInfo;
  final String? previousServices;
  final String? additionalNotes;
  final bool consentGiven;
  final String? city;
  
  // ⭐ جديد: إحداثيات الطفل الجغرافية
  final double? locationLat;
  final double? locationLng;


  // NEW: Financial Assistance Fields
  final bool? financialAssistanceApplied;
  final double? discountPercentage;
  final double? originalPrice;
  final double? finalPrice;
  final String? paymentStatus;
  final int? financialAssistanceRequestId;

  final Map<String, dynamic>? institutionContact;


  Child({
    required this.id,
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    this.diagnosisId,
    required this.photo,
    required this.medicalHistory,
    this.condition,
    required this.age,
    this.lastSessionDate,
    this.status,
    this.institutionId,
    required this.registrationStatus,
    this.currentInstitutionId,
    this.currentInstitutionName,
    this.deletedAt,
    required this.isArchived,

    // الحقول الجديدة
    this.suspectedCondition,
    this.symptomsDescription,
    this.aiSuggestedDiagnosis,
    this.aiConfidenceScore,
    this.riskLevel,
    this.recommendedInstitutions,

    // الحقول من الباك إند
    this.childIdentifier,
    this.address,
    this.parentPhone,
    this.schoolInfo,
    this.previousServices,
    this.additionalNotes,
    this.consentGiven = false,
    this.city,
    this.locationLat,
    this.locationLng,

    // NEW: Financial Assistance Fields
    this.financialAssistanceApplied,
    this.discountPercentage,
    this.originalPrice,
    this.finalPrice,
    this.paymentStatus,
    this.financialAssistanceRequestId,
    this.institutionContact,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    print('🔄 Child.fromJson raw data: $json');

    // معالجة last_session_date
    DateTime? lastSessionDate;
    if (json['last_session_date'] != null) {
      if (json['last_session_date'] is String) {
        lastSessionDate = DateTime.tryParse(json['last_session_date']);
      }
    }

    // معالجة deleted_at
    DateTime? deletedAt;
    if (json['deleted_at'] != null && json['deleted_at'] is String) {
      deletedAt = DateTime.tryParse(json['deleted_at']);
    }

    // معالجة الصورة
    String? photo = json['photo'];
    if (photo != null && photo.contains('base64')) {
      photo = '';
    }

    // معالجة العمر
    int age = 0;
    if (json['age'] != null) {
      if (json['age'] is int) {
        age = json['age'];
      } else if (json['age'] is String) {
        age = int.tryParse(json['age']) ?? _calculateAge(json['date_of_birth'] ?? '');
      }
    } else {
      age = _calculateAge(json['date_of_birth'] ?? '');
    }

    // معالجة ai_confidence_score
    double? aiConfidenceScore;
    if (json['ai_confidence_score'] != null) {
      if (json['ai_confidence_score'] is double) {
        aiConfidenceScore = json['ai_confidence_score'];
      } else if (json['ai_confidence_score'] is String) {
        aiConfidenceScore = double.tryParse(json['ai_confidence_score']);
      } else if (json['ai_confidence_score'] is int) {
        aiConfidenceScore = (json['ai_confidence_score'] as int).toDouble();
      }
    }

    // معالجة diagnosis_id
    int? diagnosisId;
    if (json['diagnosis_id'] != null) {
      if (json['diagnosis_id'] is int) {
        diagnosisId = json['diagnosis_id'];
      } else if (json['diagnosis_id'] is String) {
        diagnosisId = int.tryParse(json['diagnosis_id']);
      }
    }

    return Child(
      id: json['id'] ?? json['child_id'] ?? 0,
      fullName: json['full_name'] ?? '',
      dateOfBirth: json['date_of_birth'] ?? '',
      gender: json['gender'] ?? '',
      diagnosisId: diagnosisId,
      photo: photo ?? '',
      medicalHistory: json['medical_history'] ?? '',
      condition: json['condition'] ?? json['Diagnosis']?['name'],
      age: age,
      lastSessionDate: lastSessionDate,
      status: json['status'] ?? 'Active',
      institutionId: json['institution_id'],
      registrationStatus: json['registration_status'] ?? 'Not Registered',
      currentInstitutionId: json['current_institution_id'],
      institutionContact: json['currentInstitution']?['contact_info'],
      currentInstitutionName: json['current_institution_name'] ??
          json['currentInstitution']?['name'],
      deletedAt: deletedAt,
      isArchived: deletedAt != null,

      // الحقول الجديدة من الـ AI
      suspectedCondition: json['suspected_condition'],
      symptomsDescription: json['symptoms_description'],
      aiSuggestedDiagnosis: json['ai_suggested_diagnosis'],
      aiConfidenceScore: aiConfidenceScore,
      riskLevel: json['risk_level'],
      recommendedInstitutions: json['recommended_institutions'],

      // الحقول من الباك إند
      childIdentifier: json['child_identifier'],
      address: json['address'],
      parentPhone: json['parent_phone'],
      schoolInfo: json['school_info'],
      previousServices: json['previous_services'],
      additionalNotes: json['additional_notes'],
      consentGiven: json['consent_given'] ?? false,
      city: json['city'],
      locationLat: json['location_lat'] != null ? (json['location_lat'] is double ? json['location_lat'] : double.tryParse(json['location_lat'].toString())) : null,
      locationLng: json['location_lng'] != null ? (json['location_lng'] is double ? json['location_lng'] : double.tryParse(json['location_lng'].toString())) : null,

      // NEW: Financial Assistance Fields
      financialAssistanceApplied: json['financial_assistance_applied'] ?? false,
      discountPercentage: json['applied_discount_percentage'] != null
          ? double.tryParse(json['applied_discount_percentage'].toString())
          : null,
      originalPrice: json['original_price'] != null
          ? double.tryParse(json['original_price'].toString())
          : null,
      finalPrice: json['final_price'] != null
          ? double.tryParse(json['final_price'].toString())
          : null,
      paymentStatus: json['payment_status'],
      financialAssistanceRequestId: json['financial_assistance_request_id'],
    );
  }

  static int _calculateAge(String dateOfBirth) {
    try {
      if (dateOfBirth.isEmpty) return 0;
      final birthDate = DateTime.tryParse(dateOfBirth);
      if (birthDate == null) return 0;

      final now = DateTime.now();
      int age = now.year - birthDate.year;
      final monthDiff = now.month - birthDate.month;
      if (monthDiff < 0 || (monthDiff == 0 && now.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }
  

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'diagnosis_id': diagnosisId,
      'photo': photo,
      'medical_history': medicalHistory,
      'institution_id': institutionId,
      'suspected_condition': suspectedCondition,
      'symptoms_description': symptomsDescription,
      'child_identifier': childIdentifier,
      'address': address,
      'parent_phone': parentPhone,
      'school_info': schoolInfo,
      'previous_services': previousServices,
      'additional_notes': additionalNotes,
      'consent_given': consentGiven,
      'city': city,
      'location_lat': locationLat,
      'location_lng': locationLng,
    };
  }

  // دالة مساعدة لعرض بيانات الـ AI
  // في Child Model - تحديث دالة aiAnalysisSummary
  String get aiAnalysisSummary {
    if (aiSuggestedDiagnosis == null) return 'No AI analysis available';

    try {
      if (aiSuggestedDiagnosis is List) {
        final diagnoses = aiSuggestedDiagnosis as List;
        if (diagnoses.isEmpty) return 'No AI suggestions';

        final topDiagnosis = diagnoses.first;
        if (topDiagnosis is Map) {
          final name = topDiagnosis['arabic_name'] ?? topDiagnosis['name'] ?? 'Unknown';
          final confidence = topDiagnosis['confidence'];

          // ✅ معالجة الثقة سواء كانت String أو double
          String confidenceText;
          if (confidence is double) {
            confidenceText = '${(confidence * 100).toStringAsFixed(1)}%';
          } else if (confidence is String) {
            // إذا كانت String مثل "22.5%"، استخدمها كما هي
            confidenceText = confidence;
          } else if (confidence is int) {
            confidenceText = '${(confidence.toDouble() * 100).toStringAsFixed(1)}%';
          } else {
            confidenceText = 'N/A';
          }

          return '$name ($confidenceText)';
        }
      }
      return 'AI analysis available';
    } catch (e) {
      print('❌ Error in aiAnalysisSummary: $e');
      return 'AI analysis available';
    }
  }

  // دالة مساعدة للتحقق إذا فيه تحليل AI
  bool get hasAiAnalysis {
    return aiSuggestedDiagnosis != null &&
        aiSuggestedDiagnosis is List &&
        (aiSuggestedDiagnosis as List).isNotEmpty;
  }

String get paymentStatusLabel {
    switch (paymentStatus) {
      case 'free_session':
        return 'Free Session';
      case 'fully_paid':
        return 'Paid';
      case 'partially_paid':
        return 'Partially Paid';
      case 'pending':
        return 'Pending Payment';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      default:
        return paymentStatus ?? 'Unknown';
    }
  }

  Color get paymentStatusColor {
    switch (paymentStatus) {
      case 'free_session':
        return Colors.green;
      case 'fully_paid':
        return Colors.green;
      case 'partially_paid':
        return Colors.orange;
      case 'pending':
        return Colors.amber;
      case 'cancelled':
        return Colors.red;
      case 'refunded':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  bool get hasFinancialAssistance {
    return financialAssistanceApplied == true && discountPercentage != null && discountPercentage! > 0;
  }

  String get discountText {
    if (discountPercentage == null || discountPercentage == 0) {
      return 'No discount';
    }
    return '${discountPercentage!.toStringAsFixed(0)}% discount';
  }


// في child_model.dart - إضافة دوال مساعدة للتمويل

// داخل class Child

// دالة للتحقق من أهلية التقييم المالي
bool get isEligibleForFinancialAssessment {
  // يكون الطفل مؤهلاً إذا كان مسجلاً في مؤسسة
  return currentInstitutionId != null && currentInstitutionId != 0;
}

// دالة للحصول على نص حالة التمويل
String get financialStatusText {
  if (!hasFinancialAssistance) return 'No assistance';
  if (financialAssistanceApplied == true && discountPercentage != null) {
    return '${discountPercentage!.toStringAsFixed(0)}% discount applied';
  }
  return 'Assistance available';
}

// دالة للحصول على لون حالة التمويل
Color get financialStatusColor {
  if (!hasFinancialAssistance) return Colors.grey;
  if (financialAssistanceApplied == true && discountPercentage != null) {
    if (discountPercentage! >= 50) return Colors.green;
    if (discountPercentage! >= 30) return Colors.orange;
    return Colors.blue;
  }
  return Colors.grey;
}

// دالة للحصول على أيقونة التمويل
IconData get financialStatusIcon {
  if (!hasFinancialAssistance) return Icons.money_off;
  if (financialAssistanceApplied == true && discountPercentage != null) {
    if (discountPercentage! >= 50) return Icons.attach_money;
    if (discountPercentage! >= 30) return Icons.monetization_on;
    return Icons.money;
  }
  return Icons.money_off;
}

  void operator [](String other) {}



}

