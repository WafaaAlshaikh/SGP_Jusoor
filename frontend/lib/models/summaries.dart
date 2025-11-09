import 'notification_item.dart';
import 'session.dart';

class Summaries {
  final int upcomingSessions;
  final List<Session> upcomingSessionsList;
  final int newAIAdviceCount;
  final List<NotificationItem> notifications;
  final int newReportsCount;
  final int childrenCount;

  Summaries({
    required this.upcomingSessions,
    required this.upcomingSessionsList,
    required this.newAIAdviceCount,
    required this.notifications,
    required this.newReportsCount,
    required this.childrenCount,
  });

  factory Summaries.fromJson(Map<String, dynamic> json) {
    return Summaries(
      upcomingSessions: json['upcomingSessions'] ?? 0,
      upcomingSessionsList: (json['recentSessions'] as List<dynamic>?)
          ?.map((e) => Session.fromJson(e))
          .toList() ?? [],
      newReportsCount: json['newReportsCount'] ?? 0,
      newAIAdviceCount: json['newAIAdviceCount'] ?? 0,
      childrenCount: json['childrenCount'] ?? 0,
      notifications: (json['notifications'] as List<dynamic>?)
          ?.map((e) => NotificationItem.fromJson(e))
          .toList() ?? [],
    );
  }
}