const express = require('express');
const router = express.Router();
const authMiddleware = require('../../middleware/authMiddleware');
const { 
  getChildrenManagementData, 
  getDetailedStatistics,
  debugChildrenData,
  getChildDetailedInfo
} = require('../../controllers/manager/childrenManagementController');

// جميع المسارات تتطلب مصادقة المدير
router.use(authMiddleware);

// التحقق من أن المستخدم هو مدير
const checkManagerRole = (req, res, next) => {
  if (req.user.role !== 'Manager') {
    return res.status(403).json({
      success: false,
      message: 'Access denied. Managers only.'
    });
  }
  next();
};

router.use(checkManagerRole);

// المسار الرئيسي للحصول على جميع بيانات إدارة الأطفال
router.get('/children-management', getChildrenManagementData);

// مسار إضافي للإحصائيات التفصيلية
router.get('/children-management/statistics', getDetailedStatistics);

// مسار جديد لفحص البيانات بالتفصيل
router.get('/children-management/debug', debugChildrenData);

// مسار للحصول على معلومات مفصلة عن طفل معين
router.get('/child/:childId/detailed-info', getChildDetailedInfo);
module.exports = router;