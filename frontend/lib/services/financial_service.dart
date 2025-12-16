// services/financial_service.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/financial_assessment_models.dart';
import '../models/ParentFinancialModel.dart';
import 'package:frontend/services/api_service.dart';

class FinancialService {
  static Future<ParentFinancialModel?> getCachedFinancialProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('cached_financial_profile');

    if (profileJson != null) {
      try {
        return ParentFinancialModel.fromJson(jsonDecode(profileJson));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> cacheFinancialProfile(
      Map<String, dynamic> profileData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_financial_profile', jsonEncode(profileData));

    // Cache expiry date (1 day)
    await prefs.setString('cached_profile_expiry',
        DateTime.now().add(Duration(days: 1)).toIso8601String());
  }

  static Future<bool> shouldRefreshFinancialProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryString = prefs.getString('cached_profile_expiry');

    if (expiryString == null) return true;

    final expiryDate = DateTime.tryParse(expiryString);
    if (expiryDate == null) return true;

    return DateTime.now().isAfter(expiryDate);
  }

  static Future<ParentFinancialModel> getFinancialProfile() async {
    try {
      // Check cache first
      if (!await shouldRefreshFinancialProfile()) {
        final cached = await getCachedFinancialProfile();
        if (cached != null) {
          return cached;
        }
      }

      // Fetch fresh data
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await ApiService.getParentFinancialProfile(token);

      if (response['success'] == true) {
        final profile = ParentFinancialModel.fromJson(response['data']);

        // Update cache
        await cacheFinancialProfile(response['data']);

        return profile;
      } else {
        throw Exception('Failed to fetch financial profile');
      }
    } catch (e) {
      // Return cached data or default
      final cached = await getCachedFinancialProfile();
      if (cached != null) {
        return cached;
      }

      // Return default
      return ParentFinancialModel(
        parentId: 0,
        familySize: 1,
        dependentsCount: 0,
        receivesGovernmentSupport: false,
        financialScore: 0,
        financialTier: 'tier_5_no_assistance',
        credibilityScore: 50,
      );
    }
  }
}
