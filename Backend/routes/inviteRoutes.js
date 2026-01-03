const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');
const inviteController = require('../controllers/inviteController');

// Create invite for a donation campaign/institution
router.post('/donations', authMiddleware, inviteController.createDonationInvite);

// My invite stats (network impact)
router.get('/donations/my/stats', authMiddleware, inviteController.getMyDonationInviteStats);

// Resolve invite by code (logs click)
// NOTE: optional auth; if logged in we store referred_user_id
router.get('/donations/:code', inviteController.resolveDonationInvite);

module.exports = router;
