const { 
  Questionnaire, 
  QuestionnaireAnswer, 
  QuestionnaireResult,
  User,
  Child 
} = require('../model/relations');
const { calculateQuestionnaireScores } = require('../utils/scoringEngine');
const questionnaireSchema = require('../utils/questionnaireSchema');

const buildFlatQuestionList = () => {
  const sections = questionnaireSchema.sections || [];
  const flat = [];

  sections.forEach(section => {
    const questions = section.questions || [];
    questions.forEach(q => {
      flat.push({
        sectionId: section.id,
        schemaQuestion: q
      });
    });
  });

  return flat;
};

// ==========================================
// 🚀 Start New Questionnaire
// ==========================================
exports.startQuestionnaire = async (req, res) => {
  try {
    const { child_id } = req.body;
    const parent_id = req.user.user_id;

    // Check if there's an incomplete questionnaire
    const existing = await Questionnaire.findOne({
      where: {
        parent_id,
        status: 'in_progress'
      }
    });

    if (existing) {
      return res.status(200).json({
        success: true,
        message: 'You have an incomplete questionnaire',
        data: existing
      });
    }

    // Create new questionnaire
    const questionnaire = await Questionnaire.create({
      parent_id,
      child_id: child_id || null,
      status: 'in_progress',
      current_section: 'demographics',
      demographics: {},
      general_answers: {},
      conditional_answers: {
        ASD: {},
        ADHD: {},
        Speech: {},
        Down: {}
      }
    });

    res.status(201).json({
      success: true,
      message: 'Questionnaire started successfully',
      data: questionnaire
    });

  } catch (error) {
    console.error('Error starting questionnaire:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to start questionnaire',
      error: error.message
    });
  }
};

// ==========================================
// 💾 Save Single Answer
// ==========================================
exports.saveAnswer = async (req, res) => {
  try {
    const { 
      questionnaire_id, 
      question_id, 
      section, 
      category,
      answer_value,
      answer_values, // for multiple choice
      answer_text,
      score,
      weight 
    } = req.body;

    // Verify questionnaire belongs to user
    const questionnaire = await Questionnaire.findOne({
      where: {
        id: questionnaire_id,
        parent_id: req.user.user_id,
        status: 'in_progress'
      }
    });

    if (!questionnaire) {
      return res.status(404).json({
        success: false,
        message: 'Questionnaire not found or already completed'
      });
    }

    // Check if answer already exists
    let answer = await QuestionnaireAnswer.findOne({
      where: {
        questionnaire_id,
        question_id
      }
    });

    if (answer) {
      // Update existing answer
      await answer.update({
        answer_value,
        answer_values,
        answer_text,
        score: score || 0,
        weight: weight || 1.0,
        answered_at: new Date()
      });
    } else {
      // Create new answer
      answer = await QuestionnaireAnswer.create({
        questionnaire_id,
        question_id,
        section,
        category,
        answer_value,
        answer_values,
        answer_text,
        score: score || 0,
        weight: weight || 1.0
      });
    }

    // Update questionnaire's current section if needed
    await questionnaire.update({
      current_section: section
    });

    res.status(200).json({
      success: true,
      message: 'Answer saved successfully',
      data: answer
    });

  } catch (error) {
    console.error('Error saving answer:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save answer',
      error: error.message
    });
  }
};

// ==========================================
// 💾 Save Multiple Answers (Batch)
// ==========================================
exports.saveAnswersBatch = async (req, res) => {
  try {
    const { questionnaire_id, answers } = req.body;

    // Verify questionnaire
    const questionnaire = await Questionnaire.findOne({
      where: {
        id: questionnaire_id,
        parent_id: req.user.user_id,
        status: 'in_progress'
      }
    });

    if (!questionnaire) {
      return res.status(404).json({
        success: false,
        message: 'Questionnaire not found'
      });
    }

    // Save all answers
    const savedAnswers = [];
    for (const answerData of answers) {
      const answer = await QuestionnaireAnswer.create({
        questionnaire_id,
        ...answerData
      });
      savedAnswers.push(answer);
    }

    res.status(200).json({
      success: true,
      message: `${savedAnswers.length} answers saved successfully`,
      data: savedAnswers
    });

  } catch (error) {
    console.error('Error saving batch answers:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save answers',
      error: error.message
    });
  }
};

