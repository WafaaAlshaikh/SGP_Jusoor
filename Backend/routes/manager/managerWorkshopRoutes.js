const express = require('express');
const router = express.Router();
const authMiddleware = require('../../middleware/authMiddleware');
const workshopController = require('../../controllers/workshopController');

// Manager workshops
router.get('/workshops', authMiddleware, workshopController.getManagerWorkshops);
router.post('/workshops', authMiddleware, workshopController.createWorkshop);

module.exports = router;
