import 'package:flutter/material.dart';
import 'dart:async';

// CustomPainter لرسم شكل منحني بسيط في الخلفية (يمثل الجسر أو موجة رعاية)
class WavePainter extends CustomPainter {
  final Color waveColor;

  WavePainter(this.waveColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;

    final path = Path();
    // نقطة البداية
    path.moveTo(0, size.height * 0.5);
    // رسم منحنى علوي
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.2,
      size.width * 0.5, size.height * 0.5,
    );
    // رسم منحنى سفلي
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.8,
      size.width, size.height * 0.5,
    );
    // إكمال الشكل لإغلاق المسار من الأسفل
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 1. إعداد المتحكم الرئيسي للحركة (مدة الحركة 2 ثانية)
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    // 2. إعداد حركة الظهور التدريجي (Fade In)
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // 3. إعداد حركة الانزلاق من الأسفل للأعلى
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5), // يبدأ من أسفل بمسافة 0.5
      end: Offset(0, 0),    // ينتهي في موقعه الأصلي
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // بدء الحركة
    _controller.forward();

    // بدء مؤقت الانتقال (بعد 4 ثوانٍ من بدء الشاشة)
    Timer(Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // الألوان الجديدة المستخدمة
    // تم اختيار درجات الباستيل الهادئة والمريحة للعين
    final Color primaryPastelPurple = Color(0xFF8E88C7); // بنفسجي باستيل هادئ (للنصوص والخطوط)
    final Color backgroundTopLavender = Color(0xFFF0E5FF); // بنفسجي فاتح جداً للخلفية
    final Color backgroundBottomAqua = Color(0xFFA1D3CB); // أزرق/أخضر باستيل هادئ للخلفية

    return Scaffold(
      // إضافة تدرج لوني للخلفية بالكامل
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundTopLavender, backgroundBottomAqua],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // استخدام Stack لوضع العناصر فوق الخلفية وCustomPainter
        child: Stack(
          children: [
            // التفاصيل اللطيفة: شكل منحني في الأسفل (موجة أو جسر)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: Size(double.infinity, 200),
                painter: WavePainter(primaryPastelPurple.withOpacity(0.3)), // موجة بنفسجية شفافة
              ),
            ),

            // المحتوى الرئيسي مع حركتي الانزلاق والظهور
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0), // إضافة مسافة أفقية للتحكم بالكلمات
                child: SlideTransition(
                  position: _slideAnimation, // تطبيق حركة الانزلاق
                  child: FadeTransition(
                    opacity: _opacityAnimation, // تطبيق حركة الظهور
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // اللوجو
                        Image.asset(
                          'assets/images/jusoor_logo.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                          // تصميم بديل في حال فشل تحميل الصورة
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              color: primaryPastelPurple.withOpacity(0.1), // استخدام الباستيل الجديد
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.favorite, size: 150, color: primaryPastelPurple.withOpacity(0.7)), // استخدام الباستيل الجديد
                          ),
                        ),

                        SizedBox(height: 12), // مسافة أكبر قليلاً بين اسم التطبيق والوصف
                        Text(
                          // الجملة الجديدة
                          'Bridges of Hope Towards Our Children\'s Future',
                          textAlign: TextAlign.center, // توسيط النص
                          style: TextStyle(
                            fontSize: 24,
                            color: primaryPastelPurple.withOpacity(0.9), // استخدام الباستيل الجديد
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Chewy',
                          ),
                        ),
                        SizedBox(height: 50),
                        // مؤشر تحميل دائري
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryPastelPurple), // استخدام الباستيل الجديد
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}