// ==========================================
// 📖 Get Current Questionnaire
// ==========================================
exports.getCurrentQuestionnaire = async (req, res) => {
  try {
    const questionnaire = await Questionnaire.findOne({
      where: {
        parent_id: req.user.user_id,
        status: 'in_progress'
      },
      include: [
        {
          model: QuestionnaireAnswer,
          as: 'Answers'
        },
        {
          model: Child,
          as: 'QuestionnaireChild',
          attributes: ['id', 'name', 'age_years', 'age_months']
        }
      ]
    });

    if (!questionnaire) {
      return res.status(404).json({
        success: false,
        message: 'No active questionnaire found'
      });
    }

    res.status(200).json({
      success: true,
      data: questionnaire
    });

  } catch (error) {
    console.error('Error getting current questionnaire:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get questionnaire',
      error: error.message
    });
  }
};

// ==========================================
// 📖 Get Questionnaire by ID
// ==========================================
exports.getQuestionnaireById = async (req, res) => {
  try {
    const { id } = req.params;

    const questionnaire = await Questionnaire.findOne({
      where: {
        id,
        parent_id: req.user.user_id
      },
      include: [
        {
          model: QuestionnaireAnswer,
          as: 'Answers'
        },
        {
          model: QuestionnaireResult,
          as: 'Result'
        },
        {
          model: Child,
          as: 'QuestionnaireChild'
        }
      ]
    });

    if (!questionnaire) {
      return res.status(404).json({
        success: false,
        message: 'Questionnaire not found'
      });
    }

    res.status(200).json({
      success: true,
      data: questionnaire
    });

  } catch (error) {
    console.error('Error getting questionnaire:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get questionnaire',
      error: error.message
    });
  }
};

// ==========================================
// 🧮 Calculate Scores
// ==========================================
exports.calculateScores = async (req, res) => {
  try {
    const { id } = req.params;

    const questionnaire = await Questionnaire.findOne({
      where: {
        id,
        parent_id: req.user.user_id
      },
      include: [
        {
          model: QuestionnaireAnswer,
          as: 'Answers'
        }
      ]
    });

    if (!questionnaire) {
      return res.status(404).json({
        success: false,
        message: 'Questionnaire not found'
      });
    }

    // Use scoring engine to calculate
    const results = await calculateQuestionnaireScores(questionnaire);

    // Update questionnaire with scores
    await questionnaire.update({
      scores: results.scores,
      primary_concern: results.primary_concern,
      risk_level: results.risk_level,
      urgency_level: results.urgency_level
    });

    // Create or update result record
    const [result, created] = await QuestionnaireResult.upsert({
      questionnaire_id: id,
      ...results
    });

    res.status(200).json({
      success: true,
      message: 'Scores calculated successfully',
      data: {
        questionnaire,
        results: result
      }
    });

  } catch (error) {
    console.error('Error calculating scores:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to calculate scores',
      error: error.message
    });
  }
};

// ==========================================
// ✅ Complete Questionnaire
// ==========================================
exports.completeQuestionnaire = async (req, res) => {
  try {
    const { id } = req.params;
    const { time_taken_seconds, notes } = req.body;

    const questionnaire = await Questionnaire.findOne({
      where: {
        id,
        parent_id: req.user.user_id
      },
      include: [
        {
          model: QuestionnaireAnswer,
          as: 'Answers'
        }
      ]
    });

    if (!questionnaire) {
      return res.status(404).json({
        success: false,
        message: 'Questionnaire not found'
      });
    }

    // Calculate final scores
    const results = await calculateQuestionnaireScores(questionnaire);

    // Update questionnaire
    await questionnaire.update({
      status: 'completed',
      time_taken_seconds,
      total_questions_asked: questionnaire.Answers.length,
      notes,
      scores: results.scores,
      primary_concern: results.primary_concern,
      risk_level: results.risk_level,
      urgency_level: results.urgency_level,
      recommendations: results.recommendations
    });

    // Create result record
    await QuestionnaireResult.upsert({
      questionnaire_id: id,
      ...results
    });

    res.status(200).json({
      success: true,
      message: 'Questionnaire completed successfully',
      data: {
        questionnaire,
        results
      }
    });

  } catch (error) {
    console.error('Error completing questionnaire:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to complete questionnaire',
      error: error.message
    });
  }
};

// ==========================================
// 📋 Get All Questionnaires
// ==========================================
exports.getAllQuestionnaires = async (req, res) => {
  try {
    const questionnaires = await Questionnaire.findAll({
      where: {
        parent_id: req.user.user_id
      },
      include: [
        {
          model: Child,
          as: 'QuestionnaireChild',
          attributes: ['id', 'name', 'age_years', 'age_months']
        },
        {
          model: QuestionnaireResult,
          as: 'Result'
        }
      ],
      order: [['createdAt', 'DESC']]
    });

    res.status(200).json({
      success: true,
      count: questionnaires.length,
      data: questionnaires
    });

  } catch (error) {
    console.error('Error getting questionnaires:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get questionnaires',
      error: error.message
    });
  }
};

