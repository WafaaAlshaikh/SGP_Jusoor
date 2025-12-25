const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');
const deviceTokenController = require('../controllers/deviceTokenController');

router.use(authMiddleware);

router.post('/register', deviceTokenController.registerDeviceToken);
router.post('/unregister', deviceTokenController.unregisterDeviceToken);

module.exports = router;
