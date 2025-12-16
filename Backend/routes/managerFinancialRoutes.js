// routes/managerFinancialRoutes.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const managerController = require('../controllers/manager/managerController');

// Manager Financial Routes
router.get('/financial-requests', authMiddleware, managerController.getFinancialAssistanceRequests);
router.post('/financial-requests/:request_id/review', authMiddleware, managerController.reviewFinancialAssistanceRequest);

// Session-level financial aid requests
router.get('/session-aid-requests', authMiddleware, managerController.getSessionFinancialAidRequests);
router.post('/session-aid-requests/:request_id/review', authMiddleware, managerController.reviewSessionFinancialAidRequest);

module.exports = router;