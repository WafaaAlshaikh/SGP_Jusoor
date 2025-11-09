# 💳 كيفية استخدام نظام الدفع في الـ Frontend

## 📁 الملفات المضافة:

1. **`lib/services/booking_service.dart`** - تم إضافة دالة `confirmPayment()`
2. **`lib/widgets/payment_dialog.dart`** - Dialog جاهز للدفع

---

## 🎯 طريقة الاستخدام:

### 1️⃣ في صفحة الجلسات (Sessions List):

عندما تعرض قائمة الجلسات، افحص حالة كل جلسة:

```dart
import 'package:flutter/material.dart';
import '../models/booking_models.dart';
import '../widgets/payment_dialog.dart';
import '../services/auth_service.dart';

class SessionsListPage extends StatelessWidget {
  final List<SessionModel> sessions;

  const SessionsListPage({Key? key, required this.sessions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('جلسة ${session.sessionType}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التاريخ: ${session.date}'),
                Text('الحالة: ${session.displayStatusArabic}'),
              ],
            ),
            trailing: _buildActionButton(context, session),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, SessionModel session) {
    // إذا كانت الجلسة بحاجة للدفع
    if (session.status.toLowerCase() == 'pending payment') {
      return ElevatedButton.icon(
        onPressed: () => _showPaymentDialog(context, session),
        icon: const Icon(Icons.payment),
        label: const Text('ادفع الآن'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }
    
    // إذا كانت في انتظار موافقة المدير
    if (session.status.toLowerCase() == 'pending manager approval') {
      return Chip(
        label: const Text('بانتظار المدير'),
        backgroundColor: Colors.orange.shade100,
      );
    }
    
    // إذا كانت مؤكدة
    if (session.status.toLowerCase() == 'confirmed') {
      return const Chip(
        label: Text('مؤكدة'),
        backgroundColor: Colors.green,
      );
    }
    
    return const SizedBox.shrink();
  }

  Future<void> _showPaymentDialog(BuildContext context, SessionModel session) async {
    final token = await AuthService.getToken(); // احصل على الـ token
    
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PaymentDialog(
        sessionId: session.sessionId,
        token: token,
        sessionDetails: {
          'session_type': session.sessionType,
          'duration': session.duration,
          'price': session.price,
        },
      ),
    );

    // إذا تم الدفع بنجاح، أعد تحميل قائمة الجلسات
    if (result == true) {
      // TODO: أعد تحميل البيانات
      print('✅ تم الدفع بنجاح - أعد تحميل الجلسات');
    }
  }
}
```

---

### 2️⃣ بعد الحجز مباشرة:

عندما يحجز الأهل جلسة ويحصل على `Pending Payment`، اعرض زر الدفع فوراً:

```dart
// في صفحة الحجز بعد النجاح
Future<void> _handleBookingSuccess(BookingResponse response) async {
  if (response.status.toLowerCase() == 'pending payment') {
    // اعرض Dialog الدفع مباشرة
    final shouldPay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تم الحجز بنجاح!'),
        content: const Text('جلستك بحاجة للدفع الآن. هل تريد إتمام الدفع؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ادفع الآن'),
          ),
        ],
      ),
    );

    if (shouldPay == true) {
      _showPaymentDialog(response.sessionId!);
    }
  } else if (response.status.toLowerCase() == 'pending manager approval') {
    // رسالة للانتظار
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تم إرسال الطلب'),
        content: const Text('جلستك بانتظار موافقة المدير'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showPaymentDialog(int sessionId) async {
  final token = await AuthService.getToken();
  
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => PaymentDialog(
      sessionId: sessionId,
      token: token!,
      sessionDetails: {
        'session_type': _selectedSessionType?.name,
        'duration': _selectedSessionType?.duration,
        'price': _selectedSessionType?.price,
      },
    ),
  );

  if (result == true) {
    // انتقل لصفحة الجلسات
    Navigator.of(context).pushReplacementNamed('/sessions');
  }
}
```

---

### 3️⃣ في صفحة تفاصيل الجلسة:

