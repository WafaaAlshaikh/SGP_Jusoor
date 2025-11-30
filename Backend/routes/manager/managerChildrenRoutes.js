const express = require('express');
const router = express.Router();
const managerChildrenController = require('../../controllers/manager/managerChildrenController');
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

// الأطفال والإحصائيات
router.get('/children', managerChildrenController.getInstitutionChildren);
router.get('/children/statistics', managerChildrenController.getChildrenStatistics);
router.get('/children/:child_id', managerChildrenController.getChildDetails);

// الإحصائيات المتقدمة للأطفال
router.get('/children/:child_id/advanced-statistics', managerChildrenController.getAdvancedChildStatistics);
router.get('/children/:child_id/multidisciplinary-insights', managerChildrenController.getChildMultidisciplinaryInsights);

// طلبات التسجيل
router.get('/registration-requests/pending', managerChildrenController.getPendingRegistrationRequests);
router.put('/registration-requests/:request_id/approve', managerChildrenController.approveRegistrationRequest);
router.put('/registration-requests/:request_id/reject', managerChildrenController.rejectRegistrationRequest);

module.exports = router;