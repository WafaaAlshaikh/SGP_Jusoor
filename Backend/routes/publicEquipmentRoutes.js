const express = require('express');
const router = express.Router();
const equipmentDonationApi = require('../controllers/api/equipmentDonationApi');

// Routes عامة لا تحتاج مصادقة
router.get('/institutions', equipmentDonationApi.getInstitutionsForEquipmentDonation);
router.get('/campaigns', equipmentDonationApi.getOpenEquipmentCampaigns);
router.get('/institutions/:institutionId/campaigns', equipmentDonationApi.getInstitutionEquipmentCampaigns);
router.get('/campaigns/:campaignId', equipmentDonationApi.getEquipmentCampaignDetails);
router.post('/donate/anonymous', equipmentDonationApi.createAnonymousEquipmentDonation);
router.get('/status', equipmentDonationApi.checkEquipmentDonationStatus);

module.exports = router;