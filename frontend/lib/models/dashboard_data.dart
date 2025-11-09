// lib/models/dashboard_data.dart
class Parent {
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? occupation;
  final String profilePicture;

  Parent({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.occupation,
    required this.profilePicture,
  });

  factory Parent.fromJson(Map<String, dynamic> json) {
    return Parent(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      occupation: json['occupation'],
      profilePicture: json['profile_picture'] ?? '',
    );
  }
}

class Child {
  final String name;
  final String condition;
  final String image;

  Child({required this.name, required this.condition, required this.image});

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      name: json['name'] ?? '',
      condition: json['condition'] ?? '',
      image: json['image'] ?? '',
    );
  }
}

class Summaries {
  final int totalChildren;
  final int pendingRegistrations;
  final int upcomingSessions;
  final int newAIAdviceCount;
  final int newReportsCount;
  final List<dynamic> notifications;

  Summaries({
    required this.totalChildren,
    required this.pendingRegistrations,
    required this.upcomingSessions,
    required this.newAIAdviceCount,
    required this.newReportsCount,
    required this.notifications,
  });

  factory Summaries.fromJson(Map<String, dynamic> json) {
    return Summaries(
      totalChildren: json['totalChildren'] ?? 0,
      pendingRegistrations: json['pendingRegistrations'] ?? 0,
      upcomingSessions: json['upcomingSessions'] ?? 0,
      newAIAdviceCount: json['newAIAdviceCount'] ?? 0,
      newReportsCount: json['newReportsCount'] ?? 0,
      notifications: json['notifications'] ?? [],
    );
  }
}

class DashboardData {
  final Parent parent;
  final List<Child> children;
  final Summaries summaries;

  DashboardData({
    required this.parent,
    required this.children,
    required this.summaries,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    var childrenJson = json['children'] as List<dynamic>? ?? [];
    List<Child> childrenList = childrenJson.map((c) => Child.fromJson(c)).toList();

    return DashboardData(
      parent: Parent.fromJson(json['parent'] ?? {}),
      children: childrenList,
      summaries: Summaries.fromJson(json['summaries'] ?? {}),
    );
  }
}