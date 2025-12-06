const express = require('express');
const router = express.Router();
const authMiddleware = require('../../middleware/authMiddleware');
const { 
  getParentsList,        // جلب قائمة الآباء الموجودين
  addNewChild,           // إضافة طفل جديد
  getAvailableSpecialists, // جلب الأخصائيين المتاحين
  bookGeneralSession     // حجز جلسة General
} = require('../../controllers/manager/addChildController');

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

// جلب قائمة الآباء في المؤسسة
router.get('/parents', getParentsList);

// إضافة طفل جديد (مع أو بدون أب جديد)
router.post('/add-child', addNewChild);

// جلب الأخصائيين المتاحين لجلسة General
router.get('/available-specialists', getAvailableSpecialists);

// حجز جلسة General للطفل
router.post('/book-general-session', bookGeneralSession);

module.exports = router;