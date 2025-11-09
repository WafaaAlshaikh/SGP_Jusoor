// routes/sessionBookingRoutes.js
const express = require('express');
const router = express.Router();
const sessionBookingController = require('../controllers/sessionBookingController');
const authMiddleware = require('../middleware/authMiddleware');

// ============= PARENT ROUTES =============
router.get('/available-slots', authMiddleware, sessionBookingController.getAvailableSlots);
router.post('/book-session', authMiddleware, sessionBookingController.bookSession);
router.post('/confirm-payment/:session_id', authMiddleware, sessionBookingController.confirmPayment);
router.get('/institution-session-types/:institution_id', authMiddleware, sessionBookingController.getInstitutionSessionTypes);
router.get('/child/:child_id/suitable-session-types', authMiddleware, sessionBookingController.getSuitableSessionTypes);
router.get('/session-details/:session_id', authMiddleware, sessionBookingController.getSessionDetails);

// ============= MANAGER ROUTES =============
router.get('/manager/pending-sessions', authMiddleware, sessionBookingController.getPendingSessions);
router.put('/manager/approve-session/:session_id', authMiddleware, sessionBookingController.managerApproveSession);
router.put('/manager/reject-session/:session_id', authMiddleware, sessionBookingController.managerRejectSession);

module.exports = router;