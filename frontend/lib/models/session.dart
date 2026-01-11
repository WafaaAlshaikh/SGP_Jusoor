// lib/models/session.dart
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  final String sessionId;
  final String childName;
  final String specialistName;
  final String institutionName;
  final String sessionType;

  final String date;
  final String time;
  final int duration;
  final double price;
  final String sessionLocation;
  final String status;
  final String? reportUrl;
  final double? rating; // ← التقييم
  final String? ratingComment; // ← تعليق التقييم
  final DateTime? ratedAt; // ← وقت التقييم
  final bool? isRated; // ← هل تم التقييم؟
  final String? cancellationReason;
  final double sessionTypePrice;
  final bool isPaid;
  final String paymentStatus;
  final double? originalPrice;
  final double? finalPrice;
  final double? discountPercentage;
  final double? discountAmount;
  final double? refundAmount;
  final bool canCancel;
  final bool canPay;
  final String? parentNotes;
  final String? review;
  final int? childAge;

  final String? childCondition;
  final bool canRate; // ← هل يمكن تقييم الجلسة؟
  bool? isEligibleForAutoDiscount;
  double? autoDiscountPercentage;
  double? autoDiscountAmount;
  String? autoDiscountReason;
  Map<String, dynamic>? financialAssessment;

  Session({
    required this.sessionId,
    required this.childName,
    required this.specialistName,
    required this.institutionName,
    required this.sessionType,

    required this.date,
    required this.time,
    required this.duration,
    required this.price,
    required this.sessionLocation,
    required this.status,
    this.reportUrl,
    this.rating,
    this.ratingComment,
    this.ratedAt,
    this.isRated,
    this.cancellationReason,
    required this.sessionTypePrice,
    required this.isPaid,
    required this.paymentStatus,
    this.originalPrice,
    this.finalPrice,
    this.discountPercentage,
    this.discountAmount,
    this.refundAmount,
    required this.canCancel,
    required this.canPay,
    this.parentNotes,
    this.review,
    this.childAge,

    this.childCondition,
    required this.canRate, // ← تمت الإضافة
    this.isEligibleForAutoDiscount = false,
    this.autoDiscountPercentage = 0,
    this.autoDiscountAmount = 0,
    this.autoDiscountReason,
    this.financialAssessment,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? '';
    final isPaid = (json['is_paid'] ?? json['isPaid'] ?? false) == true;
    final isRated = json['is_rated'] ?? false;
    final canRate = status == 'Completed' && !isRated;

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final paymentStatus = (json['payment_status'] ?? json['paymentStatus'] ?? 'Pending').toString();

    return Session(
      sessionId: json['sessionId']?.toString() ?? json['id']?.toString() ?? '',
      childName: json['childName'] ?? '',
      specialistName: json['specialistName'] ?? '',
      institutionName: json['institutionName'] ?? '',
      sessionType: json['sessionType'] ?? '',

      date: json['date'] ?? '',
      time: json['time'] ?? '',
      duration: json['duration'] ?? 0,
      price: json['price']?.toDouble() ?? 0.0,
      sessionLocation: json['sessionLocation'] ?? '',
      status: json['status'] ?? '',
      reportUrl: json['reportUrl'],
      rating: json['rating']?.toDouble(),
      ratingComment: json['rating_comment'],
      ratedAt: json['rated_at'] != null ? DateTime.parse(json['rated_at']) : null,
      isRated: isRated,
      cancellationReason: json['cancellationReason'],
      isPaid: isPaid,
      paymentStatus: paymentStatus,
      originalPrice: _toDouble(json['original_price'] ?? json['originalPrice']),
      finalPrice: _toDouble(json['final_price'] ?? json['finalPrice']),
      discountPercentage: _toDouble(json['applied_discount_percentage'] ?? json['discountPercentage']),
      discountAmount: _toDouble(json['discount_amount'] ?? json['discountAmount']),
      refundAmount: _toDouble(json['refund_amount'] ?? json['refundAmount']),
      canCancel: status == 'Scheduled',
      canPay: status == 'Scheduled' && !isPaid,
      parentNotes: json['parentNotes'],
      review: json['review'],

      childAge: json['childAge'] ?? json['age'],
      childCondition: json['childCondition'] ?? json['condition'],
      sessionTypePrice: _getPriceFromSessionType(json['sessionType']),
      canRate: canRate, // ← تعيين القيمة
      isEligibleForAutoDiscount: json['eligible_for_auto_discount'] ?? false,
      autoDiscountPercentage: _toDouble(
        json['discount_percentage'] ??
            json['auto_discount_percentage'] ??
            json['autoDiscountPercentage'],
      ),
      autoDiscountAmount: _toDouble(
        json['discount_amount'] ??
            json['auto_discount_amount'] ??
            json['autoDiscountAmount'],
      ),
      autoDiscountReason: (json['discount_reason'] ??
              json['auto_discount_reason'] ??
              json['autoDiscountReason'])
          ?.toString(),
      financialAssessment: json['financial_assessment'],
    );
  }

  static double _getPriceFromSessionType(String? sessionType) {
    if (sessionType == null) return 50.0;

    final priceMap = {
      'Speech Therapy': 80.0,
      'Occupational Therapy': 90.0,
      'Behavioral Therapy': 100.0,
      'Physical Therapy': 85.0,
      'Social Skills': 75.0,
      'Assessment': 120.0,
      'Speech therapy': 80.0,
      'Occupational therapy': 90.0,
      'Behavioral therapy': 100.0,
      'Physical therapy': 85.0,
    };

    // ابحثي عن المفتاح (case insensitive)
    final key = priceMap.keys.firstWhere(
          (key) => key.toLowerCase().contains(sessionType.toLowerCase()),
      orElse: () => 'Default',
    );

    return priceMap[key] ?? 50.0;
  }

  // دالة مساعدة لتحويل الحالة
  String get displayStatus {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case 'confirmed':
        return 'upcoming';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      case 'pending':
        return 'pending';
      default:
        return 'pending';
    }
  }
}