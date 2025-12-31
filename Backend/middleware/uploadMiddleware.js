const multer = require('multer');
const path = require('path');
const fs = require('fs');

// إنشاء مجلد uploads/equipment إذا لم يكن موجوداً
const equipmentDir = path.join(__dirname, '../uploads/equipment');
if (!fs.existsSync(equipmentDir)) {
  fs.mkdirSync(equipmentDir, { recursive: true });
}

// إعداد multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, equipmentDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, 'equipment-' + uniqueSuffix + ext);
  }
});

// تصفية الملفات المسموح بها
const fileFilter = (req, file, cb) => {
  const allowedTypes = ['image/jpeg', 'image/png', 'image/jpg', 'image/gif'];
  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('نوع الملف غير مدعوم. يسمح بالصور فقط (JPEG, PNG, JPG, GIF)'), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB لكل صورة
    files: 5 // حد أقصى 5 ملفات
  }
});

module.exports = upload;