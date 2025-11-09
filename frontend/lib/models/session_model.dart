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
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      sessionId: json['sessionId']?.toString() ?? '',
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
    );
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