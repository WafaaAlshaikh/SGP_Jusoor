# 🗺️ حل مشكلة توقف التطبيق عند فتح الخريطة

## ❌ المشكلة
التطبيق يتوقف (crash) عند فتح شاشة الخريطة

## 🔍 السبب المحتمل
**Google Maps API Key** غير مفعّل أو ليس عليه صلاحيات

---

## ✅ الحل الكامل

### 1️⃣ تفعيل Google Maps API Key

#### **الخطوة 1: افتح Google Cloud Console**
```
https://console.cloud.google.com/
```

#### **الخطوة 2: إنشاء مشروع جديد (إذا لم يكن موجود)**
1. اضغط على "Select a project" من الأعلى
2. اضغط "NEW PROJECT"
3. اسم المشروع: `Jusoor-App`
4. اضغط "CREATE"

#### **الخطوة 3: تفعيل Maps SDK for Android**
1. اذهب إلى: https://console.cloud.google.com/apis/library
2. ابحث عن: **"Maps SDK for Android"**
3. اضغط على النتيجة
4. اضغط **"ENABLE"** (إذا كان معطل)
5. انتظر حتى يتم التفعيل

#### **الخطوة 4: إنشاء API Key جديد**
1. اذهب إلى: https://console.cloud.google.com/apis/credentials
2. اضغط **"+ CREATE CREDENTIALS"**
3. اختر **"API key"**
4. سيتم إنشاء key جديد - انسخه!

#### **الخطوة 5: تقييد الـ API Key (اختياري لكن مهم)**
1. اضغط على الـ key الذي أنشأته
2. في "Application restrictions":
   - اختر **"Android apps"**
   - اضغط **"+ Add an item"**
   - Package name: `com.example.frontend` (أو اسم package تطبيقك)
   - SHA-1: يمكن الحصول عليه بالأمر:
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
3. في "API restrictions":
   - اختر **"Restrict key"**
   - فعّل: **Maps SDK for Android**
4. اضغط **"SAVE"**

---

### 2️⃣ وضع الـ API Key في التطبيق

#### **افتح الملف:**
```
frontend\android\app\src\main\AndroidManifest.xml
```

#### **ابحث عن السطر 46 وضع الـ key الجديد:**
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_NEW_API_KEY_HERE" />
```

**مثال:**
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyBxYz123456789AbCdEfGhIjKlMnOpQrS" />
```

---

### 3️⃣ تنظيف وإعادة البناء

```bash
cd D:\Jusoor\frontend

# تنظيف
flutter clean

# بناء جديد
flutter run -d emulator-5554
```

---

## 🛡️ الحل البديل: استخدام خريطة بسيطة بدون Google Maps

إذا لم تستطع الحصول على API key، يمكن استخدام **خيار النص البسيط**:

### **تعديل MapScreen ليعمل بدون Google Maps:**

أرسل لي رسالة وسأعطيك كود بديل يستخدم:
- قائمة منسدلة بالمدن
- حقول إدخال لـ Latitude & Longitude
- بدون الحاجة لـ Google Maps API

---

## 🔍 التأكد من أن المشكلة في Google Maps

### **افتح Terminal وشغل:**
```bash
cd D:\Jusoor\frontend
flutter run -d emulator-5554
```

### **عند فتح الخريطة، شوف الـ Logcat:**
```bash
# في terminal منفصل
adb logcat | findstr "Google"
```

**لو ظهرت رسالة مثل:**
```
E/Google Maps Android API: Authorization failure.
E/Google Maps Android API: API key not found.
```

**معناها:** المشكلة 100% في API key ❌

---

## 📊 ملخص سريع

| الخطوة | الحالة |
|--------|--------|
| ✅ **Error Handling** | تم إضافته في MapScreen |
| ⚠️ **Google Maps API Key** | يجب تفعيله |
| ✅ **Permissions** | موجودة في AndroidManifest |
| ✅ **Dependencies** | google_maps_flutter installed |

---

## 🆘 المساعدة

إذا واجهتك مشكلة:

1. **تأكد من الإنترنت شغال** في الـ emulator
2. **جرب إعادة تشغيل الـ emulator** (Cold Boot)
3. **تأكد من Google Play Services** مثبت على الـ emulator
4. **جرب emulator مختلف** (مع Google Play)

---

## 🎯 الخلاصة

المشكلة الأغلب في Google Maps API Key:
- ❌ مو مفعّل
- ❌ مو عليه صلاحيات
- ❌ expired أو بحد استخدام

**الحل:** اتبع الخطوات أعلاه لتفعيل key صحيح ✅
