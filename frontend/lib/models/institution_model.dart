// lib/models/institution_model.dart
class Institution {
  final int id;
  final String name;
  final String? description;
  final String city;
  final String? region;
  final String? address;
  final String? contactInfo;
  final String? website;
  final double? locationLat;
  final double? locationLng;
  final double matchScore;
  final double? distance;
  final double rating;
  final double avgPrice;
  final List<String> matchingSpecialties;
  final List<dynamic> availableServices;

  final String? contactPhone;
  final String? contactEmail;
  final double? avgSessionPrice;
  final bool isActive;
  final List<String>? specialties;

  Institution({
    required this.id,
    required this.name,
    this.description,
    required this.city,
    this.region,
    this.address,
    this.contactInfo,
    this.website,
    this.locationLat,
    this.locationLng,
    required this.matchScore,
    this.distance,
    required this.rating,
    required this.avgPrice,
    required this.matchingSpecialties,
    required this.availableServices,    
    this.contactPhone,
    this.contactEmail,
    this.avgSessionPrice,
    required this.isActive,
    this.specialties,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: json['id'] ?? json['institution_id'] ?? 0,
      name: json['name'] ?? 'Unknown Institution',
      description: json['description'],
      city: json['city'] ?? '',
      region: json['region'],
      address: json['address'] ?? json['location_address'],
      contactInfo: json['contact_info'],
      website: json['website'],
      locationLat: json['location_lat'] != null 
          ? double.tryParse(json['location_lat'].toString()) 
          : null,
      locationLng: json['location_lng'] != null
          ? double.tryParse(json['location_lng'].toString())
          : null,
      matchScore: double.tryParse(json['match_score']!.toString().replaceAll('%', '')) ?? 0.0,
      distance: json['distance'] != null
          ? double.tryParse(json['distance'].toString().replaceAll(' كم', ''))
          : null,
      rating: double.tryParse(json['rating']!.toString()) ?? 0.0,
      avgPrice: double.tryParse(json['avg_price']!.toString()) ?? 0.0,
      matchingSpecialties: (json['matching_specialties'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      availableServices: json['available_services'] as List? ?? [],
      contactPhone: json['contact_phone'],
      contactEmail: json['contact_email'],
      avgSessionPrice: json['avg_session_price'] != null
          ? double.tryParse(json['avg_session_price'].toString())
          : null,
      isActive: json['is_active'] ?? true,
      
      specialties: json['specialties'] != null
          ? List<String>.from(json['specialties'])
          : null,
    );
  }

  String get distanceText {
    if (distance == null) return 'Not specified';
    return '${distance!.toStringAsFixed(1)} km';
  }

  String get matchScoreText {
    return '${matchScore.toStringAsFixed(0)}%';
  }

  String get ratingText {
    return rating.toStringAsFixed(1);
  }

  String get priceText {
    return '\$${avgPrice.toStringAsFixed(0)}';
  }
}