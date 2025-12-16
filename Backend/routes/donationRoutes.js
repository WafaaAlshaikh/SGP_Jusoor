const express = require('express');
const router = express.Router();
const donationController = require('../controllers/donationController');
const authMiddleware = require('../middleware/authMiddleware');

// Public or lightly protected: list institutions available for donation
router.get('/donations/institutions', donationController.getDonationInstitutions);

// Public: list active/upcoming campaigns for a specific institution (for donors)
router.get(
  '/donations/institutions/:institutionId/campaigns',
  donationController.getInstitutionCampaignsForDonations
);

// Protected: create a new donation (direct DB, without Stripe)
router.post('/donations', authMiddleware, donationController.createDonation);

// Protected: start Stripe Checkout for a donation (one-time or monthly)
router.post(
  '/donations/checkout',
  authMiddleware,
  donationController.createDonationCheckout
);

// Protected: confirm a donation after Stripe Checkout using session_id
router.post(
  '/donations/confirm',
  authMiddleware,
  donationController.confirmDonationFromStripe
);

// Protected: get donation history for current donor
router.get(
  '/donations/history',
  authMiddleware,
  donationController.getDonationHistory
);

// Protected: get aggregated donation impact for current donor
router.get(
  '/donations/impact',
  authMiddleware,
  donationController.getDonationImpact
);

module.exports = router;
