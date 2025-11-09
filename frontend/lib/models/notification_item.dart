// models/notification_item.dart
class NotificationItem {
  final String title;
  final String date;

  NotificationItem({required this.title, required this.date});

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      title: json['title'] ?? '',
      date: json['date'] ?? '',
    );
  }
}
