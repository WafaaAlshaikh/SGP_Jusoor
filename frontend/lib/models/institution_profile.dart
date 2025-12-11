class InstitutionProfile {
  final InstitutionData institution;
  final ManagerData manager;

  InstitutionProfile({
    required this.institution,
    required this.manager,
  });

  factory InstitutionProfile.fromJson(Map<String, dynamic> json) {
    return InstitutionProfile(
      institution: InstitutionData.fromJson(json['institution'] ?? {}),
      manager: ManagerData.fromJson(json['manager'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'institution': institution.toJson(),
      'manager': manager.toJson(),
    };
  }
}

class InstitutionData {
  final int institutionId;
  final String name;
  final String? description;
  final String? location;
  final String? locationAddress;
  final String? city;
  final String? region;
  final double? lat; // إضافة هذا
  final double? lng; // إضافة هذا
  final String? contactEmail;
  final String? contactPhone;
  final String? licenseNumber;
  final int? establishedYear;
  final List<String> servicesOffered;
  final List<String> conditionsSupported;
  final DateTime? createdAt;


  InstitutionData({
    required this.institutionId,
    required this.name,
    this.description,
    this.location,
    this.locationAddress,
    this.city,
    this.region,
    this.lat, // إضافة هذا
    this.lng, // إضافة هذا
    this.contactEmail,
    this.contactPhone,
    this.licenseNumber,
    this.establishedYear,
    required this.servicesOffered,
    required this.conditionsSupported,
    this.createdAt,
  });

  factory InstitutionData.fromJson(Map<String, dynamic> json) {
    // دالة لتحويل أي نوع إلى List<String>
    List<String> parseList(dynamic value) {
      if (value == null) {
        return [];
      }

      if (value is String) {
        // إذا كانت نصاً، اقسمها بفواصل
        if (value.isEmpty) return [];
        return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }

      if (value is List) {
        // إذا كانت مصفوفة، حولها إلى List<String>
        return value.map((item) {
          if (item is String) return item;
          return item.toString();
        }).where((item) => item.isNotEmpty).toList();
      }

      return [];
    }

    return InstitutionData(
      institutionId: json['institution_id'] is int ? json['institution_id'] : 0,
      name: json['name'] is String ? json['name'] : 'غير محدد',
      description: json['description'] is String ? json['description'] : null,
      location: json['location'] is String ? json['location'] : null,
      locationAddress: json['location_address'] is String ? json['location_address'] : null,
      city: json['city'] is String ? json['city'] : null,
      region: json['region'] is String ? json['region'] : null,
      lat: json['lat'] is num ? json['lat'].toDouble() : null, // إضافة هذا
      lng: json['lng'] is num ? json['lng'].toDouble() : null, // إضافة هذا
      contactEmail: json['contact_email'] is String ? json['contact_email'] : null,
      contactPhone: json['contact_phone'] is String ? json['contact_phone'] : null,
      licenseNumber: json['license_number'] is String ? json['license_number'] : null,
      establishedYear: json['established_year'] is int ? json['established_year'] : null,
      servicesOffered: parseList(json['services_offered']),
      conditionsSupported: parseList(json['conditions_supported']),
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'institution_id': institutionId,
      'name': name,
      'description': description,
      'location': location,
      'location_address': locationAddress,
      'city': city,
      'region': region,
      'lat': lat, // إضافة هذا
      'lng': lng, // إضافة هذا
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'license_number': licenseNumber,
      'established_year': establishedYear,
      'services_offered': servicesOffered,
      'conditions_supported': conditionsSupported,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // للاستخدام في الفورم (للتحرير)
  Map<String, dynamic> toUpdateJson() {
    return {
      'description': description ?? '',
      'location': location ?? '',
      'location_address': locationAddress ?? '',
      'city': city ?? '',
      'region': region ?? '',
      'lat': lat, // إضافة هذا
      'lng': lng, // إضافة هذا
      'contact_email': contactEmail ?? '',
      'contact_phone': contactPhone ?? '',
      'services_offered': servicesOffered,
      'conditions_supported': conditionsSupported,
    };
  }
}

class ManagerData {
  final int userId;
  final String fullName;
  final String email;
  final String? phone;
  final String? profilePicture;
  final DateTime? createdAt;

  ManagerData({
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    this.profilePicture,
    this.createdAt,
  });

  factory ManagerData.fromJson(Map<String, dynamic> json) {
    return ManagerData(
      userId: json['user_id'] is int ? json['user_id'] : 0,
      fullName: json['full_name'] is String ? json['full_name'] : 'غير محدد',
      email: json['email'] is String ? json['email'] : 'غير محدد',
      phone: json['phone'] is String ? json['phone'] : null,
      profilePicture: json['profile_picture'] is String ? json['profile_picture'] : null,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'profile_picture': profilePicture,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
