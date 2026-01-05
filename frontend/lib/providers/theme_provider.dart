// providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isDarkMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme') ?? 'light';
    
    setTheme(savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light);
  }

  void setTheme(ThemeMode themeMode) async {
    _themeMode = themeMode;
    _isDarkMode = themeMode == ThemeMode.dark;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', _isDarkMode ? 'dark' : 'light');
    
    notifyListeners();
  }

  void toggleTheme() {
    setTheme(_isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }
}