// routes/donationRoutes.js
const express = require('express');
const router = express.Router();
const donationController = require('../controllers/donationController');
const webhookController = require('../controllers/webhookController');
const authMiddleware = require('../middleware/authMiddleware');
const managerAuthMiddleware = require('../middleware/managerAuth');

// ==================== ⚠️ CRITICAL: Webhook MUST be BEFORE express.json() ====================
// ✅ هذا المسار يجب أن يكون قبل أي middleware يعالج JSON
router.post('/webhook', 
  express.raw({ type: 'application/json' }), 
  webhookController.handleStripeWebhook
);

// ==================== Routes العامة (لا تحتاج مصادقة) ====================
router.get('/institutions', donationController.getDonationInstitutions);
router.get('/institutions/:institutionId/campaigns', donationController.getInstitutionCampaignsForDonations);
router.get('/status', donationController.checkDonationBySession);
router.get('/debug', donationController.debugDonations);

// ==================== Routes للمتبرعين المجهولين ====================
router.post('/anonymous/checkout', donationController.createAnonymousDonation);
router.post('/anonymous/confirm', donationController.confirmDonation);

// ==================== Routes للمتبرعين المسجلين (تحتاج مصادقة) ====================
router.post('/checkout', authMiddleware, donationController.createDonationCheckout);
router.post('/confirm', authMiddleware, donationController.confirmDonation);
router.get('/history', authMiddleware, donationController.getDonationHistory);
router.get('/impact', authMiddleware, donationController.getDonationImpact);
router.get('/impact/v2', authMiddleware, donationController.getDonationImpactV2);
router.get('/donor/profile', authMiddleware, donationController.getDonorProfile);

// ==================== Route للتبرع المرن (مع أو بدون مصادقة) ====================
router.post('/flexible/checkout', donationController.createDonationCheckout);

// ==================== Routes للمدراء ====================
// router.get('/manager/stats', managerAuthMiddleware, donationController.getManagerDonationStats);
// أضف هذا المسار
router.post('/confirm-payment', donationController.confirmDonationPayment);
module.exports = router;