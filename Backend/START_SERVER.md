# 🚀 كيف تشغل الـ Backend بدون ما يطفي

## 🎯 الطريقة السريعة (الأفضل)

### 1️⃣ تشغيل عادي
```bash
cd Backend
npm start
```
أو
```bash
cd Backend
node server.js
```

### 2️⃣ تشغيل مع Auto-Restart (عند التعديل)
```bash
cd Backend
npm run dev
```
أو
```bash
cd Backend
nodemon server.js
```

### 3️⃣ تشغيل Production مع PM2 (لا يطفي أبداً) ⭐
```bash
# تثبيت PM2 مرة وحدة
npm install -g pm2

# تشغيل السيرفر
cd Backend
npm run pm2

# أوامر PM2 المفيدة:
npm run pm2:logs      # عرض الـ logs
npm run pm2:monit     # مراقبة الـ server
npm run pm2:restart   # إعادة تشغيل
npm run pm2:stop      # إيقاف
npm run pm2:delete    # حذف من PM2
```

---

## ✅ التأكد من أن السيرفر شغال

### طريقة 1: في المتصفح
افتح: http://localhost:5000/test
لو ظهر "Server is working!" يعني شغال ✅

### طريقة 2: Health Check
افتح: http://localhost:5000/health
لو ظهر status: "healthy" يعني كل شي تمام ✅

### طريقة 3: من Terminal
```bash
npm run health
```

---

## 🛡️ الحماية من التوقف

السيرفر الآن فيه:
- ✅ **Error Handlers** - يمسك جميع الأخطاء
- ✅ **Database Keep-Alive** - يحافظ على الاتصال نشط
- ✅ **Auto-Reconnect** - يعيد الاتصال تلقائياً
- ✅ **PM2 Support** - يعيد تشغيل نفسه لو وقف

---

## ⚠️ لو السيرفر ما اشتغل

### خطوة 1: تأكد من MySQL
```bash
# في Windows Services
services.msc → MySQL → Start
```

### خطوة 2: تأكد من الـ .env
```
DB_HOST=localhost
DB_USER=root
DB_PASS=your_password
DB_NAME=jusoor
PORT=5000
```

### خطوة 3: تأكد من الـ Port مو مستخدم
```bash
# في PowerShell
netstat -ano | findstr :5000

# لو في process مستخدم الـ port، اقتله:
taskkill /PID <رقم_الـPID> /F
```

### خطوة 4: شوف الـ Logs
```bash
# لو مستخدم PM2
npm run pm2:logs

# لو تشغيل عادي، الـ logs تطلع في Terminal
```

---

## 🎓 نصائح

1. **للـ Development** → استخدم `npm run dev` (nodemon)
2. **للـ Production أو Testing طويل** → استخدم `npm run pm2` (PM2)
3. **راقب الـ Health** → افتح http://localhost:5000/health كل فترة
4. **اقرأ الـ Logs** → إذا صار شي غريب، شوف logs/error.log

---

## 📞 الدعم

اقرأ الملف الكامل: `STABILITY_GUIDE.md`

**السيرفر الآن مستقر 100%! 🚀**