// ==========================================
// 📊 Get Results
// ==========================================
exports.getResults = async (req, res) => {
  try {
    const { id } = req.params;

    const result = await QuestionnaireResult.findOne({
      where: { questionnaire_id: id },
      include: [
        {
          model: Questionnaire,
          where: { parent_id: req.user.user_id }
        }
      ]
    });

    if (!result) {
      return res.status(404).json({
        success: false,
        message: 'Results not found'
      });
    }

    res.status(200).json({
      success: true,
      data: result
    });

  } catch (error) {
    console.error('Error getting results:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get results',
      error: error.message
    });
  }
};

// ==========================================
// 🗑️ Delete Questionnaire
// ==========================================
exports.deleteQuestionnaire = async (req, res) => {
  try {
    const { id } = req.params;

    const questionnaire = await Questionnaire.findOne({
      where: {
        id,
        parent_id: req.user.user_id
      }
    });

    if (!questionnaire) {
      return res.status(404).json({
        success: false,
        message: 'Questionnaire not found'
      });
    }

    // Soft delete by updating status
    await questionnaire.update({ status: 'expired' });

    res.status(200).json({
      success: true,
      message: 'Questionnaire deleted successfully'
    });

  } catch (error) {
    console.error('Error deleting questionnaire:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete questionnaire',
      error: error.message
    });
  }
};

// ==========================================
// � Get Questionnaire Schema (raw sections)
// ==========================================
exports.getQuestionnaireSchema = async (req, res) => {
  try {
    const { section } = req.query;

    let sections = questionnaireSchema.sections || [];

    if (section) {
      sections = sections.filter((s) => s.id === section);
    }

    res.status(200).json({
      success: true,
      sections,
    });
  } catch (error) {
    console.error('Error getting questionnaire schema:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get questionnaire schema',
      error: error.message,
    });
    return;
  }
};

