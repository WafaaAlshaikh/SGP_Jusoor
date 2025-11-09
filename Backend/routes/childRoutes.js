// routes/childRoutes.js - النسخة المحدثة
const express = require('express');
const router = express.Router();
const childController = require('../controllers/childController');
const authMiddleware = require('../middleware/authMiddleware');

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
router.delete('/:id', authMiddleware, childController.deleteChild);
router.get('/:id/registration-status', authMiddleware, childController.getRegistrationStatus);

module.exports = router;