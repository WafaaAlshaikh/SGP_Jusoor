const express = require('express');
const router = express.Router();
const questionnaireController = require('../controllers/questionnaireController');
const authMiddleware = require('../middleware/authMiddleware');

// جميع الروتس تحتاج مصادقة
router.get('/questions', authMiddleware, questionnaireController.getQuestions);
router.post('/responses', authMiddleware, questionnaireController.saveQuestionnaireResponse);
router.get('/history', authMiddleware, questionnaireController.getQuestionnaireHistory);

module.exports = router;