const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const {
  getUpcomingSessions,
  getCompletedSessions,
  confirmSession,
  getChildSessions,
  cancelSession,
  getAllSessions 
} = require('../controllers/sessionController');


router.get('/sessions', authMiddleware, getAllSessions);
router.get('/upcoming-sessions', authMiddleware, getUpcomingSessions);
router.get('/completed-sessions', authMiddleware, getCompletedSessions);
router.patch('/sessions/:id/confirm', authMiddleware, confirmSession);
router.patch('/sessions/:id/cancel', authMiddleware, cancelSession);
router.get('/child-sessions/:childId', authMiddleware, getChildSessions);



module.exports = router;
