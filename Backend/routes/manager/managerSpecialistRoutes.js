const express = require('express');
const router = express.Router();
const managerSpecialistController = require('../../controllers/manager/managerSpecialistController');
const jwt = require('jsonwebtoken');

// Middleware للمصادقة
const authenticate = (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ 
        success: false,
        message: 'No token provided' 
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; 
    next();
  } catch (err) {
    return res.status(401).json({ 
      success: false,
      message: 'Invalid token' 
    });
  }
};

// Middleware للتفويض - المدير فقط
const authorizeManager = (req, res, next) => {
  if (!req.user || req.user.role !== 'Manager') {
    return res.status(403).json({
      success: false,
      message: 'Access denied - manager role required'
    });
  }
  next();
};

// استخدام الـ middleware
router.use(authenticate);
router.use(authorizeManager);

// ==================== ROUTES ====================

// 🔹 جلب جميع الأخصائيين في المؤسسة
router.get('/specialists', managerSpecialistController.getInstitutionSpecialists);

// 🔹 جلب تفاصيل أخصائي محدد
router.get('/specialists/:specialist_id', managerSpecialistController.getSpecialistDetails);

// 🔹 تحديث حالة الأخصائي (موافقة، رفض، تفعيل، إيقاف)
router.put('/specialists/:specialist_id/status', managerSpecialistController.updateSpecialistStatus);

// 🔹 إحصائيات الأخصائيين الشاملة
router.get('/specialists-statistics', managerSpecialistController.getSpecialistsStatistics);

// 🔹 تقرير أداء مفصل لأخصائي معين
router.get('/specialists/:specialist_id/performance-report', managerSpecialistController.getSpecialistPerformanceReport);

module.exports = router;