// lib/routes/parent_routes.dart
import 'package:flutter/material.dart';
import '../screens/EditProfileScreen.dart';
import '../screens/manage_children_screen.dart';
import '../screens/sessions_screen.dart';
import '../screens/educational_resources_screen.dart';
// استيراد بقية الشاشات حسب الحاجة

class ParentRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/parent/edit-profile':
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());

      case '/parent/manage-children':
        return MaterialPageRoute(builder: (_) => const ManageChildrenScreen());

      case '/parent/sessions':
        return MaterialPageRoute(builder: (_) => const SessionsScreen());

      case '/parent/educational-resources':
        return MaterialPageRoute(builder: (_) => const EducationalResourcesScreen());

    // يمكنك إضافة المزيد من الـ routes هنا

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}