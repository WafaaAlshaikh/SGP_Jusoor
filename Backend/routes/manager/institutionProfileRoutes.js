const express = require('express');
const router = express.Router();
const institutionProfileController = require('../../controllers/manager/institutionProfileController');
const authMiddleware = require('../../middleware/authMiddleware');

// في institutionRoutes.js
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// تكوين multer لرفع الصور
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = 'uploads/profiles/';
    // إنشاء المجلد إذا لم يكن موجوداً
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'manager_' + req.user.user_id + '_' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: function (req, file, cb) {
    console.log('=== FILE UPLOAD INFO ===');
    console.log('Original name:', file.originalname);
    console.log('MIME type from client:', file.mimetype);
    console.log('Field name:', file.fieldname);
    
    // السماح بكل أنواع الصور و octet-stream
    const allowedMimeTypes = [
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/gif',
      'image/webp',
      'image/bmp',
      'image/svg+xml',
      'application/octet-stream' // إضافة هذا!
    ];
    
    // التحقق من الامتداد أيضاً
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
    const fileExtension = path.extname(file.originalname).toLowerCase();
    
    const hasValidExtension = allowedExtensions.includes(fileExtension);
    const hasValidMimeType = allowedMimeTypes.includes(file.mimetype);
    
    console.log('File extension:', fileExtension);
    console.log('Has valid extension:', hasValidExtension);
    console.log('Has valid MIME type:', hasValidMimeType);
    
    // إذا كان الامتداد صحيح، اقبله حتى لو كان MIME type هو octet-stream
    if (hasValidExtension || hasValidMimeType) {
      console.log('✅ File accepted');
      cb(null, true);
    } else {
      console.log('❌ File rejected');
      cb(new Error(`Invalid file. Extension: ${fileExtension}, MIME: ${file.mimetype}`), false);
    }
  }
});

// تأكد من أن المستخدم مدير
const isManager = (req, res, next) => {
  if (req.user.role !== 'Manager') {
    return res.status(403).json({
      success: false,
      message: 'غير مصرح - يجب أن تكون مدير مؤسسة'
    });
  }
  next();
};

// جلب بروفايل المؤسسة
router.get('/profile', 
  authMiddleware, 
  isManager, 
  institutionProfileController.getInstitutionProfile
);

// روت رفع صورة المدير
router.post('/upload_profile_picture', 
  authMiddleware, 
  isManager,
  upload.single('profile_picture'),
  institutionProfileController.uploadProfilePicture  // استدعاء الكونترولر
);

// تحديث بروفايل المؤسسة والمدير
router.put('/update_profile', 
  authMiddleware, 
  isManager, 
  institutionProfileController.updateInstitutionProfile
);

// تحديث صورة المدير (بدون ملف - فقط رابط)
router.put('/update_manager_picture', 
  authMiddleware, 
  isManager, 
  institutionProfileController.updateManagerProfilePicture
);

// Get institution reviews
router.get('/reviews', 
  authMiddleware, 
  isManager, 
  institutionProfileController.getInstitutionReviews
);

// // Get review summary
// router.get('/reviews/summary', 
//   authMiddleware, 
//   isManager, 
//   institutionProfileController.getReviewSummary
// );

// // NEW: Get AI-powered analysis
// router.get('/reviews/ai-analysis', 
//   authMiddleware, 
//   isManager, 
//   institutionProfileController.getAIAnalysis
// );

module.exports = router;