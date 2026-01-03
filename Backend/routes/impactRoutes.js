const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');
const impactController = require('../controllers/impactController');

// Donor feed (requires auth)
router.get('/feed', authMiddleware, impactController.getDonorImpactFeed);

module.exports = router;
