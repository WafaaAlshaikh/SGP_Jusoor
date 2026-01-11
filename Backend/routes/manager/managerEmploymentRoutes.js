const express = require('express');
const router = express.Router();
const managerEmploymentController = require('../../controllers/manager/managerEmploymentController');
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

// ==================== مسارات طلبات التوظيف ====================

// 🔹 جلب جميع طلبات التوظيف للمؤسسة
router.get('/employment-requests', managerEmploymentController.getEmploymentRequests);

// 🔹 جلب تفاصيل طلب توظيف محدد
router.get('/employment-requests/:request_id', managerEmploymentController.getEmploymentRequestDetails);

// 🔹 جدولة مقابلة للأخصائي
router.post('/employment-requests/:request_id/schedule-interview', managerEmploymentController.scheduleInterview);

// 🔹 الموافقة على طلب التوظيف
router.put('/employment-requests/:request_id/approve', managerEmploymentController.approveEmploymentRequest);

// 🔹 رفض طلب التوظيف
router.put('/employment-requests/:request_id/reject', managerEmploymentController.rejectEmploymentRequest);

// 🔹 جلب جميع المقابلات المجدولة
router.get('/interviews', managerEmploymentController.getAllInterviews);

// 🔹 تحديث حالة المقابلة
router.put('/interviews/:interview_id/status', managerEmploymentController.updateInterviewStatus);

// 🔹 حذف مقابلة
router.delete('/interviews/:interview_id', managerEmploymentController.deleteInterview);

module.exports = router;