```dart
class SessionDetailsPage extends StatelessWidget {
  final SessionModel session;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الجلسة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // عرض التفاصيل
            Text('النوع: ${session.sessionType}'),
            Text('التاريخ: ${session.date}'),
            Text('الحالة: ${session.displayStatusArabic}'),
            
            const SizedBox(height: 24),
            
            // زر الدفع
            if (session.status.toLowerCase() == 'pending payment')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(context),
                  icon: const Icon(Icons.payment),
                  label: const Text('ادفع الآن'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showPaymentDialog(BuildContext context) async {
    final token = await AuthService.getToken();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PaymentDialog(
        sessionId: session.sessionId,
        token: token!,
        sessionDetails: {
          'session_type': session.sessionType,
          'duration': session.duration,
          'price': session.price,
        },
      ),
    );

    if (result == true) {
      // أعد تحميل البيانات
      Navigator.of(context).pop(true); // ارجع للصفحة السابقة
    }
  }
}
```

---

## 🎨 تخصيص الـ Dialog:

يمكنك تخصيص الألوان والأيقونات في ملف `payment_dialog.dart`:

```dart
// تغيير اللون الأساسي
backgroundColor: Colors.blue, // بدلاً من Colors.green

// إضافة طرق دفع إضافية
final List<Map<String, dynamic>> _paymentMethods = [
  {'value': 'Cash', 'label': 'نقدي', 'icon': Icons.money},
  {'value': 'Credit Card', 'label': 'بطاقة ائتمان', 'icon': Icons.credit_card},
  {'value': 'Bank Transfer', 'label': 'تحويل بنكي', 'icon': Icons.account_balance},
  {'value': 'PayPal', 'label': 'باي بال', 'icon': Icons.payment}, // إضافة جديدة
];
```

---

## 🔍 التحقق من حالة الجلسة:

```dart
// في أي مكان تريد التحقق من حالة الجلسة
bool needsPayment(SessionModel session) {
  return session.status.toLowerCase() == 'pending payment';
}

bool isWaitingManagerApproval(SessionModel session) {
  return session.status.toLowerCase() == 'pending manager approval';
}

bool isConfirmed(SessionModel session) {
  return session.status.toLowerCase() == 'confirmed';
}

// استخدام
if (needsPayment(session)) {
  // اعرض زر الدفع
}
```

---

## 🧪 اختبار الدفع:

### السيناريو 1: أول حجز
1. سجل دخول كأهل: `ahmad.parent@example.com / 123456`
2. احجز جلسة → الحالة: **Pending Manager Approval**
3. سجل دخول كمدير: `sarah.manager@hopetherapy.sy / 123456`
4. وافق على الجلسة → الحالة: **Pending Payment**
5. ارجع كأهل → اضغط "ادفع الآن"
6. اختر طريقة الدفع → الحالة: **Confirmed** ✅

### السيناريو 2: حجز ثاني
1. احجز جلسة ثانية → الحالة: **Pending Payment** (مباشرة)
2. اضغط "ادفع الآن" → الحالة: **Confirmed** ✅

---

## 📱 UI Preview:

```
┌─────────────────────────────────┐
│  💳 تأكيد الدفع      جلسة #123  │
├─────────────────────────────────┤
│  📋 تفاصيل الجلسة               │
│  ├ نوع الجلسة: Behavioral       │
│  ├ المدة: 60 دقيقة              │
│  └ السعر: $50                   │
├─────────────────────────────────┤
│  طريقة الدفع:                   │
│  ⚪ 💵 نقدي                     │
│  ⚫ 💳 بطاقة ائتمان             │
│  ⚪ 🏦 تحويل بنكي               │
├─────────────────────────────────┤
│  رقم المعاملة: [________]       │
├─────────────────────────────────┤
│  [إلغاء]  [تأكيد الدفع ✓]      │
└─────────────────────────────────┘
```

---

## ⚠️ ملاحظات مهمة:

1. **التوكن**: تأكد من أن لديك توكن صالح قبل عرض Dialog الدفع
2. **إعادة التحميل**: بعد الدفع الناجح، أعد تحميل قائمة الجلسات
3. **معالجة الأخطاء**: تأكد من معالجة حالات الفشل بشكل صحيح
4. **UX**: اعرض مؤشر تحميل أثناء معالجة الدفع

---

## 🎉 جاهز للاستخدام!

الآن يمكنك استخدام نظام الدفع في أي مكان في التطبيق ببساطة باستدعاء:

```dart
showDialog(
  context: context,
  builder: (context) => PaymentDialog(
    sessionId: sessionId,
    token: token,
    sessionDetails: details,
  ),
);
```
