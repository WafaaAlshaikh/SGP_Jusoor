// app_colors.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      
      // Primary Colors
      primaryColor: const Color(0xFF1A5A7A),
      primaryColorLight: const Color(0xFF5BA4D0),
      primaryColorDark: const Color(0xFF144A65),
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1A5A7A),
        secondary: Color(0xFFF4F4D0),
        tertiary: Color(0xFFFAEAB1),
        surface: Color(0xFFFFFFFF),
        background: Color(0xFFF0F7FF),
        error: Color(0xFFE74C3C),
        onPrimary: Colors.white,
        onSecondary: Color(0xFF1A2B3C),
        onSurface: Color(0xFF1A2B3C),
        onBackground: Color(0xFF1A2B3C),
        onError: Colors.white,
      ),
      
      // Scaffold
      scaffoldBackgroundColor: const Color(0xFFF0F7FF),
      cardColor: const Color(0xFFFFFFFF),
      canvasColor: const Color(0xFFF0F7FF),
      
      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Color(0xFF1A2B3C), fontSize: 96, fontWeight: FontWeight.w300),
        displayMedium: TextStyle(color: Color(0xFF1A2B3C), fontSize: 60, fontWeight: FontWeight.w300),
        displaySmall: TextStyle(color: Color(0xFF1A2B3C), fontSize: 48, fontWeight: FontWeight.w400),
        headlineMedium: TextStyle(color: Color(0xFF1A2B3C), fontSize: 34, fontWeight: FontWeight.w400),
        headlineSmall: TextStyle(color: Color(0xFF1A2B3C), fontSize: 24, fontWeight: FontWeight.w400),
        titleLarge: TextStyle(color: Color(0xFF1A2B3C), fontSize: 20, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: Color(0xFF5D6D7E), fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(color: Color(0xFF5D6D7E), fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(color: Color(0xFF8A9AAB), fontSize: 12, fontWeight: FontWeight.w400),
      ),
      
      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A5A7A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A5A7A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1A5A7A), width: 2),
        ),
      ),
      
      // Dividers
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      
      // Primary Colors
      primaryColor: const Color(0xFF5BA4D0),
      primaryColorLight: const Color(0xFF86C1E9),
      primaryColorDark: const Color(0xFF1A5A7A),
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5BA4D0),
        secondary: Color(0xFFFAEAB1),
        tertiary: Color(0xFFF4F4D0),
        surface: Color(0xFF1E1E1E),
        background: Color(0xFF121212),
        error: Color(0xFFEF5350),
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
      ),
      
      // Scaffold
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      canvasColor: const Color(0xFF121212),
      
      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.w300),
        displayMedium: TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.w300),
        displaySmall: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w400),
        headlineMedium: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w400),
        headlineSmall: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w400),
        titleLarge: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: Color(0xFFB0BEC5), fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(color: Color(0xFF78909C), fontSize: 12, fontWeight: FontWeight.w400),
      ),
      
      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A5A7A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5BA4D0),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF5BA4D0), width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFFB0BEC5)),
        hintStyle: const TextStyle(color: Color(0xFF78909C)),
      ),
      
      // Dividers
      dividerTheme: const DividerThemeData(
        color: Color(0xFF424242),
        thickness: 1,
        space: 1,
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF5BA4D0),
        foregroundColor: Colors.white,
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Color(0xFF5BA4D0),
        unselectedItemColor: Color(0xFF78909C),
      ),
    );
  }
}

