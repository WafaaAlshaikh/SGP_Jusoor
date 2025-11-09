const express = require('express');
const router = express.Router();
const specialistSessionController = require('../controllers/specialistSessionController');
const authMiddleware = require('../middleware/authMiddleware');

// 🔒 السماح فقط للأخصائيين
const specialistOnly = (req, res, next) => {
  if (req.user.role !== 'Specialist') {
    return res.status(403).json({ message: 'Access denied' });
  }
  next();
};

// ✅ 1. جلب كل الجلسات للأخصائي
router.get(
  '/sessions',
  authMiddleware,
  specialistOnly,
  specialistSessionController.getAllSessionsForSpecialist
);

// ✅ 2. طلب حذف الجلسة
router.post(
  '/sessions/:id/delete-request',
  authMiddleware,
  specialistOnly,
  specialistSessionController.requestDeleteSession
);

// ✅ 3. طلب تعديل الجلسة (Pending Update)
router.post(
  '/sessions/:id/request-update',
  authMiddleware,
  specialistOnly,
  specialistSessionController.requestSessionUpdate
);


// ✅ 4. إكمال جلسات اليوم
router.post(
  '/sessions/complete-today',
  authMiddleware,
  specialistOnly,
  specialistSessionController.completeTodaySessions
);

// ✅ 5. جلب الجلسات القادمة (7 أيام)
router.get(
  '/sessions/upcoming',
  authMiddleware,
  specialistOnly,
  specialistSessionController.getUpcomingSessions
);

// ✅ 6. التقرير الشهري
router.get(
  '/sessions/monthly-report',
  authMiddleware,
  specialistOnly,
  specialistSessionController.getMonthlyReport
);

// ✅ 7. ضبط التذكيرات
router.post(
  '/sessions/reminders',
  authMiddleware,
  specialistOnly,
  specialistSessionController.setSessionReminders
);

// ✅ 8. الانضمام إلى جلسة زوم
router.get(
  '/sessions/:id/join-zoom',
  authMiddleware,
  specialistOnly,
  specialistSessionController.joinZoomSession
);

// ✅ 9. جلب الإحصائيات السريعة
router.get(
  '/sessions/quick-stats',
  authMiddleware,
  specialistOnly,
  specialistSessionController.getQuickStats
);

// ✅ 10. الموافقة أو الرفض على التعديل المؤقت (Parent)
router.post(
  '/sessions/pending/:id/approve',
  authMiddleware,
  async (req, res, next) => {
    if (req.user.role !== 'Parent') {
      return res.status(403).json({ message: 'Access denied' });
    }
    next();
  },
  specialistSessionController.approvePendingSession
);

// ✅ 11. جلب التعديلات المعلقة للأهل
router.get(
  '/sessions/pending',
  authMiddleware,
  async (req, res, next) => {
    if (req.user.role !== 'Parent') {
      return res.status(403).json({ message: 'Access denied' });
    }
    next();
  },
  specialistSessionController.getPendingSessionsForParent
);
router.get(
  '/pending-updates', 
  authMiddleware, 
  specialistSessionController.getPendingUpdateRequests
);

// ⭐ روت جديد لجلب الجلسات المطلوب حذفها
router.get('/delete-requests', authMiddleware,  specialistSessionController.getDeleteRequestedSessions);
module.exports = router;