const express = require('express');
const router = express.Router();
const ScreeningController = require('../controllers/screeningController');

// Create controller instance
const screeningController = new ScreeningController();

// ========== MAIN ROUTES ==========

// Start new screening
router.post('/start', screeningController.startScreening.bind(screeningController));

// Submit answer to question
router.post('/answer', screeningController.submitAnswer.bind(screeningController));

// Get screening results
router.get('/results/:session_id', screeningController.getResults.bind(screeningController));

// Get screening statistics
router.get('/stats', screeningController.getScreeningStats.bind(screeningController));

// ========== DEBUG ROUTES ==========

// Debug current session state
router.get('/debug/state/:session_id', async (req, res) => {
  try {
    const { session_id } = req.params;
    const debugInfo = await screeningController.debugCurrentState(session_id);
    res.json(debugInfo);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Debug query for specific age
router.get('/debug/query/:age', async (req, res) => {
  try {
    const { age } = req.params;
    const debugInfo = await screeningController.debugQuery(parseInt(age));
    res.json(debugInfo);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Debug all questions in database
router.get('/debug/questions', screeningController.debugAllQuestions.bind(screeningController));

// Debug next question logic
router.get('/debug/next-question/:session_id', screeningController.debugNextQuestionLogic.bind(screeningController));

// Debug route to see all available questions (legacy)
router.get('/debug/all-questions', async (req, res) => {
  try {
    const { Question } = require('../model/index');
    const questions = await Question.findAll({
      raw: true,
      order: [['age_group', 'ASC'], ['order', 'ASC']]
    });
    
    res.json({
      total: questions.length,
      questions: questions.map(q => ({
        id: q.id,
        text: q.question_text,
        age_group: q.age_group,
        category: q.category,
        order: q.order,
        depends_on: q.depends_on_previous
      }))
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// في screeningRoutes.js - أضف هذا الـ route
router.get('/debug/responses/:session_id', async (req, res) => {
  try {
    const { session_id } = req.params;
    const debugInfo = await screeningController.debugSessionResponses(session_id);
    res.json(debugInfo);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;