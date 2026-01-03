const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const aiRecommendationsController = require('../controllers/aiRecommendationsController');

// Get AI-powered recommendations for institutions
router.get('/recommendations', authMiddleware, aiRecommendationsController.getRecommendations);

// Get AI-powered recommendations for donors (money + equipment)
router.get('/donor/recommendations', authMiddleware, aiRecommendationsController.getDonorRecommendations);

module.exports = router;