// Class for custom colors (optional - for backward compatibility)
// تم تعديل هذه الدوال لتعمل كمتغيرات ثابتة بدلاً من دوال
class AppColor {
  // Colors from light theme (يمكن تغييرها حسب الـ theme لاحقاً)
  static const Color primaryLight = Color(0xFF1A5A7A);
  static const Color secondaryLight = Color(0xFFF4F4D0);
  static const Color tertiaryLight = Color(0xFFFAEAB1);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF0F7FF);
  static const Color errorLight = Color(0xFFE74C3C);
  static const Color successLight = Color(0xFF27AE60);
  static const Color warningLight = Color(0xFFF39C12);
  static const Color infoLight = Color(0xFF3498DB);
  static const Color textDarkLight = Color(0xFF1A2B3C);
  static const Color textGrayLight = Color(0xFF5D6D7E);
  static const Color textLightLight = Color(0xFF8A9AAB);
  static const Color accent1Light = Color(0xFFF4F4D0);
  static const Color accent2Light = Color(0xFFFAEAB1);
  static const Color accent3Light = Color(0xFFFAEAB1); // نفس tertiary
  static const Color accent4Light = Color(0xFF6366F1);
  static const Color creamLight = Color(0xFFF0F7FF);
  
  // Colors from dark theme
  static const Color primaryDark = Color(0xFF5BA4D0);
  static const Color secondaryDark = Color(0xFFFAEAB1);
  static const Color tertiaryDark = Color(0xFFF4F4D0);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color errorDark = Color(0xFFEF5350);
  static const Color successDark = Color(0xFF27AE60);
  static const Color warningDark = Color(0xFFF39C12);
  static const Color infoDark = Color(0xFF3498DB);
  static const Color textDarkDark = Colors.white;
  static const Color textGrayDark = Color(0xFFB0BEC5);
  static const Color textLightDark = Color(0xFF78909C);
  static const Color accent1Dark = Color(0xFFFAEAB1);
  static const Color accent2Dark = Color(0xFFF4F4D0);
  static const Color accent3Dark = Color(0xFFFAEAB1);
  static const Color accent4Dark = Color(0xFF6366F1);
  static const Color creamDark = Color(0xFF121212);
  
  // Helper methods to get colors based on brightness
  static bool _isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
  
  static Color primary(BuildContext context) => 
      _isDarkMode(context) ? primaryDark : primaryLight;
  
  static Color surface(BuildContext context) => 
      _isDarkMode(context) ? surfaceDark : surfaceLight;
  
  static Color background(BuildContext context) => 
      _isDarkMode(context) ? backgroundDark : backgroundLight;
  
  static Color textDark(BuildContext context) => 
      _isDarkMode(context) ? textDarkDark : textDarkLight;
  
  static Color textGray(BuildContext context) => 
      _isDarkMode(context) ? textGrayDark : textGrayLight;
  
  static Color textLight(BuildContext context) => 
      _isDarkMode(context) ? textLightDark : textLightLight;
  
  static Color error(BuildContext context) => 
      _isDarkMode(context) ? errorDark : errorLight;
  
  static Color success(BuildContext context) => 
      _isDarkMode(context) ? successDark : successLight;
  
  static Color warning(BuildContext context) => 
      _isDarkMode(context) ? warningDark : warningLight;
  
  static Color info(BuildContext context) => 
      _isDarkMode(context) ? infoDark : infoLight;
  
  static Color accent1(BuildContext context) => 
      _isDarkMode(context) ? accent1Dark : accent1Light;
  
  static Color accent2(BuildContext context) => 
      _isDarkMode(context) ? accent2Dark : accent2Light;
  
  static Color accent3(BuildContext context) => 
      _isDarkMode(context) ? accent3Dark : accent3Light;
  
  static Color accent4(BuildContext context) => 
      _isDarkMode(context) ? accent4Dark : accent4Light;
  
  static Color cream(BuildContext context) => 
      _isDarkMode(context) ? creamDark : creamLight;
  
  // Chat colors
  static Color myMessage(BuildContext context) => primary(context);
  static Color theirMessage(BuildContext context) => surface(context);
  static Color messageTextMe(BuildContext context) => Colors.white;
  static Color messageTextThem(BuildContext context) => textDark(context);
  static Color chatBackground(BuildContext context) => background(context);
}