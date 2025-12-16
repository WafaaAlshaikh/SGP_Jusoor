const express = require('express');
const router = express.Router();
const authMiddleware = require('../../middleware/authMiddleware');
const donationCampaignController = require('../../controllers/manager/donationCampaignController');
const donationController = require('../../controllers/donationController');

// All routes require authentication (manager)
router.use(authMiddleware);
router.get('/statistics', donationController.getDonationStatistics);
router.get('/statistics/filtered', donationController.getFilteredDonationStatistics);

router.get('/campaigns', donationCampaignController.getCampaigns);
router.post('/campaigns', donationCampaignController.createCampaign);
router.put('/campaigns/:id', donationCampaignController.updateCampaign);
router.get('/campaigns/:id/impact', donationCampaignController.getCampaignImpact);

module.exports = router;
