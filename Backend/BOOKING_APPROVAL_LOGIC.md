# نظام موافقة الحجوزات - Smart Booking Approval System

## 📋 نظرة عامة (Overview)

تم تطبيق نظام موافقة ذكي للحجوزات يعتمد على سجل الحجوزات السابقة:
- **أول حجز**: يتطلب موافقة المدير (Manager Approval)
- **الحجوزات اللاحقة**: موافقة تلقائية إذا كان الموعد متاحاً

---

## 🔄 سير العمل (Workflow)

### 1️⃣ أول حجز للطفل في المؤسسة
```
الأهل يحجز جلسة
    ↓
النظام يتحقق: هل يوجد حجوزات سابقة معتمدة؟
    ↓ (لا)
الحالة: "Pending Manager Approval"
    ↓
المدير يراجع ويوافق/يرفض
    ↓ (موافقة)
الحالة: "Pending Payment"
    ↓
الأهل يدفع
    ↓
الحالة: "Confirmed"
```

### 2️⃣ حجوزات لاحقة (بعد الموافقة الأولى)
```
الأهل يحجز جلسة
    ↓
النظام يتحقق: هل يوجد حجوزات سابقة معتمدة؟
    ↓ (نعم)
الحالة: "Pending Payment" (مباشرة)
    ↓
الأهل يدفع
    ↓
الحالة: "Confirmed"
```

---

## 🗄️ تغييرات قاعدة البيانات

### حقول جديدة في جدول `Sessions`:
```sql
- is_first_booking: BOOLEAN        -- هل هو أول حجز؟
- approved_by_manager_id: BIGINT   -- معرف المدير الذي وافق
- manager_approval_date: DATETIME  -- تاريخ موافقة المدير
- manager_notes: TEXT              -- ملاحظات المدير
```

### حالات جديدة في `status` ENUM:
```sql
- 'Pending Manager Approval'      -- بانتظار موافقة المدير
- 'Pending Specialist Approval'   -- بانتظار موافقة الأخصائي
- 'Approved'                       -- معتمدة
- 'Rejected'                       -- مرفوضة
```

---

## 🔧 تطبيق Migration

### خطوات التطبيق:
```bash
# 1. إيقاف السيرفر
npm stop

# 2. نسخ احتياطي لقاعدة البيانات
mysqldump -u root -p jusoor_db > backup_before_migration.sql

# 3. تطبيق الـ Migration
mysql -u root -p jusoor_db < migrations/add_manager_approval_fields.sql

# 4. تشغيل السيرفر
npm start
```

### التحقق من نجاح التطبيق:
```sql
-- تحقق من الحقول الجديدة
DESCRIBE Sessions;

-- تحقق من القيم الافتراضية
SHOW CREATE TABLE Sessions;
```

---

## 📡 API Endpoints الجديدة

### للمدير (Manager):

#### 1. جلب الجلسات المعلقة
```http
GET /api/booking/manager/pending-sessions
Authorization: Bearer {manager_token}

Response:
{
  "success": true,
  "total_pending": 3,
  "sessions": [
    {
      "session_id": 123,
      "child_name": "محمد أحمد",
      "parent_name": "أحمد علي",
      "parent_contact": {
        "email": "parent@example.com",
        "phone": "+963123456789"
      },
      "specialist_name": "د. سارة محمود",
      "session_type": "Behavioral Therapy",
      "duration": 60,
      "price": 50.0,
      "date": "2025-01-15",
      "time": "10:00:00",
      "parent_notes": "أول جلسة للطفل",
      "is_first_booking": true
    }
  ]
}
```

#### 2. الموافقة على جلسة
```http
PUT /api/booking/manager/approve-session/:session_id
Authorization: Bearer {manager_token}

Body:
{
  "manager_notes": "تمت الموافقة بعد مراجعة ملف الطفل"
}

Response:
{
  "success": true,
  "message": "Session approved successfully",
  "session_id": 123,
  "new_status": "Approved"
}
```

#### 3. رفض جلسة
```http
PUT /api/booking/manager/reject-session/:session_id
Authorization: Bearer {manager_token}

Body:
{
  "manager_notes": "يرجى التواصل مع الإدارة أولاً"
}

Response:
{
  "success": true,
  "message": "Session rejected successfully",
  "session_id": 123,
  "new_status": "Rejected"
}
```

### للأهل (Parent):

#### 4. تأكيد الدفع
```http
POST /api/booking/confirm-payment/:session_id
Authorization: Bearer {parent_token}

Body:
{
  "payment_method": "Cash",  // or "Credit Card", "Bank Transfer"
  "transaction_id": "TXN123456789"  // optional
}

Response:
{
  "success": true,
  "message": "Payment confirmed successfully - your session is now scheduled",
  "session_id": 123,
  "new_status": "Confirmed",
  "session_details": {
    "child_name": "Omar Ahmad",
    "session_type": "Behavioral Therapy Session",
    "date": "2025-01-15",
    "time": "10:00:00",
    "duration": 60,
    "price": 50.0
  }
}
```

---

## 🎯 منطق التحقق من أول حجز

```javascript
// في sessionBookingController.js
const previousApprovedSessions = await Session.count({
  where: {
    child_id,
    institution_id,
    status: 'Approved'
  }
});

const isFirstBooking = previousApprovedSessions === 0;

if (isFirstBooking) {
  // → يذهب للمدير
  sessionStatus = 'Pending Manager Approval';
} else {
  // → موافقة تلقائية ثم ينتظر الدفع
  sessionStatus = 'Pending Payment';
}
```

