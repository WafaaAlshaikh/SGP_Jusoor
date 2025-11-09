// models/booking_models.dart

class SessionType {
  final int sessionTypeId;
  final String name;
  final int duration;
  final double price;
  final String category;
  final String description;
  final String specialistSpecialization;
  final bool isSuitable;
  final String suitabilityReason;
  final List<dynamic> targetConditions;
  final Map<String, dynamic>? institutionInfo;

  SessionType({
    required this.sessionTypeId,
    required this.name,
    required this.duration,
    required this.price,
    required this.category,
    required this.description,
    required this.specialistSpecialization,
    this.isSuitable = true,
    this.suitabilityReason = '',
    this.targetConditions = const [],
    this.institutionInfo,
  });

  factory SessionType.fromJson(Map<String, dynamic> json) {
    return SessionType(
      sessionTypeId: json['session_type_id'] ?? json['id'] ?? 0,
      name: json['name'] ?? '',
      duration: _parseInt(json['duration']),
      price: _parsePrice(json['price']),
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      specialistSpecialization: json['specialist_specialization'] ?? '',
      isSuitable: json['is_suitable'] ?? true,
      suitabilityReason: json['suitability_reason'] ?? '',
      targetConditions: List<dynamic>.from(json['target_conditions'] ?? []),
      institutionInfo: json['institution_info'],
    );
  }

  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      final cleaned = price.replaceAll('\$', '').replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'session_type_id': sessionTypeId,
      'name': name,
      'duration': duration,
      'price': price,
      'category': category,
      'description': description,
      'specialist_specialization': specialistSpecialization,
      'is_suitable': isSuitable,
      'suitability_reason': suitabilityReason,
      'target_conditions': targetConditions,
      'institution_info': institutionInfo,
    };
  }
}

class AvailableSlot {
  final int specialistId;
  final String specialistName;
  final String dayOfWeek;
  final String time;
  final int duration;
  final double price;
  final int sessionTypeId;

  AvailableSlot({
    required this.specialistId,
    required this.specialistName,
    required this.dayOfWeek,
    required this.time,
    required this.duration,
    required this.price,
    required this.sessionTypeId,
  });

