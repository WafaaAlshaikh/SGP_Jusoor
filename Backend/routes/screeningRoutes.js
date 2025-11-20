const express = require('express');
const router = express.Router();
const ScreeningController = require('../controllers/screeningController');

const screeningController = new ScreeningController();

// ========== MAIN ROUTES ==========

// Start new screening
router.post('/start', screeningController.startScreening.bind(screeningController));

// Submit answer
router.post('/answer', screeningController.submitAnswer.bind(screeningController));

// Get results
router.get('/results/:session_id', screeningController.getResults.bind(screeningController));

// Get statistics
router.get('/stats', screeningController.getScreeningStats.bind(screeningController));

// ========== DEBUG ROUTES ==========

// Debug session details
router.get('/debug/session/:session_id', screeningController.debugSession.bind(screeningController));

// Test query for specific age
router.get('/debug/age/:age_months', async (req, res) => {
  try {
    const { age_months } = req.params;
    const age = parseInt(age_months);
    
    const ageGroup = screeningController.getAgeGroup(age);
    const expectedInitial = screeningController.getExpectedInitialCount(age);
    
    const { Question } = require('../model/index');
    
    const initialQuestions = await Question.findAll({
      where: {
        age_group: ageGroup,
        is_initial: true
      },
      order: [['order', 'ASC']]
    });

    const allQuestions = await Question.findAll({
      where: { age_group: ageGroup },
      order: [['category', 'ASC'], ['order', 'ASC']]
    });

    res.json({
      success: true,
      age_months: age,
      age_group: ageGroup,
      expected_initial_count: expectedInitial,
      initial_questions_found: initialQuestions.length,
      total_questions_for_age: allQuestions.length,
      initial_questions: initialQuestions.map(q => ({
        id: q.id,
        text: q.question_text,
        category: q.category,
        order: q.order
      })),
      all_questions_summary: allQuestions.reduce((acc, q) => {
        acc[q.category] = (acc[q.category] || 0) + 1;
        return acc;
      }, {})
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// List all questions
router.get('/debug/questions', async (req, res) => {
  try {
    const { Question } = require('../model/index');
    
    const questions = await Question.findAll({
      order: [['age_group', 'ASC'], ['category', 'ASC'], ['order', 'ASC']],
      attributes: ['id', 'question_text', 'age_group', 'category', 'order', 'is_initial', 'is_critical']
    });

    const grouped = questions.reduce((acc, q) => {
      const key = `${q.age_group}_${q.category}`;
      if (!acc[key]) {
        acc[key] = {
          age_group: q.age_group,
          category: q.category,
          total: 0,
          initial: 0,
          critical: 0,
          questions: []
        };
      }
      acc[key].total++;
      if (q.is_initial) acc[key].initial++;
      if (q.is_critical) acc[key].critical++;
      acc[key].questions.push({
        id: q.id,
        text: q.question_text.substring(0, 60) + '...',
        order: q.order,
        is_initial: q.is_initial,
        is_critical: q.is_critical
      });
      return acc;
    }, {});

    res.json({
      success: true,
      total_questions: questions.length,
      by_age_and_category: grouped,
      summary: {
        'age_16_30': questions.filter(q => q.age_group === '16-30').length,
        'age_2_5_5': questions.filter(q => q.age_group === '2.5-5').length,
        'age_6_plus': questions.filter(q => q.age_group === '6+').length,
        'initial_total': questions.filter(q => q.is_initial).length,
        'critical_total': questions.filter(q => q.is_critical).length
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Simulate screening flow
router.post('/debug/simulate', async (req, res) => {
  try {
    const { age_months, answers } = req.body;
    
    if (!age_months || !answers) {
      return res.status(400).json({
        success: false,
        message: 'age_months and answers array required'
      });
    }

    // Start screening
    const startResponse = await screeningController.startScreening({
      body: { child_age_months: age_months }
    }, {
      json: (data) => data
    });

    let currentSession = startResponse.session_id;
    let questionIndex = 0;
    let allResponses = [];

    // Submit answers
    for (const answer of answers) {
      if (questionIndex >= startResponse.questions.length) break;
      
      const question = startResponse.questions[questionIndex];
      const submitResponse = await screeningController.submitAnswer({
        body: {
          session_id: currentSession,
          question_id: question.id,
          answer: answer
        }
      }, {
        json: (data) => data
      });

      allResponses.push(submitResponse);
      questionIndex++;

      if (submitResponse.completed) break;
    }

    res.json({
      success: true,
      simulation: {
        age_months,
        total_questions_answered: questionIndex,
        responses: allResponses,
        final_result: allResponses[allResponses.length - 1]
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;