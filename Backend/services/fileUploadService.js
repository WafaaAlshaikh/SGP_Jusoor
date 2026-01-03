// services/fileUploadService.js
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const crypto = require('crypto');

class FileUploadService {
  
  // إعداد مكان حفظ الملفات
  static storage = multer.diskStorage({
    destination: async (req, file, cb) => {
      const childId = req.params.id || 'temp';
      const uploadPath = path.join(__dirname, '../uploads/children', childId);
      
      // إنشاء المجلد إذا لم يكن موجوداً
      try {
        await fs.mkdir(uploadPath, { recursive: true });
        cb(null, uploadPath);
      } catch (error) {
        console.error('❌ Error creating upload directory:', error);
        cb(error);
      }
    },
    filename: (req, file, cb) => {
      // إنشاء اسم فريد للملف
      const uniqueSuffix = crypto.randomBytes(8).toString('hex');
      const ext = path.extname(file.originalname).toLowerCase();
      const baseName = path.basename(file.originalname, ext)
        .replace(/[^a-zA-Z0-9]/g, '_')
        .substring(0, 50);
      
      cb(null, `${Date.now()}_${uniqueSuffix}_${baseName}${ext}`);
    }
  });

  // ✅ فلترة أنواع الملفات المسموحة - النسخة المحسّنة
  static fileFilter = (req, file, cb) => {
    console.log('📄 File upload attempt:');
    console.log('   - Original name:', file.originalname);
    console.log('   - Mimetype:', file.mimetype);
    console.log('   - Size:', file.size);

    // الحصول على الامتداد من اسم الملف
    const ext = path.extname(file.originalname).toLowerCase();
    
    // قائمة الامتدادات المسموحة
    const allowedExtensions = ['.pdf', '.jpg', '.jpeg', '.png', '.doc', '.docx'];
    
    // قائمة MIME types المسموحة (شاملة)
    const allowedMimeTypes = [
      // PDF
      'application/pdf',
      'application/x-pdf',
      'application/acrobat',
      'applications/vnd.pdf',
      'text/pdf',
      'text/x-pdf',
      
      // Images
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/pjpeg', // Progressive JPEG
      'image/x-png',
      
      // Word Documents
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/doc',
      'application/ms-doc',
      'application/x-doc',
      'application/vnd.ms-word',
      
      // Fallback
      'application/octet-stream' // بعض المتصفحات بترسل هاد
    ];

    // التحقق من الامتداد أولاً
    if (!allowedExtensions.includes(ext)) {
      console.log('❌ File rejected: Invalid extension');
      return cb(new Error(`Invalid file type. Only PDF, JPG, PNG, DOC, DOCX allowed. Got: ${ext}`));
    }

    // التحقق من MIME type ثانياً
    if (!allowedMimeTypes.includes(file.mimetype)) {
      console.log('⚠️ Warning: Unusual MIME type, but extension is valid');
      console.log('   Allowing file based on extension...');
      // نسمح بالملف بناءً على الامتداد حتى لو الـ MIME type غريب
    }

    console.log('✅ File accepted');
    cb(null, true);
  };

  // إعداد Multer
  static upload = multer({
    storage: FileUploadService.storage,
    fileFilter: FileUploadService.fileFilter,
    limits: {
      fileSize: 10 * 1024 * 1024, // 10MB maximum
      files: 1 // ملف واحد فقط
    }
  });

  // حذف ملف
  static async deleteFile(filePath) {
    try {
      await fs.unlink(filePath);
      console.log(`✅ File deleted: ${filePath}`);
      return true;
    } catch (error) {
      console.error(`❌ Error deleting file: ${error.message}`);
      return false;
    }
  }

  // التحقق من نوع الملف بعد الرفع (أمان إضافي)
  static isValidFileType(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    const validExtensions = ['.pdf', '.jpg', '.jpeg', '.png', '.doc', '.docx'];
    return validExtensions.includes(ext);
  }
}

module.exports = FileUploadService;