  factory AvailableSlot.fromJson(Map<String, dynamic> json) {
    return AvailableSlot(
      specialistId: SessionType._parseInt(json['specialist_id']),
      specialistName: json['specialist_name'] ?? '',
      dayOfWeek: json['day_of_week'] ?? '',
      time: json['time'] ?? '',
      duration: SessionType._parseInt(json['duration']),
      price: SessionType._parsePrice(json['price']),
      sessionTypeId: SessionType._parseInt(json['session_type_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'specialist_id': specialistId,
      'specialist_name': specialistName,
      'day_of_week': dayOfWeek,
      'time': time,
      'duration': duration,
      'price': price,
      'session_type_id': sessionTypeId,
    };
  }
}

class SessionDetails {
  final int sessionId;
  final String date;
  final String time;
  final String status;
  final String sessionType;
  final int duration;
  final double price;
  final String specialistName;
  final String childName;
  final String institutionName;
  final bool requestedByParent;
  final String? parentNotes;

  SessionDetails({
    required this.sessionId,
    required this.date,
    required this.time,
    required this.status,
    required this.sessionType,
    required this.duration,
    required this.price,
    required this.specialistName,
    required this.childName,
    required this.institutionName,
    required this.requestedByParent,
    this.parentNotes,
  });

  factory SessionDetails.fromJson(Map<String, dynamic> json) {
    return SessionDetails(
      sessionId: json['session_id'] ?? 0,
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      status: json['status'] ?? '',
      sessionType: json['session_type'] ?? '',
      duration: SessionType._parseInt(json['duration']),
      price: SessionType._parsePrice(json['price']),
      specialistName: json['specialist_name'] ?? '',
      childName: json['child_name'] ?? '',
      institutionName: json['institution_name'] ?? '',
      requestedByParent: json['requested_by_parent'] ?? false,
      parentNotes: json['parent_notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'date': date,
      'time': time,
      'status': status,
      'session_type': sessionType,
      'duration': duration,
      'price': price,
      'specialist_name': specialistName,
      'child_name': childName,
      'institution_name': institutionName,
      'requested_by_parent': requestedByParent,
      'parent_notes': parentNotes,
    };
  }
}

class SessionModel {
  final int sessionId;
  final String childName;
  final String specialistName;
  final String institutionName;
  final String date;
  final String time;
  final int? duration;
  final double? price;
  final String sessionType;
  final String status;
  final String? sessionLocation;
  final String? cancellationReason;
  final double? rating;
  final double? sessionTypePrice;

  SessionModel({
    required this.sessionId,
    required this.childName,
    required this.specialistName,
    required this.institutionName,
    required this.date,
    required this.time,
    this.duration,
    this.price,
    required this.sessionType,
    required this.status,
    this.sessionLocation,
    this.cancellationReason,
    this.rating,
    this.sessionTypePrice,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      sessionId: json['sessionId'] ?? json['session_id'] ?? 0,
      childName: json['childName'] ?? json['child_name'] ?? '',
      specialistName: json['specialistName'] ?? json['specialist_name'] ?? '',
      institutionName: json['institutionName'] ?? json['institution_name'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      duration: SessionType._parseInt(json['duration']),
      price: SessionType._parsePrice(json['price']),
      sessionType: json['sessionType'] ?? json['session_type'] ?? '',
      status: json['status'] ?? '',
      sessionLocation: json['sessionLocation'] ?? json['session_location'],
      cancellationReason: json['cancellationReason'] ?? json['cancellation_reason'],
      rating: (json['rating'] ?? json['session_rating'])?.toDouble(),
      sessionTypePrice: SessionType._parsePrice(json['sessionTypePrice'] ?? json['session_type_price']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'child_name': childName,
      'specialist_name': specialistName,
      'institution_name': institutionName,
      'date': date,
      'time': time,
      'duration': duration,
      'price': price,
      'session_type': sessionType,
      'status': status,
      'session_location': sessionLocation,
      'cancellation_reason': cancellationReason,
      'rating': rating,
      'session_type_price': sessionTypePrice,
    };
  }

  String get displayStatus {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case 'confirmed':
      case 'approved':
        return 'upcoming';
      case 'pending payment':
        return 'pending_payment';
      case 'completed':
        return 'completed';
      case 'cancelled':
      case 'refunded':
        return 'cancelled';
      case 'rejected':
        return 'rejected';
      case 'pending manager approval':
        return 'pending_manager';
      case 'pending specialist approval':
      case 'pending approval':
      default:
        return 'pending';
    }
  }

  String get displayStatusArabic {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'معتمدة';
      case 'scheduled':
      case 'confirmed':
        return 'مجدولة';
      case 'pending payment':
        return 'بانتظار الدفع';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغية';
      case 'rejected':
        return 'مرفوضة';
      case 'pending manager approval':
        return 'بانتظار موافقة المدير';
      case 'pending specialist approval':
      case 'pending approval':
        return 'بانتظار الموافقة';
      default:
        return status;
    }
  }
}

// ⬇️⬇️⬇️ التصحيح الكامل لـ BookingResponse
class BookingResponse {
  final bool success;
  final String message;
  final int? sessionId;
  final String status;
  final Map<String, dynamic>? sessionDetails;
  final bool? isFirstBooking; // ⬅️ جديد
  final bool? requiresManagerApproval; // ⬅️ جديد

  BookingResponse({
    required this.success,
    required this.message,
    this.sessionId,
    required this.status,
    this.sessionDetails,
    this.isFirstBooking,
    this.requiresManagerApproval,
  });

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      success: json['success'] ?? (json['session_id'] != null),
      message: json['message'] ?? '',
      sessionId: json['session_id'],
      status: json['status'] ?? 'Pending Approval',
      sessionDetails: json['session_details'],
      isFirstBooking: json['is_first_booking'],
      requiresManagerApproval: json['requires_manager_approval'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'session_id': sessionId,
      'status': status,
      'session_details': sessionDetails,
      'is_first_booking': isFirstBooking,
      'requires_manager_approval': requiresManagerApproval,
    };
  }
}

class BookingRequest {
  final int childId;
  final int institutionId;
  final int sessionTypeId;
  final int specialistId;
  final String date;
  final String time;
  final String? parentNotes;

  BookingRequest({
    required this.childId,
    required this.institutionId,
    required this.sessionTypeId,
    required this.specialistId,
    required this.date,
    required this.time,
    this.parentNotes,
  });

  Map<String, dynamic> toJson() {
    return {
      'child_id': childId,
      'institution_id': institutionId,
      'session_type_id': sessionTypeId,
      'specialist_id': specialistId,
      'date': date,
      'time': time,
      if (parentNotes != null && parentNotes!.isNotEmpty)
        'parent_notes': parentNotes,
    };
  }
}

class AvailableSlotsResponse {
  final String sessionType;
  final List<AvailableSlot> availableSlots;

  AvailableSlotsResponse({
    required this.sessionType,
    required this.availableSlots,
  });

  factory AvailableSlotsResponse.fromJson(Map<String, dynamic> json) {
    return AvailableSlotsResponse(
      sessionType: json['session_type'] ?? '',
      availableSlots: (json['available_slots'] as List? ?? [])
          .map((slot) => AvailableSlot.fromJson(slot))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_type': sessionType,
      'available_slots': availableSlots.map((slot) => slot.toJson()).toList(),
    };
  }
}

class InstitutionSessionTypesResponse {
  final int institutionId;
  final List<SessionType> sessionTypes;

  InstitutionSessionTypesResponse({
    required this.institutionId,
    required this.sessionTypes,
  });

  factory InstitutionSessionTypesResponse.fromJson(Map<String, dynamic> json) {
    return InstitutionSessionTypesResponse(
      institutionId: json['institution_id'] ?? 0,
      sessionTypes: (json['session_types'] as List? ?? [])
          .map((type) => SessionType.fromJson(type))
          .toList(),
    );
  }
}

class BookingConfirmation {
  final bool success;
  final String message;
  final int sessionId;
  final String status;
  final DateTime? nextPaymentDue;
  final double? amountDue;

  BookingConfirmation({
    required this.success,
    required this.message,
    required this.sessionId,
    required this.status,
    this.nextPaymentDue,
    this.amountDue,
  });

  factory BookingConfirmation.fromJson(Map<String, dynamic> json) {
    return BookingConfirmation(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      sessionId: json['session_id'] ?? 0,
      status: json['status'] ?? '',
      nextPaymentDue: json['next_payment_due'] != null
          ? DateTime.parse(json['next_payment_due'])
          : null,
      amountDue: SessionType._parsePrice(json['amount_due']),
    );
  }
}

class Specialist {
  final int specialistId;
  final String name;
  final String specialization;
  final String? profilePicture;
  final double rating;
  final int yearsExperience;
  final String? bio;

  Specialist({
    required this.specialistId,
    required this.name,
    required this.specialization,
    this.profilePicture,
    required this.rating,
    required this.yearsExperience,
    this.bio,
  });

  factory Specialist.fromJson(Map<String, dynamic> json) {
    return Specialist(
      specialistId: json['specialist_id'] ?? 0,
      name: json['name'] ?? json['full_name'] ?? '',
      specialization: json['specialization'] ?? '',
      profilePicture: json['profile_picture'],
      rating: (json['rating'] ?? 0.0).toDouble(),
      yearsExperience: json['years_experience'] ?? 0,
      bio: json['bio'],
    );
  }
}

class TimeSlot {
  final String startTime;
  final String endTime;
  final bool isAvailable;
  final String? specialistName;
  final int? specialistId;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    this.specialistName,
    this.specialistId,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      isAvailable: json['is_available'] ?? false,
      specialistName: json['specialist_name'],
      specialistId: json['specialist_id'],
    );
  }
}

