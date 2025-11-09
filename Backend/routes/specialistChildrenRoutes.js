const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { getSpecialistChildren, getChildDetails } = require('../controllers/specialistChildrenController');

// جميع المسارات تتطلب مصادقة
router.use(authMiddleware);

// جلب جميع الأطفال للاخصائي
router.get('/children', getSpecialistChildren);

// جلب تفاصيل طفل محدد
router.get('/children/:childId', getChildDetails);

module.exports = router;