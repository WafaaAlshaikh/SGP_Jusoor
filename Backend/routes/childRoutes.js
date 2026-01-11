// routes/childRoutes.js - النسخة المحدثة
const express = require('express');
const router = express.Router();
const childController = require('../controllers/childController');
const authMiddleware = require('../middleware/authMiddleware');
const FileUploadService = require('../services/fileUploadService');
const multer = require('multer');

// ================= المسار الجديد: Multi-Step Process =================

// STEP 1: حفظ المعلومات الأساسية
router.post('/basic-info', authMiddleware, childController.saveChildBasicInfo);

// STEP 2: تحليل الحالة الطبية وإرجاع توصيات
router.post('/:id/medical-analysis', authMiddleware, childController.analyzeMedicalCondition);

// STEP 3: جلب المؤسسات مع الفلاتر
router.get('/:id/recommended-institutions', authMiddleware, childController.getInstitutionsWithFilters);

// STEP 4: طلب التسجيل
router.post('/:id/request-registration', authMiddleware, childController.requestInstitutionRegistration);

// ================= المسارات الأصلية (للتوافق) =================
router.get('/', authMiddleware, childController.getChildren);
router.post('/', authMiddleware, childController.addChild); // الطريقة القديمة
router.post('/symptoms-search', authMiddleware, childController.searchBySymptoms);
router.get('/stats', authMiddleware, childController.getChildStatistics);
router.get('/:id', authMiddleware, childController.getChild);
router.put('/:id', authMiddleware, childController.updateChild);
router.put('/:id/unhide', authMiddleware, childController.unhideChild);
router.delete('/:id', authMiddleware, childController.deleteChild);
router.get('/:id/registration-status', authMiddleware, childController.getRegistrationStatus);


// routes/childRoutes.js - إضافة المسارات الجديدة


// رفع مستند طبي
router.post(
  '/:id/upload-document',
  authMiddleware,
  (req, res, next) => {
    const upload = FileUploadService.upload.single('medical_document');
    
    upload(req, res, (err) => {
      if (err) {
        console.error('❌ Multer error:', err);
        
        // معالجة أخطاء Multer المختلفة
        if (err instanceof multer.MulterError) {
          if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({
              success: false,
              message: 'File too large. Maximum size is 10MB',
              error_code: 'FILE_TOO_LARGE'
            });
          } else if (err.code === 'LIMIT_FILE_COUNT') {
            return res.status(400).json({
              success: false,
              message: 'Too many files. Only one file allowed',
              error_code: 'TOO_MANY_FILES'
            });
          } else if (err.code === 'LIMIT_UNEXPECTED_FILE') {
            return res.status(400).json({
              success: false,
              message: 'Unexpected field name. Use "medical_document"',
              error_code: 'WRONG_FIELD_NAME'
            });
          }
        } else {
          // أخطاء مخصصة من fileFilter
          return res.status(400).json({
            success: false,
            message: err.message || 'File upload failed',
            error_code: 'INVALID_FILE_TYPE'
          });
        }
        
        return res.status(500).json({
          success: false,
          message: 'Upload failed',
          error: err.message
        });
      }
      
      // إذا كل شي تمام، كمل للـ controller
      next();
    });
  },
  childController.uploadMedicalDocument
);

router.post(
  '/:id/upload-photo',
  authMiddleware,
  (req, res, next) => {
    const upload = FileUploadService.upload.single('photo');

    upload(req, res, (err) => {
      if (err) {
        console.error('❌ Multer error:', err);

        if (err instanceof multer.MulterError) {
          if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({
              success: false,
              message: 'File too large. Maximum size is 10MB',
              error_code: 'FILE_TOO_LARGE'
            });
          } else if (err.code === 'LIMIT_FILE_COUNT') {
            return res.status(400).json({
              success: false,
              message: 'Too many files. Only one file allowed',
              error_code: 'TOO_MANY_FILES'
            });
          } else if (err.code === 'LIMIT_UNEXPECTED_FILE') {
            return res.status(400).json({
              success: false,
              message: 'Unexpected field name. Use "photo"',
              error_code: 'WRONG_FIELD_NAME'
            });
          }
        } else {
          return res.status(400).json({
            success: false,
            message: err.message || 'File upload failed',
            error_code: 'INVALID_FILE_TYPE'
          });
        }

        return res.status(500).json({
          success: false,
          message: 'Upload failed',
          error: err.message
        });
      }

      next();
    });
  },
  childController.uploadChildPhoto
);

// حذف مستند طبي
router.delete(
  '/:id/documents/:file_id',
  authMiddleware,
  childController.deleteMedicalDocument
);

// ================= ACTIVITY RECOMMENDATION ROUTES =================

// رفع مستند للأنشطة
router.post(
  '/:id/upload-activity-document',
  authMiddleware,
  (req, res, next) => {
    const upload = FileUploadService.upload.single('activity_document');
    
    upload(req, res, (err) => {
      if (err) {
        return res.status(400).json({
          success: false,
          message: err.message || 'File upload failed'
        });
      }
      next();
    });
  },
  childController.uploadActivityDocument
);

// تحليل وتوليد أنشطة
router.post(
  '/:id/analyze-for-activities',
  authMiddleware,
  childController.analyzeForActivities
);

// تحليل سريع (بدون مستند)
router.post(
  '/:id/quick-activity-analysis',
  authMiddleware,
  childController.quickActivityAnalysis
);

// جلب الأنشطة المقترحة
router.get(
  '/:id/activity-recommendations',
  authMiddleware,
  childController.getActivityRecommendations
);

// تحديث حالة النشاط
router.put(
  '/:id/activities/:activityId/status',
  authMiddleware,
  childController.updateActivityStatus
);

// جلب قائمة المستندات
// router.get(
//   '/:id/documents',
//   authMiddleware,
//   childController.getMedicalDocuments
// );
module.exports = router;