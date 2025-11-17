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
  processPayment // ⬅️ تأكد من استيرادها
} = require('../controllers/sessionController');

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

module.exports = router;