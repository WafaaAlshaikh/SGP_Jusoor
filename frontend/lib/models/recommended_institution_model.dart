// models/recommended_institution_model.dart

import 'dart:ui';

import 'package:flutter/material.dart';

class RecommendedInstitution {
  final int institutionId;
  final String name;
  final String city;
  final List<String> specializations;
  final bool financialAid;
  final double averageSessionPrice;
  final double compatibilityScore;
  final EstimatedDiscount estimatedDiscount;
  final int processingTime;
  final String? imageUrl;
  final String? address;
  final double? rating;
  final int? availableSlots;

  RecommendedInstitution({
    required this.institutionId,
    required this.name,
    required this.city,
    required this.specializations,
    required this.financialAid,
    required this.averageSessionPrice,
    required this.compatibilityScore,
    required this.estimatedDiscount,
    required this.processingTime,
    this.imageUrl,
    this.address,
    this.rating,
    this.availableSlots,
  });

  factory RecommendedInstitution.fromJson(Map<String, dynamic> json) {
    return RecommendedInstitution(
      institutionId: json['institution_id'] ?? 0,
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      specializations: List<String>.from(json['specializations'] ?? []),
      financialAid: json['financial_aid'] ?? false,
      averageSessionPrice: double.tryParse(json['average_session_price']?.toString() ?? '0') ?? 0.0,
      compatibilityScore: double.tryParse(json['compatibility_score']?.toString() ?? '0') ?? 0.0,
      estimatedDiscount: EstimatedDiscount.fromJson(json['estimated_discount'] ?? {}),
      processingTime: json['processing_time'] ?? 7,
      imageUrl: json['image_url'],
      address: json['address'],
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
      availableSlots: json['available_slots'],
    );
  }

  String get priceText => '\$${averageSessionPrice.toStringAsFixed(2)}';
  String get compatibilityText => '${compatibilityScore.toInt()}% Match';
  String get processingText => '$processingTime أيام';
  String get specializationsText => specializations.join(' • ');
  
  Color get compatibilityColor {
    if (compatibilityScore >= 80) return Colors.green;
    if (compatibilityScore >= 60) return Colors.orange;
    return Colors.red;
  }
}

class EstimatedDiscount {
  final int min;
  final int max;
  final int average;

  EstimatedDiscount({
    required this.min,
    required this.max,
    required this.average,
  });

  factory EstimatedDiscount.fromJson(Map<String, dynamic> json) {
    return EstimatedDiscount(
      min: json['min'] ?? 0,
      max: json['max'] ?? 0,
      average: json['average'] ?? 0,
    );
  }

  String get rangeText => '$min%-$max%';
  String get averageText => '$average%';
}