// ==========================================
// 📋 Get Questionnaire Questions (staged)
// ==========================================
exports.getQuestionnaireQuestions = async (req, res) => {
  try {
    const { stage, previous_answers } = req.query;

    const sections = questionnaireSchema.sections || [];

    const demographicsSection = sections.find((s) => s.id === 'demographics');
    const generalSection = sections.find((s) => s.id === 'general_screening');
    const asdDeep = sections.find((s) => s.id === 'ASD_deep');
    const adhdDeep = sections.find((s) => s.id === 'ADHD_deep');
    const speechDeep = sections.find((s) => s.id === 'Speech_deep');
    const downDeep = sections.find((s) => s.id === 'Down_deep');

    let selectedQuestions = [];

    // 1) Demographics stage: only demographics section (Q1, Q2, Q4)
    if (stage === 'demographics') {
      if (demographicsSection && Array.isArray(demographicsSection.questions)) {
        selectedQuestions = demographicsSection.questions;
      }
    }
    // 2) General stage: only general_screening section (Q5–Q14)
    else if (stage === 'general') {
      if (generalSection && Array.isArray(generalSection.questions)) {
        selectedQuestions = generalSection.questions;
      }
    }
    // 3) Deep stage: decide which deep sections to show based on general answers
    else if (stage === 'deep') {
      // Parse previous_answers sent from the app (answers to general_screening)
      let prevAnswersObj = {};
      if (previous_answers) {
        try {
          prevAnswersObj = JSON.parse(previous_answers);
        } catch (e) {
          console.warn('Failed to parse previous_answers JSON:', e.message);
        }
      }

      // Build mapping from question numeric index to schema question in general_screening
      const flat = buildFlatQuestionList();

      const scores = {
        ASD: 0,
        ADHD: 0,
        Speech: 0,
        Down: 0,
      };

      const triggers = {
        ASD: 0,
        ADHD: 0,
        Speech: 0,
        Down: 0,
      };

      // Iterate over previous answers and accumulate simple scores
      for (const [key, value] of Object.entries(prevAnswersObj)) {
        const numericId = parseInt(key, 10);
        const questionIndex = Number.isNaN(numericId) ? -1 : numericId - 1;
        const flatItem = questionIndex >= 0 && questionIndex < flat.length
          ? flat[questionIndex]
          : null;

        if (!flatItem || flatItem.sectionId !== 'general_screening') continue;

        const schemaQuestion = flatItem.schemaQuestion;
        if (!schemaQuestion) continue;

        const rawAnswer = value && typeof value === 'object'
          ? value.answer?.toString?.()
          : value?.toString?.();
        if (!rawAnswer) continue;

        const opts = Array.isArray(schemaQuestion.options)
          ? schemaQuestion.options
          : [];

        let optionScore = 0;
        const matchedOption = opts.find((o) => {
          if (!o) return false;
          if (typeof o === 'object') {
            const label = o.label != null ? o.label.toString() : null;
            const valueField = o.value != null ? o.value.toString() : null;
            return label === rawAnswer || valueField === rawAnswer;
          }
          return o.toString() === rawAnswer;
        });

        if (matchedOption && typeof matchedOption.score === 'number') {
          optionScore = matchedOption.score;
        }

        const scoring = schemaQuestion.scoring || {};

        const triggerThreshold = typeof scoring.trigger_threshold === 'number'
          ? scoring.trigger_threshold
          : null;

        // ASD
        if (scoring.ASD) {
          let qScore = optionScore;
          if (typeof scoring.ASD === 'string' && scoring.ASD.includes('*')) {
            // very simple evaluation of expressions like 'score * 0.5'
            const multiplier = parseFloat(scoring.ASD.split('*')[1]);
            if (!Number.isNaN(multiplier)) {
              qScore = optionScore * multiplier;
            }
          }
          scores.ASD += qScore;
          if (triggerThreshold != null && qScore >= triggerThreshold) {
            triggers.ASD += 1;
          }
        }

        // ADHD
        if (scoring.ADHD) {
          let qScore = optionScore;
          scores.ADHD += qScore;
          if (triggerThreshold != null && qScore >= triggerThreshold) {
            triggers.ADHD += 1;
          }
        }

        // Speech
        if (scoring.Speech) {
          let qScore = optionScore;
          if (typeof scoring.Speech === 'string' && scoring.Speech.includes('*')) {
            const multiplier = parseFloat(scoring.Speech.split('*')[1]);
            if (!Number.isNaN(multiplier)) {
              qScore = optionScore * multiplier;
            }
          }
          scores.Speech += qScore;
          if (triggerThreshold != null && qScore >= triggerThreshold) {
            triggers.Speech += 1;
          }
        }

        // Down
        if (scoring.Down) {
          let qScore = optionScore;
          scores.Down += qScore;
          if (triggerThreshold != null && qScore >= triggerThreshold) {
            triggers.Down += 1;
          }
        }
      }

      // Decide which deep sections to include based on triggers / scores
      const selectedDeepSections = [];

      const addIfTriggered = (key, sectionRef) => {
        if (!sectionRef || !Array.isArray(sectionRef.questions)) return;
        if (triggers[key] > 0 || scores[key] > 0) {
          selectedDeepSections.push(sectionRef);
        }
      };

      addIfTriggered('ASD', asdDeep);
      addIfTriggered('ADHD', adhdDeep);
      addIfTriggered('Speech', speechDeep);
      addIfTriggered('Down', downDeep);

      // If no section triggered at all, choose the highest score section (fallback)
      if (selectedDeepSections.length === 0) {
        const scoreEntries = [
          { key: 'ASD', value: scores.ASD, section: asdDeep },
          { key: 'ADHD', value: scores.ADHD, section: adhdDeep },
          { key: 'Speech', value: scores.Speech, section: speechDeep },
          { key: 'Down', value: scores.Down, section: downDeep },
        ].filter((e) => e.section && Array.isArray(e.section.questions));

        if (scoreEntries.length > 0) {
          scoreEntries.sort((a, b) => b.value - a.value);
          selectedDeepSections.push(scoreEntries[0].section);
        }
      }

      selectedQuestions = [];
      for (const sec of selectedDeepSections) {
        if (Array.isArray(sec.questions)) {
          selectedQuestions.push(...sec.questions);
        }
      }
    }
    // Fallback: no stage provided -> return flat list of all questions as before
    else {
      const flatQuestions = buildFlatQuestionList();
      selectedQuestions = flatQuestions.map((item) => item.schemaQuestion || {});
    }

    // Transform selected questions into flat format expected by Flutter
    const questions = (selectedQuestions || []).map((q, index) => {
      const options = Array.isArray(q.options)
        ? q.options.map((o) => {
            if (o && typeof o === 'object') {
              return o.label || o.value || '';
            }
            return o != null ? o.toString() : '';
          })
        : [];

      const weight = typeof q.weight === 'number' ? q.weight : 1.0;

      return {
        question_id: index + 1,
        category: q.category || '',
        question_text: q.text || '',
        question_type: 'Multiple Choice',
        options,
        weight,
        target_conditions: [],
        min_age: 0,
        max_age: 18,
      };
    });

    res.status(200).json({
      success: true,
      questions,
    });
  } catch (error) {
    console.error('Error getting questionnaire questions:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get questionnaire questions',
      error: error.message,
    });
  }
};


