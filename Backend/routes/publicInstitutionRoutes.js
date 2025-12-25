const express = require('express');
const router = express.Router();

const publicInstitutionController = require('../controllers/publicInstitutionController');
const publicInstitutionContentController = require('../controllers/publicInstitutionContentController');
const institutionReviewController = require('../controllers/institutionReviewController');
const publicInstitutionAIController = require('../controllers/publicInstitutionAIController');
const publicInstitutionContactController = require('../controllers/publicInstitutionContactController');
const institutionFollowController = require('../controllers/institutionFollowController');
const authMiddleware = require('../middleware/authMiddleware');
const optionalAuth = require('../middleware/optionalAuth');

// Public institutions list
router.get('/institutions', publicInstitutionController.getPublicInstitutions);

// Public institution details
router.get('/institutions/:institutionId', publicInstitutionController.getPublicInstitutionDetails);

// Public institution highlights (curated quick overview)
router.get('/institutions/:institutionId/highlights', publicInstitutionController.getPublicInstitutionHighlights);

// Public institution profile (aggregated)
router.get('/institutions/:institutionId/profile', publicInstitutionController.getPublicInstitutionProfile);

// Public institution team (specialists)
router.get('/institutions/:institutionId/team', publicInstitutionController.getPublicInstitutionTeam);

// Public institution home (CMS + media)
router.get('/institutions/:institutionId/home', publicInstitutionContentController.getInstitutionHome);

// Public CMS endpoints
router.get('/institutions/:institutionId/content', publicInstitutionContentController.getInstitutionContent);
router.get('/institutions/:institutionId/news', publicInstitutionContentController.getInstitutionNews);
router.get('/institutions/:institutionId/programs', publicInstitutionContentController.getInstitutionPrograms);
router.get('/institutions/:institutionId/projects', publicInstitutionContentController.getInstitutionProjects);
router.get('/institutions/:institutionId/faq', publicInstitutionContentController.getInstitutionFAQ);

// Public institution reviews (uses InstitutionReviewController)
router.get('/institutions/:institutionId/reviews', institutionReviewController.getInstitutionReviews);

router.post('/institutions/:institutionId/ai/ask', optionalAuth, publicInstitutionAIController.askInstitutionAI);

router.post('/institutions/:institutionId/contact', authMiddleware, publicInstitutionContactController.createInstitutionContact);

router.post('/institutions/:institutionId/follow', authMiddleware, institutionFollowController.followInstitution);
router.post('/institutions/:institutionId/unfollow', authMiddleware, institutionFollowController.unfollowInstitution);
router.get('/institutions/:institutionId/follow-status', authMiddleware, institutionFollowController.getFollowStatus);

// أضف هاتين المسارتين بعد المسارات الحالية

// أنواع جلسات المؤسسة
router.get('/institutions/:institutionId/session-types', publicInstitutionController.getInstitutionSessionTypes);

// تفاصيل نوع جلسة محدد
router.get('/institutions/:institutionId/session-types/:sessionTypeId', publicInstitutionController.getSessionTypeDetails);
module.exports = router;