class DaySchedule {
  final String day;
  final List<TimeSlot> timeSlots;
  final bool isAvailable;

  DaySchedule({
    required this.day,
    required this.timeSlots,
    required this.isAvailable,
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      day: json['day'] ?? '',
      timeSlots: (json['time_slots'] as List? ?? [])
          .map((slot) => TimeSlot.fromJson(slot))
          .toList(),
      isAvailable: json['is_available'] ?? false,
    );
  }
}

class BookingSummary {
  final SessionType sessionType;
  final AvailableSlot selectedSlot;
  final Child child;
  final DateTime selectedDate;
  final String parentNotes;
  final double totalPrice;
  final double? discount;
  final double finalPrice;

  BookingSummary({
    required this.sessionType,
    required this.selectedSlot,
    required this.child,
    required this.selectedDate,
    required this.parentNotes,
    required this.totalPrice,
    this.discount,
    required this.finalPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'session_type': sessionType.toJson(),
      'selected_slot': selectedSlot.toJson(),
      'child': {
        'id': child.id,
        'full_name': child.fullName,
      },
      'selected_date': selectedDate.toIso8601String(),
      'parent_notes': parentNotes,
      'total_price': totalPrice,
      'discount': discount,
      'final_price': finalPrice,
    };
  }
}

class Child {
  final int id;
  final String fullName;
  final int? age;
  final String? condition;
  final String? photo;
  final String registrationStatus;
  final int? currentInstitutionId;
  final String? currentInstitutionName;

  Child({
    required this.id,
    required this.fullName,
    this.age,
    this.condition,
    this.photo,
    required this.registrationStatus,
    this.currentInstitutionId,
    this.currentInstitutionName,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] ?? json['child_id'] ?? 0,
      fullName: json['full_name'] ?? '',
      age: json['age'],
      condition: json['condition'],
      photo: json['photo'],
      registrationStatus: json['registration_status'] ?? 'Not Registered',
      currentInstitutionId: json['current_institution_id'],
      currentInstitutionName: json['current_institution_name'],
    );
  }
}

class BookingError {
  final String code;
  final String message;
  final String? details;

  BookingError({
    required this.code,
    required this.message,
    this.details,
  });

  factory BookingError.fromJson(Map<String, dynamic> json) {
    return BookingError(
      code: json['code'] ?? 'UNKNOWN_ERROR',
      message: json['message'] ?? 'An unknown error occurred',
      details: json['details'],
    );
  }

  @override
  String toString() {
    return 'BookingError{code: $code, message: $message, details: $details}';
  }
}

class BookingValidationResult {
  final bool isValid;
  final List<String> errors;
  final bool isChildRegistered;
  final bool isInstitutionAvailable;
  final bool isSpecialistAvailable;

  BookingValidationResult({
    required this.isValid,
    required this.errors,
    required this.isChildRegistered,
    required this.isInstitutionAvailable,
    required this.isSpecialistAvailable,
  });

  factory BookingValidationResult.fromJson(Map<String, dynamic> json) {
    return BookingValidationResult(
      isValid: json['is_valid'] ?? false,
      errors: List<String>.from(json['errors'] ?? []),
      isChildRegistered: json['is_child_registered'] ?? false,
      isInstitutionAvailable: json['is_institution_available'] ?? false,
      isSpecialistAvailable: json['is_specialist_available'] ?? false,
    );
  }
}