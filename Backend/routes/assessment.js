// routes/assessment.js
const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const authorize = require('../middlewares/authorize');
const AssessmentQuestion = require('../model/AssessmentQuestion');
const AssessmentResponse = require('../model/AssessmentResponse');
const AssessmentResult = require('../model/AssessmentResult');
const Child = require('../model/Child');

// 1. Start assessment => returns session_id and first question
router.post('/start/:childId', authorize(['Parent']), async (req,res)=> {
  const childId = req.params.childId;
  const parentId = req.user.user_id;
  // TODO: validate child belongs to parent
  const sessionId = uuidv4();
  // get first question (e.g., question with id = 1 or flagged start)
  const first = await AssessmentQuestion.findOne({ where: { /* is_start: true OR question_id: 1 */ } });
  return res.json({ session_id: sessionId, question: first });
});

// 2. Answer question
router.post('/answer', authorize(['Parent']), async (req,res)=> {
  const { session_id, child_id, question_id, answer } = req.body;
  const parent_id = req.user.user_id;
  const q = await AssessmentQuestion.findByPk(question_id);
  // compute score_value based on q.type and q.weight
  let score_value = computeScore(q, answer); // اكتب الدالة أدناه
  await AssessmentResponse.create({ session_id, parent_id, child_id, question_id, answer, score_value });
  // determine next question using q.next_map and answer
  const nextQuestionId = determineNext(q, answer);
  if (!nextQuestionId) {
    // finished -> analyze and store result
    const result = await analyzeSession(session_id, child_id);
    return res.json({ finished: true, result });
  }
  const nextQ = await AssessmentQuestion.findByPk(nextQuestionId);
  return res.json({ finished: false, question: nextQ });
});

// 3. Get result (by session_id)
router.get('/result/:sessionId', authorize(['Parent','Specialist','Admin']), async (req,res)=> {
  const sessionId = req.params.sessionId;
  const result = await AssessmentResult.findOne({ where: { session_id: sessionId }});
  if (!result) return res.status(404).json({ message: 'Not found' });
  return res.json(result);
});

module.exports = router;
