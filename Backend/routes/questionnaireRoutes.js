const express = require('express');
const router = express.Router();
const questionnaireController = require('../controllers/questionnaireController');

const authMiddleware = require('../middleware/authMiddleware');

// Start new questionnaire
router.post('/start', authMiddleware, questionnaireController.startQuestionnaire);

// Save answer (single question)
router.post('/answer', authMiddleware, questionnaireController.saveAnswer);

// Save multiple answers (batch)
router.post('/answers/batch', authMiddleware, questionnaireController.saveAnswersBatch);

// Get current questionnaire status
router.get('/current', authMiddleware, questionnaireController.getCurrentQuestionnaire);

// Questionnaire questions/schema/responses (used by app)
router.get('/questions', authMiddleware, questionnaireController.getQuestionnaireQuestions);
router.get('/schema', authMiddleware, questionnaireController.getQuestionnaireSchema);
router.post('/responses', authMiddleware, questionnaireController.submitQuestionnaireResponses);

// Get all questionnaires for current user
router.get('/', authMiddleware, questionnaireController.getAllQuestionnaires);

// Get questionnaire by ID
router.get('/:id', authMiddleware, questionnaireController.getQuestionnaireById);

// Calculate scores and generate results
router.post('/:id/calculate', authMiddleware, questionnaireController.calculateScores);

// Complete questionnaire
router.post('/:id/complete', authMiddleware, questionnaireController.completeQuestionnaire);

// Get results for a questionnaire
router.get('/:id/results', authMiddleware, questionnaireController.getResults);

// Delete questionnaire (soft delete)
router.delete('/:id', authMiddleware, questionnaireController.deleteQuestionnaire);

// Share with specialist
//router.post('/:id/share', authMiddleware, questionnaireController.shareWithSpecialist);

module.exports = router;
