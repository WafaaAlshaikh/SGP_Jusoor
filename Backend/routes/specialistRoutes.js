const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { 
  getUpcomingSessionsCount, 
  getChildrenCount, 
  addSession,
  getChildrenInInstitution,
  getImminentSessions,
  getEligibleChildren,
  getAvailableSessionTypes,
  addSessionsForChildren,
  addSessionType,
  getAvailableSlots
} = require('../controllers/specialistController');


// 🔒 كل الرُتب بس للأخصائيين (تحقق من الـ role)
const specialistOnly = (req, res, next) => {
  if (req.user.role !== 'Specialist') {
    return res.status(403).json({ message: 'Access denied' });
  }
  next();
};
const { getProfileInfo } = require('../controllers/specialistController');
// 🔹 احصائيات
router.get('/upcoming-sessions', authMiddleware, specialistOnly, getUpcomingSessionsCount);
router.get('/children-count', authMiddleware, specialistOnly, getChildrenCount);
router.get('/available-slots', authMiddleware, getAvailableSlots);


// endpoint لجلب بيانات الملف الشخصي
router.get('/me', authMiddleware, (req, res) => {
  // إذا بدك تقتصر على الأخصائيين:
  if (req.user.role !== 'Specialist') {
    return res.status(403).json({ message: 'Access denied' });
  }
  getProfileInfo(req, res);
});


router.get('/imminent-sessions', authMiddleware, specialistOnly, getImminentSessions);

// // 🔹 إضافة جلسة
// router.post('/add-session', authMiddleware, specialistOnly, addSession);
// router.get(
//   '/institution-children',
//   authMiddleware,
//   specialistOnly,
//   getChildrenInInstitution
// );

// ✅ جلب الأطفال المؤهلين (نفس المؤسسة + نفس الحالة)
router.get(
  '/eligible-children',
  authMiddleware,
  specialistOnly,
  getEligibleChildren
);

// ✅ جلب أنواع الجلسات المتاحة حسب الحالة
router.get(
  '/available-session-types',
  authMiddleware,
  specialistOnly,
  getAvailableSessionTypes
);

// ✅ إضافة جلسات لعدة أطفال (مع طلب موافقة الأهل)
router.post(
  '/add-sessions',
  authMiddleware,
  specialistOnly,
  addSessionsForChildren
);

// ✅ إضافة نوع جلسة جديد (بحاجة لموافقة المدير)
router.post(
  '/add-session-type',
  authMiddleware,
  specialistOnly,
  addSessionType
);

module.exports = router;