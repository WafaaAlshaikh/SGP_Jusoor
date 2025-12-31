const express = require('express');
const router = express.Router();
const equipmentDonationController = require('../controllers/equipmentDonationController');
const authMiddleware = require('../middleware/authMiddleware');
const managerAuthMiddleware = require('../middleware/managerAuth');
const upload = require('../middleware/uploadMiddleware');

// Routes العامة (لا تحتاج مصادقة)
router.get('/categories', equipmentDonationController.getEquipmentCategories);

// Routes تحتاج مصادقة
router.post('/donate', 
  authMiddleware, 
  upload.array('images', 5), // السماح بحد أقصى 5 صور
  equipmentDonationController.createEquipmentDonation
);

// للمستخدم العادي
router.get('/my-donations', 
  authMiddleware, 
  equipmentDonationController.getUserEquipmentDonations
);

router.get('/:id', 
  authMiddleware, 
  equipmentDonationController.getEquipmentDonationDetails
);

// Routes للمدير
router.get('/manager/list', 
  authMiddleware, 
  equipmentDonationController.getManagerEquipmentDonations
);

router.put('/manager/:id/status', 
  authMiddleware, 
  equipmentDonationController.updateEquipmentDonationStatus
);

router.get('/manager/stats', 
  authMiddleware, 
  equipmentDonationController.getEquipmentDonationStats
);

module.exports = router;