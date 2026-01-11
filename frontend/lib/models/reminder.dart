// models/reminder.dart
class SessionReminder {
  final String sessionId;
  final String sessionTitle;
  final DateTime sessionDateTime;
  final DateTime reminderTime;
  final bool isActive;

  SessionReminder({
    required this.sessionId,
    required this.sessionTitle,
    required this.sessionDateTime,
    required this.reminderTime,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
      'sessionDateTime': sessionDateTime.toIso8601String(),
      'reminderTime': reminderTime.toIso8601String(),
      'isActive': isActive,
    };
  }
}