import 'package:flutter/material.dart';

class ParentAppColors {
  static const Color primaryTeal = Color(0xFF4DB6AC); // اللون الأساسي الدافئ
  static const Color accentOrange = Color(0xFFFF9800); // لون ثانوي للتركيز
  static const Color backgroundLight = Color(0xFFF5F8FA); // خلفية نظيفة
  static const Color textName = Color(0xFFE5DDFD);
  static const Color textDark = Color(0xFF333333);
  static const Color textGrey = Color(0xFF888888);
  static const Color primaryColor = Color(0xFF4DB6AC);


  static const Color primaryBlue = Color(0xFF4A6FA5); // أزرق ناعم
  static const Color secondaryLavender = Color(0xFF8B85C1); // بنفسجي فاتح
  static const Color accentCoral = Color(0xFFFF7B7B); // مرجاني دافئ
  static const Color mintGreen = Color(0xFF7FD8BE); // أخضر نعناعي

  // ألوان محايدة
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF718096);
  static const Color borderLight = Color(0xFFE2E8F0);

  // ألوان للتدرجات
  static const Color gradientStart = Color(0xFF667EEA);
  static const Color gradientEnd = Color(0xFF764BA2);

  // ألوان الحالة
  static const Color successGreen = Color(0xFF48BB78);
  static const Color warningOrange = Color(0xFFED8936);
  static const Color errorRed = Color(0xFFF56565);
  static const Color infoBlue = Color(0xFF4299E1);

  // ألوان إضافية للشخصية
  static const Color softYellow = Color(0xFFFFD166);
  static const Color palePink = Color(0xFFFFB6C1);
  static const Color skyBlue = Color(0xFF87CEEB);

  // تدرجات جاهزة
  static LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient softGradient = LinearGradient(
    colors: [mintGreen, skyBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient warmGradient = LinearGradient(
    colors: [accentCoral, softYellow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
