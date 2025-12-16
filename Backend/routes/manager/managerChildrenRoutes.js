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

// ==================== ROUTES الجديدة للنظام التلقائي ====================

/**
 * @route   GET /api/manager/auto-approval/status
 * @desc    الحصول على حالة وإحصائيات النظام التلقائي
 * @access  Private (Manager only)
 */
router.get('/auto-approval/status', managerChildrenController.getAutoApprovalStatus);

/**
 * @route   POST /api/manager/auto-approval/process
 * @desc    تشغيل المعالجة التلقائية يدوياً
 * @access  Private (Manager only)
 */
router.post('/auto-approval/process', managerChildrenController.triggerAutoApprovalProcess);

/**
 * @route   PUT /api/manager/auto-approval/config
 * @desc    تحديث إعدادات النظام التلقائي
 * @access  Private (Manager only)
 */
router.put('/auto-approval/config', managerChildrenController.updateAutoApprovalConfig);

/**
 * @route   GET /api/manager/auto-approval/pending-review
 * @desc    الحصول على الطلبات التي تحتاج مراجعة يدوية
 * @access  Private (Manager only)
 */
router.get('/auto-approval/pending-review', managerChildrenController.getPendingManualReviewRequests);

/**
 * @route   POST /api/manager/auto-approval/bulk-action
 * @desc    تنفيذ إجراءات جماعية على الطلبات
 * @access  Private (Manager only)
 */
router.post('/auto-approval/bulk-action', managerChildrenController.processBulkActions);

module.exports = router;