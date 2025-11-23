// routes/progressAnalysisRoutes.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { 
  analyzeChildProgress, 
  getQuickStatistics ,
  compareDateRangeProgress,
  analyzePeriodProgress
} = require('../controllers/progressAnalysisController');

// جميع المسارات تتطلب مصادقة
router.use(authMiddleware);

/**
 * @route   GET /api/specialist/children/:childId/progress-analysis
 * @desc    تحليل شامل لتقدم الطفل مع AI
 * @access  Private (Specialist only)
 */
router.get('/children/:childId/progress-analysis', analyzeChildProgress);

/**
 * @route   GET /api/specialist/children/:childId/quick-stats
 * @desc    إحصائيات سريعة بدون AI
 * @access  Private (Specialist only)
 */
router.get('/children/:childId/quick-stats', getQuickStatistics);

/**
 * @route   GET /api/specialist/children/:childId/compare-dates
 * @desc    Compare progress between two specific dates
 * @access  Private (Specialist only)
 * @query   {String} startDate - Start date (YYYY-MM-DD)
 * @query   {String} endDate - End date (YYYY-MM-DD)
 */
router.get('/children/:childId/compare-dates',compareDateRangeProgress);

/**
 * @route   GET /api/specialist/children/:childId/period-analysis
 * @desc    Analyze progress for specific periods (last_week, last_month, last_3_months, last_6_months)
 * @access  Private (Specialist only)
 * @query   {String} period - Time period to analyze
 */
router.get('/children/:childId/period-analysis',analyzePeriodProgress);


module.exports = router;