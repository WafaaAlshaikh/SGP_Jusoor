const express = require('express');
const router = express.Router();
const authMiddleware = require('../../middleware/authMiddleware');
const managerController = require('../../controllers/manager/managerController');

// Generate free session offers for eligible children
router.post('/free-sessions/generate', authMiddleware, managerController.generateFreeSessionOffers);

module.exports = router;
