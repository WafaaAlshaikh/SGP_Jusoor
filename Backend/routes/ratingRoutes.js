// routes/ratingRoutes.js (نسخة محدثة مع middleware مخصص)
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const ratingMiddleware = require('../middleware/ratingMiddleware');

// Import Controllers
const sessionRatingController = require('../controllers/sessionRatingController');
const institutionReviewController = require('../controllers/institutionReviewController');
const specialistFeedbackController = require('../controllers/specialistFeedbackController');
const ratingStatsController = require('../controllers/ratingStatsController');

// ==================== Middleware للتحقق من الأدوار ====================
const parentOnly = (req, res, next) => {
  if (req.user.role !== 'Parent') {
    return res.status(403).json({ 
      success: false,
      message: 'Access denied. Parents only.' 
    });
  }
  next();
};

const managerOnly = (req, res, next) => {
  if (req.user.role !== 'Manager') {
    return res.status(403).json({ 
      success: false,
      message: 'Access denied. Managers only.' 
    });
  }
  next();
};

// ==================== تقييمات الجلسات ====================
router.post('/sessions/:sessionId/rate', 
  authMiddleware, 
  parentOnly,
  ratingMiddleware.canRateSession,
  sessionRatingController.rateSession
);

router.get('/sessions/:sessionId/ratings', 
  authMiddleware, 
  sessionRatingController.getSessionRatings
);

router.get('/specialists/:specialistId/ratings', 
  authMiddleware, 
  sessionRatingController.getSpecialistRatings
);

router.get('/my-ratings', 
  authMiddleware, 
  parentOnly, 
  sessionRatingController.getMyRatings
);

// ==================== مراجعات المؤسسة ====================
router.post('/institutions/:institutionId/reviews', 
  authMiddleware, 
  parentOnly,
  ratingMiddleware.hasVisitedInstitution,
  institutionReviewController.addInstitutionReview
);

router.get('/institutions/:institutionId/reviews', 
  authMiddleware, 
  institutionReviewController.getInstitutionReviews
);

router.get('/my-institution-reviews', 
  authMiddleware, 
  parentOnly, 
  institutionReviewController.getMyInstitutionReviews
);

// ==================== ملاحظات الأخصائيين ====================
router.post('/specialists/feedback', 
  authMiddleware, 
  parentOnly,
  ratingMiddleware.hasSessionsWithSpecialist,
  specialistFeedbackController.submitSpecialistFeedback
);

router.get('/manager/specialists-feedbacks', 
  authMiddleware, 
  managerOnly,
  specialistFeedbackController.getSpecialistFeedbacksForManager
);

router.get('/my-feedbacks', 
  authMiddleware, 
  parentOnly, 
  specialistFeedbackController.getMyFeedbacks
);

// ==================== إحصائيات وتقارير ====================
router.get('/manager/rating-dashboard', 
  authMiddleware, 
  managerOnly,
  ratingMiddleware.isManagerOfInstitution,
  ratingStatsController.getRatingDashboard
);

router.get('/manager/specialists/:specialistId/report', 
  authMiddleware, 
  managerOnly,
  ratingStatsController.getSpecialistDetailedReport
);

module.exports = router;