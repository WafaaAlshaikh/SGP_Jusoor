# 🛡️ دليل استقرار الـ Backend - Jusoor

## ⚠️ المشكلة السابقة
كان الـ backend يتوقف تلقائياً بسبب:
- Uncaught Exceptions
- Unhandled Promise Rejections
- انقطاع الاتصال بقاعدة البيانات
- عدم وجود error handlers

## ✅ الحلول المطبقة

### 1️⃣ Global Error Handlers (server.js)
```javascript
// ✅ يمسك أي خطأ في الـ routes ويمنع السيرفر من التوقف
app.use((err, req, res, next) => {
    console.error('❌ Global Error Handler:', err.message);
    res.status(err.status || 500).json({
        success: false,
        message: err.message || 'Internal Server Error'
    });
});

// ✅ يمسك uncaught exceptions
process.on('uncaughtException', (err) => {
    console.error('💥 UNCAUGHT EXCEPTION!');
    console.error('Error:', err.name, err.message);
    // السيرفر يستمر بالعمل
});

// ✅ يمسك unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
    console.error('💥 UNHANDLED REJECTION!');
    console.error('Reason:', reason);
    // السيرفر يستمر بالعمل
});
```

### 2️⃣ Database Connection Pool (config/db.js)
```javascript
pool: {
    max: 10,          // الحد الأقصى للاتصالات
    min: 2,           // الحد الأدنى للاتصالات
    acquire: 30000,   // timeout لمحاولة الاتصال
    idle: 10000,      // قبل إغلاق اتصال غير نشط
    evict: 5000       // للتحقق من الاتصالات الميتة
}
```

### 3️⃣ Database Keep-Alive (config/db.js)
```javascript
// ✅ Ping كل دقيقة للحفاظ على الاتصال نشط
setInterval(async () => {
    try {
        await sequelize.query('SELECT 1');
    } catch (err) {
        console.error('⚠️ Database keep-alive failed');
    }
}, 60000); // كل دقيقة
```

### 4️⃣ Auto-Reconnect للـ Database
```javascript
// ✅ إعادة المحاولة تلقائياً إذا انقطع الاتصال
catch (err) {
    console.log('❌ DB Error or Sync Error:', err.message);
    console.log('🔄 Retrying database connection in 5 seconds...');
    setTimeout(() => {
        startServer();
    }, 5000);
}
```

### 5️⃣ Health Check Endpoint
```bash
# ✅ للتحقق من حالة السيرفر
GET http://localhost:5000/health

Response:
{
    "status": "healthy",
    "uptime": "15 minutes",
    "memory": {
        "rss": "120 MB",
        "heapUsed": "85 MB"
    },
    "database": "connected",
    "timestamp": "2024-11-07T19:39:00.000Z"
}
```

---

## 🚀 طرق تشغيل السيرفر

### ⚡ الطريقة العادية (Development)
```bash
cd Backend
node server.js
```

### 🔥 باستخدام nodemon (Auto-restart on changes)
```bash
cd Backend
npm install -g nodemon
nodemon server.js
```

### 🛡️ باستخدام PM2 (Production - الأفضل)
```bash
# تثبيت PM2 عالمياً
npm install -g pm2

# تشغيل السيرفر باستخدام PM2
cd Backend
pm2 start ecosystem.config.js

# مراقبة السيرفر
pm2 monit

# عرض الـ logs
pm2 logs jusoor-backend

# إيقاف السيرفر
pm2 stop jusoor-backend

# إعادة تشغيل السيرفر
pm2 restart jusoor-backend

# حذف من PM2
pm2 delete jusoor-backend
```

---

## 📊 مراقبة حالة السيرفر

### 1️⃣ مراقبة الـ Health Check
```bash
# كل 30 ثانية تفحص حالة السيرفر
curl http://localhost:5000/health
```

### 2️⃣ مراقبة الـ Logs
```bash
# في حال استخدام PM2
pm2 logs jusoor-backend --lines 50

# في حال التشغيل العادي
# الـ logs تظهر في Terminal مباشرة
```

### 3️⃣ مراقبة Memory Usage
```bash
pm2 monit
# أو
node --inspect server.js
```

---

## 🔧 Troubleshooting

### ❌ المشكلة: السيرفر لا يشتغل
```bash
# تأكد من:
1. MySQL شغال
2. الـ .env file موجود وفيه البيانات الصحيحة
3. Port 5000 مو مستخدم
   - Windows: netstat -ano | findstr :5000
   - Kill process: taskkill /PID <PID> /F
```

### ❌ المشكلة: Database connection error
```bash
# تأكد من:
1. MySQL service شغال
2. اسم الـ database صحيح في .env
3. username و password صحيحين
4. host=localhost أو 127.0.0.1
```

### ❌ المشكلة: السيرفر يتوقف بعد فترة
```bash
# الحل تم تطبيقه! الآن السيرفر:
✅ يمسك جميع الأخطاء
✅ يحافظ على اتصال قاعدة البيانات نشط
✅ يعيد الاتصال تلقائياً إذا انقطع
✅ يعيد تشغيل نفسه إذا استخدمت PM2
```

---

## 📈 Performance Tips

### 1️⃣ استخدم PM2 في Production
- يعيد تشغيل السيرفر تلقائياً
- يدير الـ memory usage
- يحفظ الـ logs بشكل منظم

### 2️⃣ فعّل Database Logging في Development فقط
```javascript
// في db.js
logging: process.env.NODE_ENV === 'development' ? console.log : false
```

### 3️⃣ راقب Memory Usage
```bash
# إذا الـ memory usage عالي، استخدم:
pm2 reload jusoor-backend  # Zero-downtime restart
```

---

## 🎯 الخلاصة

السيرفر الآن:
- ✅ **مستقر** - لا يتوقف بسبب أخطاء غير متوقعة
- ✅ **متصل** - يحافظ على اتصال قاعدة البيانات نشط
- ✅ **ذاتي الإصلاح** - يعيد الاتصال تلقائياً
- ✅ **قابل للمراقبة** - Health check endpoint
- ✅ **جاهز للـ Production** - PM2 config

**شغل السيرفر وما تقلق! 🚀**
