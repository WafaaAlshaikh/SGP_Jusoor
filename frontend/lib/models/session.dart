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
  final double? rating;
  final String? cancellationReason;
  final double sessionTypePrice;// أضيفي هذا


  // الخصائص الجديدة
  final String? parentNotes;
  final String? review;
  final int? childAge;
  final String? childCondition;

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
    this.cancellationReason,
    required this.sessionTypePrice, // أضيفي هذا


    // الخصائص الجديدة
    this.parentNotes,
    this.review,
    this.childAge,
    this.childCondition,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
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
      cancellationReason: json['cancellationReason'],

      // الخصائص الجديدة
      parentNotes: json['parentNotes'],
      review: json['review'],
      childAge: json['childAge'] ?? json['age'],
      childCondition: json['childCondition'] ?? json['condition'],
      sessionTypePrice: _getPriceFromSessionType(json['sessionType']), // استخدمي الدالة مباشرة
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