const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const {
  getUpcomingSessions,
  getCompletedSessions,
  getPendingSessions,
  getCancelledSessions,
  confirmSession,
  getChildSessions,
  cancelSession,
  rateSession,
  getAllSessions,
  processPayment, // تأكد من استيرادها
  parentConfirmAutoSession,
  parentSessionDecision,
  checkAutoFinancialAssistance,
  applyAutoDiscount,
  createSessionWithAutoFinancialAid,
  checkSessionFinancialAid
} = require('../controllers/sessionController');

console.log({
  checkAutoFinancialAssistance,
  applyAutoDiscount
});


// routes/sessionRoutes.js (أضف هذه المسارات)

// المسار للتحقق التلقائي من المساعدة المالية
router.get('/:session_id/check-auto-assistance', 
  authMiddleware, 
  checkAutoFinancialAssistance
);

// المسار لتطبيق الخصم التلقائي
router.post('/:session_id/apply-auto-discount', 
  authMiddleware, 
  applyAutoDiscount
);
// إزالة processPayment من هنا لأنه غير موجود في sessionController
// router.post('/:id/process-payment', processPayment); // ❌ إزالة هذا السطر

router.get('/sessions', authMiddleware, getAllSessions);
router.get('/upcoming', getUpcomingSessions);
router.patch('/:id/cancel', cancelSession);
// الطرق الحالية
router.get('/upcoming-sessions', authMiddleware, getUpcomingSessions);
router.get('/completed-sessions', authMiddleware, getCompletedSessions);
router.get('/pending-sessions', authMiddleware, getPendingSessions);
router.get('/cancelled-sessions', authMiddleware, getCancelledSessions);
router.patch('/sessions/:id/confirm', authMiddleware, confirmSession);
router.patch('/sessions/:id/cancel', authMiddleware, cancelSession);
router.post('/sessions/:id/rate', authMiddleware, rateSession);
router.get('/child-sessions/:childId', authMiddleware, getChildSessions);
router.post('/sessions/:id/confirm-auto', authMiddleware, parentConfirmAutoSession);
router.post('/sessions/:id/decision', authMiddleware, parentSessionDecision);

// routes/sessionRoutes.js (إضافة هذه المسارات)


// 🔧 مسار إنشاء جلسة مع المساعدة المالية التلقائية
router.post('/create-with-aid', authMiddleware, createSessionWithAutoFinancialAid);

// 🔧 مسار التحقق من المساعدة المالية لجلسة محددة
router.get('/:session_id/check-aid', authMiddleware, checkSessionFinancialAid);

// 🔧 مسار لتطبيق المساعدة المالية التلقائية على جلسة موجودة
router.post('/:session_id/apply-auto-aid', authMiddleware, async (req, res) => {
  try {
    const result = await AutoFinancialAidService.autoApplyFinancialAid(req.params.session_id);
    res.json(result);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});
module.exports = router;