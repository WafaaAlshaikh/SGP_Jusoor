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

// ==================== Routes العامة (للتبرع) ====================
router.get('/institutions', donationController.getDonationInstitutions);
router.get('/institutions/:institutionId/campaigns', donationController.getInstitutionCampaignsForDonations);

// ==================== Routes للمتبرعين (تحتاج مصادقة) ====================
router.post('/checkout', authMiddleware, donationController.createDonationCheckout);

// ✅ تحديث: دالة التحقق من حالة التبرع
// router.get('/status', authMiddleware, donationController.checkDonationStatus);

// ✅ جديد: تأكيد التبرع بعد العودة من Stripe
router.post('/confirm', authMiddleware, donationController.confirmDonation);

router.get('/history', authMiddleware, donationController.getDonationHistory);
router.get('/impact', authMiddleware, donationController.getDonationImpact);
// router.post('/:donation_id/cancel', authMiddleware, donationController.cancelDonation);

// ==================== Routes للمدراء ====================
// router.get('/manager/stats', managerAuthMiddleware, donationController.getManagerDonationStats);

module.exports = router;