---

## 🔐 صلاحيات المدير

### التحقق من الصلاحيات:
```javascript
const manager = await User.findByPk(managerId);

if (!manager || manager.role !== 'Manager') {
  return res.status(403).json({ 
    message: 'Access denied. Manager role required.' 
  });
}

// التحقق من أن الجلسة تتبع مؤسسة المدير
if (session.institution_id !== manager.institution_id) {
  return res.status(403).json({ 
    message: 'You can only manage sessions in your institution' 
  });
}
```

---

## 📱 تحديثات Frontend

### حالات الجلسة الجديدة في Models:
```dart
String get displayStatusArabic {
  switch (status.toLowerCase()) {
    case 'approved':
      return 'معتمدة';
    case 'pending manager approval':
      return 'بانتظار موافقة المدير';
    case 'rejected':
      return 'مرفوضة';
    // ... باقي الحالات
  }
}
```

### الرسائل المخصصة بعد الحجز:
```dart
if (bookingResponse.isFirstBooking == true) {
  // رسالة: جلستك بانتظار موافقة المدير
  message = 'تم إرسال طلب الحجز للمدير للموافقة';
} else {
  // رسالة: تم تأكيد الحجز مباشرة
  message = 'تم تأكيد حجزك بنجاح';
}
```

---

## 🧪 اختبار النظام

### سيناريو 1: أول حجز
```bash
# 1. حجز جلسة لطفل جديد
curl -X POST http://localhost:5000/api/booking/book-session \
-H "Authorization: Bearer {parent_token}" \
-H "Content-Type: application/json" \
-d '{
  "child_id": 1,
  "institution_id": 1,
  "session_type_id": 2,
  "specialist_id": 3,
  "date": "2025-01-15",
  "time": "10:00:00"
}'

# النتيجة المتوقعة:
# status: "Pending Manager Approval"
# is_first_booking: true
# requires_manager_approval: true
```

### سيناريو 2: حجز ثاني (بعد الموافقة)
```bash
# 1. المدير يوافق على الحجز الأول
curl -X PUT http://localhost:5000/api/booking/manager/approve-session/1 \
-H "Authorization: Bearer {manager_token}"

# 2. الأهل يحجز جلسة ثانية
curl -X POST http://localhost:5000/api/booking/book-session \
# ... نفس البيانات

# النتيجة المتوقعة:
# status: "Approved"
# is_first_booking: false
# requires_manager_approval: false
```

---

## 📊 تقارير وإحصائيات

### إحصائيات الحجوزات للمدير:
```sql
-- عدد الحجوزات المعلقة
SELECT COUNT(*) 
FROM Sessions 
WHERE institution_id = 1 
  AND status = 'Pending Manager Approval';

-- عدد الحجوزات الأولى
SELECT COUNT(*) 
FROM Sessions 
WHERE institution_id = 1 
  AND is_first_booking = TRUE;

-- معدل الموافقة
SELECT 
  COUNT(CASE WHEN status = 'Approved' THEN 1 END) as approved,
  COUNT(CASE WHEN status = 'Rejected' THEN 1 END) as rejected,
  ROUND(COUNT(CASE WHEN status = 'Approved' THEN 1 END) * 100.0 / COUNT(*), 2) as approval_rate
FROM Sessions 
WHERE institution_id = 1 
  AND is_first_booking = TRUE;
```

---

## ⚠️ نقاط مهمة

1. **الحجوزات القديمة**: جميع الحجوزات القديمة ستُعتبر "ليست أول حجز" بعد الـ Migration
2. **المديرين فقط**: فقط المستخدمين بدور "Manager" يمكنهم الموافقة/الرفض
3. **المؤسسة المطابقة**: المدير يمكنه فقط إدارة جلسات مؤسسته
4. **الموافقة التلقائية**: الحجوزات اللاحقة تُعتمد فوراً إذا كان الموعد متاحاً

---

## 🔄 Rollback في حالة وجود مشاكل

```sql
-- إزالة الحقول الجديدة
ALTER TABLE Sessions
DROP FOREIGN KEY fk_sessions_manager,
DROP INDEX idx_sessions_status,
DROP INDEX idx_sessions_first_booking,
DROP INDEX idx_sessions_manager_approval,
DROP COLUMN manager_notes,
DROP COLUMN manager_approval_date,
DROP COLUMN approved_by_manager_id,
DROP COLUMN is_first_booking;

-- إرجاع ENUM إلى القيم القديمة
ALTER TABLE Sessions 
MODIFY COLUMN status ENUM(
  'Pending Approval',
  'Pending Payment',
  'Confirmed',
  'Scheduled',
  'Completed',
  'Cancelled',
  'Refunded'
) DEFAULT 'Pending Approval';

-- إرجاع الحالات القديمة
UPDATE Sessions 
SET status = 'Pending Approval'
WHERE status = 'Pending Specialist Approval';
```

---

## 📞 الدعم

لأي استفسارات أو مشاكل:
- راجع الـ logs في: `backend/logs/`
- تحقق من الـ console output عند تشغيل السيرفر
- تأكد من تطبيق الـ Migration بنجاح