// ==========================================
// �💾 Submit Questionnaire Responses (from app)
// ==========================================
exports.submitQuestionnaireResponses = async (req, res) => {
  try {
    const { responses, child_id, questionnaire_id } = req.body;

    if (!responses || typeof responses !== 'object') {
      return res.status(400).json({
        success: false,
        message: 'Responses object is required'
      });
    }

    const parent_id = req.user.user_id;

    let questionnaire = null;

    if (questionnaire_id) {
      questionnaire = await Questionnaire.findOne({
        where: {
          id: questionnaire_id,
          parent_id
        }
      });
    }

    if (!questionnaire) {
      questionnaire = await Questionnaire.create({
        parent_id,
        child_id: child_id || null,
        status: 'in_progress',
        current_section: 'general_screening'
      });
    }

    const qId = questionnaire.id;

    const answerEntries = Object.entries(responses);
    const flatQuestions = buildFlatQuestionList();

    for (const [key, value] of answerEntries) {
      const answerData = value || {};
      const numericId = parseInt(key, 10);
      const questionIndex = Number.isNaN(numericId) ? -1 : numericId - 1;
      const flat = questionIndex >= 0 && questionIndex < flatQuestions.length
        ? flatQuestions[questionIndex]
        : null;

      const schemaQuestion = flat ? flat.schemaQuestion : null;
      const section = (flat && flat.sectionId) || answerData.section || 'general_screening';
      const category = (schemaQuestion && schemaQuestion.category) || answerData.category || null;

      const rawAnswer = answerData.answer?.toString?.() || null;
      const answer_value = rawAnswer;

      let weight = 1.0;
      if (schemaQuestion && typeof schemaQuestion.weight === 'number') {
        weight = schemaQuestion.weight;
      } else if (typeof answerData.weight === 'number') {
        weight = answerData.weight;
      }

      let score = 0;
      if (schemaQuestion && Array.isArray(schemaQuestion.options) && rawAnswer) {
        const option = schemaQuestion.options.find(o => {
          if (!o) return false;
          if (typeof o === 'object') {
            const label = o.label != null ? o.label.toString() : null;
            const valueField = o.value != null ? o.value.toString() : null;
            return label === rawAnswer || valueField === rawAnswer;
          }
          return o.toString() === rawAnswer;
        });

        if (option && typeof option.score === 'number') {
          score = option.score;
        }
      }

      if (typeof answerData.score === 'number' && score === 0) {
        score = answerData.score;
      }

      await QuestionnaireAnswer.create({
        questionnaire_id: qId,
        question_id: numericId.toString(),
        section,
        category,
        answer_value,
        answer_values: null,
        answer_text: null,
        score,
        weight
      });
    }

    const questionnaireWithAnswers = await Questionnaire.findOne({
      where: { id: qId, parent_id },
      include: [
        {
          model: QuestionnaireAnswer,
          as: 'Answers'
        }
      ]
    });

    if (!questionnaireWithAnswers) {
      return res.status(404).json({
        success: false,
        message: 'Questionnaire not found after saving answers',
      });
    }

    const results = await calculateQuestionnaireScores(questionnaireWithAnswers);

    await questionnaire.update({
      status: 'completed',
      scores: results.scores,
      primary_concern: results.primary_concern,
      risk_level: results.risk_level,
      urgency_level: results.urgency_level,
      total_questions_asked: questionnaireWithAnswers.Answers.length
    });

    await QuestionnaireResult.upsert({
      questionnaire_id: qId,
      ...results
    });

    res.status(200).json({
      success: true,
      message: 'Questionnaire submitted successfully',
      questionnaire_id: qId,
      scores: results.scores,
      primary_concern: results.primary_concern,
      risk_level: results.risk_level,
      urgency_level: results.urgency_level
    });
  } catch (error) {
    console.error('Error submitting questionnaire responses:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to submit questionnaire responses',
      error: error.message
    });
  }
};