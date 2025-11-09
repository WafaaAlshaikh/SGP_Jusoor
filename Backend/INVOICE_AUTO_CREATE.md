# 🧾 نظام إنشاء الفواتير التلقائي

## ❌ المشكلة السابقة:
عند الحجز، كانت الجلسة تصل إلى حالة `Pending Payment` لكن لا يتم إنشاء فاتورة، مما يسبب خطأ:
```
"no invoice found for this session"
```

---

## ✅ الحل:
تم إضافة نظام **إنشاء فواتير تلقائي** عند وصول الجلسة إلى حالة `Pending Payment`.

---

## 🔧 التعديلات:

### 1. إضافة دالة Helper:
```javascript
// في sessionBookingController.js

async function createInvoiceForSession(session, child) {
  // جلب معلومات نوع الجلسة
  const sessionType = await SessionType.findByPk(session.session_type_id);
  
  // حساب المبلغ
  const amount = parseFloat(sessionType.price);
  const taxAmount = 0;
  const totalAmount = amount + taxAmount;
  
  // توليد رقم فاتورة فريد
  const invoiceNumber = `INV-${Date.now()}-${session.session_id}`;
  
  // تاريخ الاستحقاق (3 أيام من تاريخ الجلسة)
  const dueDate = new Date(session.date);
  dueDate.setDate(dueDate.getDate() + 3);
  
  // إنشاء الفاتورة
  const invoice = await Invoice.create({
    session_id: session.session_id,
    parent_id: child.parent_id,
    institution_id: session.institution_id,
    invoice_number: invoiceNumber,
    amount: amount,
    tax_amount: taxAmount,
    total_amount: totalAmount,
    status: 'Pending',
    due_date: dueDate,
    issued_date: new Date(),
    notes: `Invoice for ${sessionType.name} session on ${session.date}`
  });
  
  return invoice;
}
```

### 2. تعديل دالة `bookSession`:
```javascript
// بعد إنشاء الجلسة
if (sessionStatus === 'Pending Payment') {
  const invoice = await createInvoiceForSession(newSession, child);
  invoiceId = invoice.invoice_id;
}

// في الـ Response
res.json({
  ...
  invoice_id: invoiceId // ⬅️ إرجاع invoice_id للـ Frontend
});
```

### 3. تعديل دالة `managerApproveSession`:
```javascript
// بعد تحديث الجلسة إلى Pending Payment
const child = await Child.findByPk(session.child_id);
const invoice = await createInvoiceForSession(session, child);

res.json({
  ...
  invoice_id: invoiceId // ⬅️ إرجاع invoice_id
});
```

---

## 📊 سير العمل الجديد:

### **السيناريو 1: أول حجز**
```
1. Parent books session
   ↓
   Status: "Pending Manager Approval"
   Invoice: لا توجد ❌
   
2. Manager approves
   ↓
   Status: "Pending Payment"
   Invoice: تم الإنشاء تلقائياً ✅
   
3. Parent pays via invoice
   ↓
   Status: "Confirmed"
   Invoice Status: "Paid"
```

### **السيناريو 2: حجوزات لاحقة**
```
1. Parent books session
   ↓
   Status: "Pending Payment"
   Invoice: تم الإنشاء تلقائياً ✅
   
2. Parent pays
   ↓
   Status: "Confirmed"
   Invoice Status: "Paid"
```

---

## 🧾 بنية الفاتورة:

```javascript
{
  invoice_id: 123,
  invoice_number: "INV-1699876543210-456", // فريد
  session_id: 456,
  parent_id: 201,
  institution_id: 101,
  amount: 50.00,          // سعر الجلسة
  tax_amount: 0.00,       // ضريبة (يمكن إضافتها لاحقاً)
  total_amount: 50.00,    // المجموع
  status: "Pending",      // أو "Paid", "Overdue", "Cancelled"
  due_date: "2025-01-18", // 3 أيام من تاريخ الجلسة
  issued_date: "2025-01-15",
  notes: "Invoice for Behavioral Therapy Session session on 2025-01-15"
}
```

---

## 🔄 ربط الفاتورة بالدفع:

### **استخدام نظام الفواتير القديم:**
```javascript
// Frontend يستخدم
PaymentService.getParentInvoices(token)
PaymentService.processPayment(invoiceId, paymentMethod)
```

### **استخدام نظام الدفع المبسط الجديد:**
```javascript
// Frontend يستخدم
BookingService.confirmPayment(sessionId, paymentMethod)
```

---

## 💡 **الفرق بين النظامين:**

| الميزة | نظام الفواتير | نظام الدفع المبسط |
|--------|---------------|-------------------|
| **الاستخدام** | معقد - يدعم طرق دفع متعددة | بسيط - دفع مباشر |
| **Invoice** | ✅ يتطلب فاتورة | ❌ لا يتطلب |
| **API** | `/api/payments/*` | `/api/booking/confirm-payment` |
| **مناسب لـ** | نظام دفع كامل بتقارير | حجوزات بسيطة |

---

## 🎯 التوصية:

استخدم **نظام الفواتير** لأنه:
1. ✅ يوفر سجل كامل للفواتير
2. ✅ يدعم تقارير مالية
3. ✅ يمكن إضافة ضرائب ورسوم
4. ✅ يمكن إرسال الفاتورة بالبريد الإلكتروني
5. ✅ يدعم الفواتير المتأخرة (Overdue)

---

## 🧪 اختبار النظام:

### 1. احجز جلسة:
```bash
POST /api/booking/book-session
```

### 2. تحقق من الفاتورة:
```bash
GET /api/payments/invoices
```

### 3. ادفع الفاتورة:
```bash
POST /api/payments/process-payment
Body: {
  "invoice_id": 123,
  "payment_method": "Cash"
}
```

---

## 📝 Logs للتحقق:

بعد الحجز، ستظهر في console:
```
✅ Invoice created: INV-1699876543210-456 for session 123
📄 Invoice 123 created for session 456
```

---

## ⚠️ ملاحظات:

1. **تاريخ الاستحقاق**: 3 أيام من تاريخ الجلسة (قابل للتعديل)
2. **الضريبة**: حالياً 0% (يمكن إضافتها لاحقاً)
3. **معالجة الأخطاء**: إذا فشل إنشاء الفاتورة، يتم تسجيل الخطأ لكن الجلسة تُحفظ
4. **رقم الفاتورة**: فريد ويستخدم timestamp + session_id

---

## ✅ الآن كل شيء يعمل!

الجلسات تُنشئ فواتير تلقائياً ✅  
لا مزيد من خطأ "no invoice found" ✅  
النظام جاهز للاستخدام ✅
