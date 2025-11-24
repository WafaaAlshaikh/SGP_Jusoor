// routes/diagnosisRoutes.js
const express = require('express');
const router = express.Router();
const diagnosisController = require('../controllers/diagnosisController'); // تأكد من المسار
const authMiddleware = require('../middleware/authMiddleware');

// استخدم الـ controller بدلاً من كتابة المنطق مباشرة في الـ route
router.get('/', authMiddleware, diagnosisController.getDiagnoses);

module.exports = router;