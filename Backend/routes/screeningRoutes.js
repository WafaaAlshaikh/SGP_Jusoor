// routes/screeningRoutes.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const {
  startScreening,
  processGateway,
  saveResults,
  getMyScreenings
} = require('../controllers/screeningController');

// 🎯 Apply auth middleware to all screening routes
router.use(authMiddleware);

// 🎯 بداية الاستبيان
router.post('/start-screening', startScreening);

// 🎯 معالجة إجابات البوابة
router.post('/process-gateway', processGateway);

// 🎯 حفظ النتائج النهائية
router.post('/save-results', saveResults);

// 🎯 جلب تاريخ الفحوصات السابقة
router.get('/my-screenings', getMyScreenings);

module.exports = router;