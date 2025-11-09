import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ActivityService {
  static const String _activityKey = 'recent_activities';

  static Future<void> addActivity(String title, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> existing = prefs.getStringList(_activityKey) ?? [];

      final newActivity = {
        'title': title,
        'type': type,
        'time': DateTime.now().toIso8601String(),
        'iconCode': _getIconCode(type),
      };

      // 🔥 تحويل الـ Map إلى JSON بشكل آمن
      final String activityJson = jsonEncode(newActivity);
      existing.insert(0, activityJson);

      if (existing.length > 3) {
        existing = existing.sublist(0, 3);
      }

      await prefs.setStringList(_activityKey, existing);
     // print('✅ Activity added: $title');

    } catch (e) {
     // print('❌ Error adding activity: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLast3Activities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> activitiesData = prefs.getStringList(_activityKey) ?? [];

     // print('📂 Loaded ${activitiesData.length} activities from storage');

      List<Map<String, dynamic>> activities = [];

      for (String activityJson in activitiesData) {
        try {
          // 🔥 محاولة تحويل JSON بشكل آمن
          final activity = Map<String, dynamic>.from(jsonDecode(activityJson));
          activities.add(activity);
        } catch (jsonError) {
          //print('❌ Failed to parse activity: $activityJson');
          // تخطي العناصر التالفة
          continue;
        }
      }

      //print('🎯 Final activities list with ${activities.length} items');
      return activities;
    } catch (e) {
      //print('❌ Error getting activities: $e');
      return [];
    }
  }

  static String _getIconCode(String type) {
    switch (type) {
      case 'session': return 'calendar';
      case 'evaluation': return 'assessment';
      case 'post': return 'article';
      case 'message': return 'chat';
      case 'vacation': return 'beach_access';
      default: return 'history';
    }
  }

  static IconData getIconFromCode(String code) {
    switch (code) {
      case 'calendar': return Icons.calendar_today;
      case 'assessment': return Icons.assessment;
      case 'article': return Icons.article;
      case 'chat': return Icons.chat;
      case 'beach_access': return Icons.beach_access;
      default: return Icons.history;
    }
  }

  static Future<void> clearAllActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activityKey);
      //print('🗑️ All activities cleared');
    } catch (e) {
      //print('❌ Error clearing activities: $e');
    }
  }

  // 🔥 دالة مساعدة لإضافة أنشطة تجريبية للتست
  static Future<void> addSampleActivities() async {
    await addActivity('Session with Ahmed completed', 'session');
    await addActivity('New evaluation added for Sara', 'evaluation');
    await addActivity('Posted in community', 'post');
  }
}