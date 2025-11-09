const express = require('express');
const router = express.Router();
const resourceController = require('../controllers/ResourceController');
const authenticate = require('../middleware/authMiddleware'); // middleware التحقق من الوالد

router.get('/parent/resources', authenticate, resourceController.getParentResources);

module.exports = router;
