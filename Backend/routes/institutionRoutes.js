// routes/institutionRoutes.js
const express = require('express');
const router = express.Router();
const institutionController = require('../controllers/institutionController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/institutions', authMiddleware, institutionController.getInstitutions);

module.exports = router;
