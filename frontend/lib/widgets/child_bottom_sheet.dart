// lib/screens/manage_children/widgets/child_bottom_sheet.dart
// Bottom sheet لعرض تفاصيل الطفل - يستخدم ChildTabs الموجود في مشروعك
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import 'child_tabs.dart' as local_tabs; // path إذا كان في مكان مختلف عدّلي المسار

class ChildBottomSheet {
  static void show(BuildContext context, {required Child child}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.88,
          child: local_tabs.ChildTabs(child: child), // استخدام الـ ChildTabs المتوفر عندك
        );
      },
    );
  }
}
